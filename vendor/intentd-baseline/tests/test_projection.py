import sqlite3
from pathlib import Path

import pytest

from intentd.journal import AuthenticatedJournal, Payload
from intentd.projection import ProjectionError, rebuild_projection
from intentd.txn import TxnStatus
from tests.helpers import (
    TEST_JOURNAL_KEY,
    blessed_app_transaction,
    boot_artifact_fixture,
    boot_plan_fixture,
    built_app_transaction,
    failed_outcome_fixture,
    pending_graphics_transaction,
    proposal_payload,
    staging_failure_fixture,
)


def test_projection_rebuilds_transaction_and_pointers(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="2" * 32)
    proposed = journal.append_proposal(proposal_payload("firefox"))
    journal.append(
        "transaction.transition",
        {"from_status": "proposed", "to_status": "validated", "rendered_hash": "r" * 64},
        txn_id=proposed.txn_id,
    )
    journal.append(
        "transaction.transition",
        {
            "from_status": "validated",
            "to_status": "built",
            "closure_path": "/nix/store/x",
            "flake_lock_hash": "l" * 64,
        },
        txn_id=proposed.txn_id,
    )
    journal.append(
        "transaction.transition",
        {"from_status": "built", "to_status": "pending"},
        txn_id=proposed.txn_id,
    )
    journal.append(
        "transaction.transition",
        {"from_status": "pending", "to_status": "blessed"},
        txn_id=proposed.txn_id,
    )

    rebuild_projection(tmp_path / "txn.db", journal.read_verified())

    conn = sqlite3.connect(tmp_path / "txn.db")
    assert conn.execute("SELECT status FROM transactions").fetchone() == ("blessed",)
    assert conn.execute("SELECT txn_id FROM pointers WHERE name='active'").fetchone() == (1,)
    assert conn.execute("SELECT txn_id FROM pointers WHERE name='blessed'").fetchone() == (1,)
    assert conn.execute("SELECT seq FROM projection_meta").fetchone() == (5,)


def test_projection_rejects_illegal_authenticated_transition(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="3" * 32)
    proposed = journal.append_proposal(proposal_payload("firefox"))
    journal.append(
        "transaction.transition",
        {"from_status": "proposed", "to_status": "blessed"},
        txn_id=proposed.txn_id,
    )

    with pytest.raises(ProjectionError, match="illegal transition proposed -> blessed"):
        rebuild_projection(tmp_path / "txn.db", journal.read_verified())
    assert not (tmp_path / "txn.db").exists()


def test_projection_ignores_audit_outcomes_but_checkpoints_them(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="4" * 32)
    journal.append("audit.outcome", {"outcome": "content-abstain"}, txn_id=None)

    rebuild_projection(tmp_path / "txn.db", journal.read_verified())

    conn = sqlite3.connect(tmp_path / "txn.db")
    assert conn.execute("SELECT count(*) FROM transactions").fetchone() == (0,)
    assert conn.execute("SELECT seq FROM projection_meta").fetchone() == (1,)


def test_invalid_replay_does_not_replace_valid_projection(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="6" * 32)
    proposed = journal.append_proposal(proposal_payload("firefox"))
    db_path = tmp_path / "txn.db"
    rebuild_projection(db_path, journal.read_verified())
    original = db_path.read_bytes()

    journal.append(
        "transaction.transition",
        {"from_status": "proposed", "to_status": "blessed"},
        txn_id=proposed.txn_id,
    )

    with pytest.raises(ProjectionError, match="illegal transition"):
        rebuild_projection(db_path, journal.read_verified())
    assert db_path.read_bytes() == original
    conn = sqlite3.connect(db_path)
    assert conn.execute("SELECT seq FROM projection_meta").fetchone() == (1,)


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("candidate_closure", "/nix/store/wrong", "candidate closure"),
        ("rendered_hash", "f" * 64, "rendered hash"),
        ("flake_lock_hash", "f" * 64, "flake-lock hash"),
        ("machine_profile_id", "ux3404vc-v1", "machine profile"),
    ],
)
def test_projection_rejects_boot_plan_mismatched_to_authenticated_build(
    tmp_path: Path, field: str, value: str, message: str
) -> None:
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="7" * 32)
    invocation_payload = proposal_payload("firefox")
    invocation_payload["invocation"] = {
        "capability": "hardware.graphics.profile",
        "params": {"profile": "integrated"},
    }
    invocation_payload["new_state"] = {"apps": [], "graphics_profile": "integrated"}
    invocation_payload["machine_profile_id"] = "intentd-vm-v1"
    proposed = journal.append_proposal(invocation_payload)
    journal.append(
        "transaction.transition",
        {
            "from_status": "proposed",
            "to_status": "validated",
            "rendered_hash": "a" * 64,
        },
        txn_id=proposed.txn_id,
    )
    journal.append(
        "transaction.transition",
        {
            "from_status": "validated",
            "to_status": "built",
            "closure_path": "/nix/store/graphics-candidate",
            "flake_lock_hash": "b" * 64,
        },
        txn_id=proposed.txn_id,
    )
    if field == "candidate_closure":
        plan = boot_plan_fixture().model_copy(
            update={
                "candidate": boot_plan_fixture().candidate.model_copy(
                    update={"closure_path": value}
                )
            }
        )
    else:
        plan = boot_plan_fixture().model_copy(update={field: value})
    journal.append(
        "transaction.transition",
        {
            "from_status": "built",
            "to_status": "pending",
            "boot_plan": plan.model_dump(mode="json"),
        },
        txn_id=proposed.txn_id,
    )

    with pytest.raises(ProjectionError, match=message):
        rebuild_projection(tmp_path / "txn.db", journal.read_verified())


def test_projection_rejects_second_authenticated_boot_anchor(tmp_path: Path) -> None:
    store, blessed = blessed_app_transaction(tmp_path)
    closure = store.get(blessed).closure_path
    assert closure is not None
    artifact = boot_artifact_fixture(closure_path=closure)
    store.anchor_blessed_boot(blessed, artifact)
    store.journal.append(
        "transaction.boot-anchored",
        {"status": "blessed", "artifact": artifact.model_dump(mode="json")},
        txn_id=blessed,
    )

    with pytest.raises(ProjectionError, match="already anchored"):
        rebuild_projection(tmp_path / "replayed.db", store.journal.read_verified())


@pytest.mark.parametrize("case", ["both", "wrong-candidate"])
def test_projection_rejects_invalid_authenticated_staging_failure(
    tmp_path: Path,
    case: str,
) -> None:
    store, txn = pending_graphics_transaction(tmp_path / "state")
    failure = staging_failure_fixture()
    payload_update: Payload
    if case == "both":
        payload_update = {
            "boot_outcome": failed_outcome_fixture().model_dump(mode="json"),
            "boot_staging_failure": failure.model_dump(mode="json"),
        }
    else:
        wrong = failure.model_copy(
            update={
                "candidate": failure.candidate.model_copy(
                    update={"closure_path": "/nix/store/wrong"}
                )
            }
        )
        payload_update = {"boot_staging_failure": wrong.model_dump(mode="json")}
    payload: Payload = {"from_status": "pending", "to_status": "aborted"}
    payload.update(payload_update)
    store.journal.append("transaction.transition", payload, txn_id=txn)

    with pytest.raises(ProjectionError):
        rebuild_projection(tmp_path / "replayed.db", store.journal.read_verified())


def test_projection_rejects_authenticated_staging_failure_on_non_boot_transaction(
    tmp_path: Path,
) -> None:
    store, txn = built_app_transaction(tmp_path / "state")
    store.transition(txn, TxnStatus.PENDING)
    store.journal.append(
        "transaction.transition",
        {
            "from_status": "pending",
            "to_status": "aborted",
            "boot_staging_failure": staging_failure_fixture().model_dump(mode="json"),
        },
        txn_id=txn,
    )

    with pytest.raises(ProjectionError):
        rebuild_projection(tmp_path / "replayed.db", store.journal.read_verified())
