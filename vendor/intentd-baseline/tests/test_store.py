import sqlite3
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import NoReturn
from unittest.mock import Mock

import pytest

import intentd.journal as journal_module
import intentd.projection as projection_module
from intentd.catalog import digest_catalog, load_catalog
from intentd.journal import AuthenticatedJournal, JournalError, Payload
from intentd.policy import PolicyDecision, PolicyVerdict, evaluate
from intentd.projection import ProjectionError
from intentd.registry import CapabilityInvocation, resolve_invocation
from intentd.state import DesiredState, apply_invocation
from intentd.store import StoreError, TransactionStore
from intentd.txn import TransitionError, TxnStatus
from tests.helpers import (
    TEST_JOURNAL_KEY,
    blessed_app_transaction,
    boot_artifact_fixture,
    boot_plan_fixture,
    built_app_transaction,
    built_graphics_transaction,
    failed_outcome_fixture,
    make_store,
    memory_nv_counter,
    pending_graphics_transaction,
    staging_failure_fixture,
    vm_machine_profile,
)

_CATALOG_HASH = digest_catalog(load_catalog())


def _install(app: str = "firefox") -> CapabilityInvocation:
    return resolve_invocation(load_catalog(), "app.install", {"app": app})


def _decision(inv: CapabilityInvocation, prev: DesiredState, new: DesiredState) -> PolicyDecision:
    return evaluate(inv, load_catalog(), prev, new, machine_profile=None)


def _drive_to_blessed(store: TransactionStore, app: str = "firefox") -> int:
    prev = store.blessed_state()
    new = DesiredState(apps=tuple(sorted({*prev.apps, app})))
    inv = _install(app)
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/x", flake_lock_hash="l" * 64)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)
    return txn


def test_propose_and_get_round_trip(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    record = store.get(txn)
    assert record.status is TxnStatus.PROPOSED
    assert record.invocation.params == {"app": "firefox"}
    assert record.new_state.apps == ("firefox",)


def test_full_lifecycle_moves_pointers(tmp_path: Path):
    store = make_store(tmp_path)
    txn = _drive_to_blessed(store)
    assert store.get(txn).status is TxnStatus.BLESSED
    active = store.active()
    assert active is not None and active.id == txn
    blessed = store.blessed()
    assert blessed is not None and blessed.id == txn
    assert store.blessed_state() == DesiredState(apps=("firefox",))


def test_illegal_transition_rejected(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    with pytest.raises(TransitionError, match="illegal transition"):
        store.transition(txn, TxnStatus.BLESSED)


def test_terminal_states_accept_no_transitions(tmp_path: Path):
    store = make_store(tmp_path)
    txn = _drive_to_blessed(store)
    with pytest.raises(TransitionError):
        store.transition(txn, TxnStatus.PENDING)


def test_evidence_required_for_validated_and_built(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    with pytest.raises(TransitionError, match="rendered_hash"):
        store.transition(txn, TxnStatus.VALIDATED)
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    with pytest.raises(TransitionError, match="closure_path"):
        store.transition(txn, TxnStatus.BUILT)


def test_boot_affecting_pending_requires_boot_plan(tmp_path: Path) -> None:
    store, txn = built_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="boot plan"):
        store.transition(txn, TxnStatus.PENDING)


def test_non_boot_pending_rejects_boot_plan(tmp_path: Path) -> None:
    store, txn = built_app_transaction(tmp_path)
    with pytest.raises(TransitionError, match="non-boot transaction"):
        store.transition(txn, TxnStatus.PENDING, boot_plan=boot_plan_fixture())


def test_boot_pending_rejects_plan_mismatched_to_authenticated_build(
    tmp_path: Path,
) -> None:
    store, txn = built_graphics_transaction(tmp_path)
    plan = boot_plan_fixture().model_copy(
        update={
            "candidate": boot_plan_fixture().candidate.model_copy(
                update={"closure_path": "/nix/store/wrong"}
            )
        }
    )
    with pytest.raises(TransitionError, match="candidate closure"):
        store.transition(txn, TxnStatus.PENDING, boot_plan=plan)


def test_boot_pending_rejects_mismatched_machine_profile(tmp_path: Path) -> None:
    store, txn = built_graphics_transaction(tmp_path)
    plan = boot_plan_fixture().model_copy(update={"machine_profile_id": "ux3404vc-v1"})
    with pytest.raises(TransitionError, match="machine profile"):
        store.transition(txn, TxnStatus.PENDING, boot_plan=plan)


def test_boot_bless_requires_healthy_outcome(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="healthy boot outcome"):
        store.transition(
            txn,
            TxnStatus.BLESSED,
            boot_outcome=failed_outcome_fixture(),
        )


def test_boot_abort_requires_failed_quarantined_outcome(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="failed, quarantined boot outcome"):
        store.transition(txn, TxnStatus.ABORTED)

    store.transition(
        txn,
        TxnStatus.ABORTED,
        boot_outcome=failed_outcome_fixture(),
    )
    assert store.get(txn).boot_outcome == failed_outcome_fixture()


def test_boot_abort_accepts_authenticated_staging_failure(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    failure = staging_failure_fixture()

    store.transition(txn, TxnStatus.ABORTED, boot_staging_failure=failure)

    record = store.get(txn)
    assert record.boot_staging_failure == failure
    assert record.boot_outcome is None


def test_boot_abort_rejects_both_failure_forms(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="exactly one"):
        store.transition(
            txn,
            TxnStatus.ABORTED,
            boot_outcome=failed_outcome_fixture(),
            boot_staging_failure=staging_failure_fixture(),
        )


def test_boot_abort_rejects_staging_failure_for_wrong_candidate(
    tmp_path: Path,
) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    failure = staging_failure_fixture().model_copy(
        update={
            "candidate": boot_plan_fixture().candidate.model_copy(
                update={"closure_path": "/nix/store/wrong"}
            )
        }
    )
    with pytest.raises(TransitionError, match="candidate"):
        store.transition(txn, TxnStatus.ABORTED, boot_staging_failure=failure)


def test_non_boot_abort_rejects_staging_failure(tmp_path: Path) -> None:
    store, txn = built_app_transaction(tmp_path)
    store.transition(txn, TxnStatus.PENDING)
    with pytest.raises(TransitionError, match="non-boot transaction"):
        store.transition(
            txn,
            TxnStatus.ABORTED,
            boot_staging_failure=staging_failure_fixture(),
        )


def test_healthy_boot_bless_persists_outcome_and_candidate_artifact(
    tmp_path: Path,
) -> None:
    store, txn = pending_graphics_transaction(tmp_path, memory_nv_counter())
    failed = failed_outcome_fixture()
    healthy = failed.model_copy(
        update={
            "healthy": True,
            "quarantined": False,
            "health": boot_plan_fixture().baseline,
            "failures": (),
        }
    )

    store.transition(txn, TxnStatus.BLESSED, boot_outcome=healthy)

    record = store.get(txn)
    assert record.boot_plan == boot_plan_fixture()
    assert record.boot_outcome == healthy
    assert record.boot_artifact == boot_plan_fixture().candidate


def test_existing_blessed_boot_requires_one_exact_anchor(tmp_path: Path) -> None:
    store, blessed = blessed_app_transaction(tmp_path)
    closure = store.get(blessed).closure_path
    assert closure is not None
    artifact = boot_artifact_fixture(closure_path=closure)
    store.anchor_blessed_boot(blessed, artifact)
    assert store.get(blessed).boot_artifact == artifact
    with pytest.raises(TransitionError, match="already anchored"):
        store.anchor_blessed_boot(blessed, artifact)


def test_boot_anchor_rejected_while_transaction_is_in_flight(tmp_path: Path) -> None:
    store, blessed = blessed_app_transaction(tmp_path)
    invocation = _install("vlc")
    previous = store.blessed_state()
    desired = DesiredState(apps=("firefox", "vlc"))
    store.propose(
        invocation,
        previous,
        desired,
        decision=_decision(invocation, previous, desired),
        catalog_hash=_CATALOG_HASH,
    )
    closure = store.get(blessed).closure_path
    assert closure is not None
    with pytest.raises(TransitionError, match="in flight"):
        store.anchor_blessed_boot(
            blessed,
            boot_artifact_fixture(closure_path=closure),
        )


def test_single_in_flight_rule(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    store.propose(inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH)
    prev2, new2 = DesiredState(), DesiredState(apps=("vlc",))
    inv2 = _install("vlc")
    with pytest.raises(StoreError, match="in flight"):
        store.propose(
            inv2, prev2, new2, decision=_decision(inv2, prev2, new2), catalog_hash=_CATALOG_HASH
        )


def test_aborted_quarantined_transaction_cannot_reactivate(tmp_path: Path):
    store, first = blessed_app_transaction(tmp_path)
    store.close()
    store, pending = pending_graphics_transaction(tmp_path)
    store.transition(pending, TxnStatus.ABORTED, boot_outcome=failed_outcome_fixture())
    assert store.get(pending).status is TxnStatus.ABORTED
    for status in TxnStatus:
        with pytest.raises(TransitionError):
            store.transition(pending, status)
    blessed = store.blessed()
    assert blessed is not None and blessed.id == first
    assert store.in_flight() is None
    store.close()
    reopened = make_store(tmp_path)
    assert reopened.get(pending).status is TxnStatus.ABORTED
    reopened_blessed = reopened.blessed()
    assert reopened_blessed is not None and reopened_blessed.id == first
    profile = vm_machine_profile()
    catalog = load_catalog()
    fresh_inv = resolve_invocation(catalog, "hardware.graphics.profile", {"profile": "integrated"})
    fresh_prev = reopened.blessed_state()
    fresh_new = apply_invocation(fresh_prev, fresh_inv)
    fresh = reopened.propose(
        fresh_inv,
        fresh_prev,
        fresh_new,
        decision=evaluate(fresh_inv, catalog, fresh_prev, fresh_new, machine_profile=profile),
        catalog_hash=_CATALOG_HASH,
        machine_profile_id=profile.profile_id,
    )
    assert reopened.get(fresh).status is TxnStatus.PROPOSED


def test_abort_restores_active_pointer_to_blessed(tmp_path: Path):
    store = make_store(tmp_path)
    first = _drive_to_blessed(store)
    prev = store.blessed_state()
    new = DesiredState(apps=tuple(sorted({*prev.apps, "vlc"})))
    inv = _install("vlc")
    second = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(second, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.transition(second, TxnStatus.BUILT, closure_path="/nix/store/y", flake_lock_hash="l" * 64)
    store.transition(second, TxnStatus.PENDING)
    active_before_abort = store.active()
    assert active_before_abort is not None and active_before_abort.id == second
    store.transition(second, TxnStatus.ABORTED, detail="health check failed")
    active = store.active()
    assert active is not None and active.id == first
    assert store.get(second).status is TxnStatus.ABORTED


def test_built_to_blessed_is_illegal(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/x", flake_lock_hash="l" * 64)
    with pytest.raises(TransitionError, match="illegal transition"):
        store.transition(txn, TxnStatus.BLESSED)


def test_pointers_and_records_survive_reopen(tmp_path: Path):
    db = tmp_path / "txn.db"
    store = make_store(db.parent)
    txn = _drive_to_blessed(store)
    store.close()
    reopened = make_store(db.parent)
    blessed = reopened.blessed()
    assert blessed is not None and blessed.id == txn
    assert reopened.blessed_state() == DesiredState(apps=("firefox",))
    assert reopened.get(txn).rendered_hash == "r" * 64


def test_events_journal_is_ordered_and_append_only(tmp_path: Path):
    store = make_store(tmp_path)
    txn = _drive_to_blessed(store)
    events = store.events(txn)
    assert [e[1] for e in events] == [
        "proposed",
        "validated",
        "built",
        "pending",
        "blessed",
    ]
    assert [e[0] for e in events] == sorted(e[0] for e in events)


def test_revert_target_is_blessed_prev_state(tmp_path: Path):
    store = make_store(tmp_path)
    assert store.revert_target() is None
    _drive_to_blessed(store)
    assert store.revert_target() == DesiredState()
    _drive_to_blessed(store, "vlc")
    assert store.revert_target() == DesiredState(apps=("firefox",))


def test_unknown_transaction_rejected(tmp_path: Path):
    store = make_store(tmp_path)
    with pytest.raises(StoreError, match="no transaction"):
        store.get(999)


def test_evidence_pins_are_write_once(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    with pytest.raises(TransitionError, match="already pinned"):
        store.transition(
            txn,
            TxnStatus.BUILT,
            closure_path="/nix/store/x",
            flake_lock_hash="l" * 64,
            rendered_hash="x" * 64,
        )
    assert store.get(txn).rendered_hash == "r" * 64


def test_empty_evidence_rejected(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    with pytest.raises(TransitionError, match="rendered_hash"):
        store.transition(txn, TxnStatus.VALIDATED, rendered_hash="")


def test_events_for_unknown_transaction_rejected(tmp_path: Path):
    store = make_store(tmp_path)
    with pytest.raises(StoreError, match="no transaction"):
        store.events(999)


def test_propose_after_abort_allowed(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/x", flake_lock_hash="l" * 64)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.ABORTED, detail="health check failed")
    prev2, new2 = DesiredState(), DesiredState(apps=("vlc",))
    inv2 = _install("vlc")
    second = store.propose(
        inv2, prev2, new2, decision=_decision(inv2, prev2, new2), catalog_hash=_CATALOG_HASH
    )
    assert store.get(second).status is TxnStatus.PROPOSED


def test_mid_lifecycle_reopen_preserves_in_flight(tmp_path: Path):
    db = tmp_path / "txn.db"
    store = make_store(db.parent)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.close()
    reopened = make_store(db.parent)
    assert reopened.get(txn).status is TxnStatus.VALIDATED
    prev2, new2 = DesiredState(), DesiredState(apps=("vlc",))
    inv2 = _install("vlc")
    with pytest.raises(StoreError, match="in flight"):
        reopened.propose(
            inv2, prev2, new2, decision=_decision(inv2, prev2, new2), catalog_hash=_CATALOG_HASH
        )
    reopened.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/x", flake_lock_hash="l" * 64)
    assert reopened.get(txn).status is TxnStatus.BUILT


def test_propose_without_decision_is_type_error(tmp_path: Path):
    store = make_store(tmp_path)
    with pytest.raises(TypeError):
        store.propose(  # pyright: ignore[reportCallIssue]
            _install(), DesiredState(), DesiredState(apps=("firefox",)), catalog_hash=_CATALOG_HASH
        )


def test_propose_rejected_decision_refused(tmp_path: Path):
    store = make_store(tmp_path)
    inv = _install()
    rejected = PolicyDecision(verdict=PolicyVerdict.REJECT, reason="test")
    with pytest.raises(StoreError, match="not authorized"):
        store.propose(
            inv,
            DesiredState(),
            DesiredState(apps=("firefox",)),
            decision=rejected,
            catalog_hash=_CATALOG_HASH,
        )


def test_propose_with_uncovered_acks_refused(tmp_path: Path):
    store = make_store(tmp_path)
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "obsidian"})
    needs = PolicyDecision(
        verdict=PolicyVerdict.NEEDS_ACK, reason="test", required_acks=("obsidian",)
    )
    with pytest.raises(StoreError, match="unacknowledged"):
        store.propose(
            inv,
            DesiredState(),
            DesiredState(apps=("obsidian",)),
            decision=needs,
            catalog_hash=_CATALOG_HASH,
        )


def test_record_event_appends_audit_row_without_status_change(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/x", flake_lock_hash="l" * 64)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.ABORTED, detail="health check failed")

    store.record_event(txn, "restore to blessed failed: boom")

    assert store.get(txn).status is TxnStatus.ABORTED
    events = store.events(txn)
    assert [e[1] for e in events] == [
        "proposed",
        "validated",
        "built",
        "pending",
        "aborted",
        "aborted",
    ]
    assert events[-1][2] == "restore to blessed failed: boom"


def test_record_event_on_unknown_transaction_rejected(tmp_path: Path):
    store = make_store(tmp_path)
    with pytest.raises(StoreError, match="no transaction"):
        store.record_event(999, "note")


def test_in_flight_is_none_when_all_transactions_are_terminal(tmp_path: Path):
    store = make_store(tmp_path)
    assert store.in_flight() is None
    _drive_to_blessed(store)
    assert store.in_flight() is None


def test_in_flight_finds_transaction_before_it_reaches_pending(tmp_path: Path):
    store = make_store(tmp_path)
    prev, new = DesiredState(), DesiredState(apps=("firefox",))
    inv = _install()
    txn = store.propose(
        inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
    )
    in_flight = store.in_flight()
    assert in_flight is not None and in_flight.id == txn
    assert in_flight.status is TxnStatus.PROPOSED

    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    in_flight = store.in_flight()
    assert in_flight is not None and in_flight.status is TxnStatus.VALIDATED

    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/x", flake_lock_hash="l" * 64)
    store.transition(txn, TxnStatus.PENDING)
    in_flight = store.in_flight()
    assert in_flight is not None and in_flight.status is TxnStatus.PENDING

    store.transition(txn, TxnStatus.BLESSED)
    assert store.in_flight() is None


def test_decision_and_acks_round_trip_through_reopen(tmp_path: Path):
    db = tmp_path / "txn.db"
    store = make_store(db.parent)
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "obsidian"})
    decision = evaluate(
        inv,
        load_catalog(),
        DesiredState(),
        DesiredState(apps=("obsidian",)),
        machine_profile=None,
        acknowledged_unfree=frozenset({"obsidian"}),
    )
    txn = store.propose(
        inv,
        DesiredState(),
        DesiredState(apps=("obsidian",)),
        decision=decision,
        acks=frozenset({"obsidian"}),
        catalog_hash=_CATALOG_HASH,
    )
    store.close()
    reopened = make_store(db.parent)
    record = reopened.get(txn)
    assert record.decision.verdict is PolicyVerdict.AUTO_APPLY
    assert record.acks == ("obsidian",)


def test_recent_returns_newest_first_limited_to_n(tmp_path: Path):
    store = make_store(tmp_path)
    first = _drive_to_blessed(store, "firefox")
    second = _drive_to_blessed(store, "vlc")
    third = _drive_to_blessed(store, "gimp")

    recent = store.recent(2)

    assert [r.id for r in recent] == [third, second]
    assert first not in [r.id for r in recent]


def test_recent_returns_all_when_n_exceeds_count(tmp_path: Path):
    store = make_store(tmp_path)
    first = _drive_to_blessed(store, "firefox")

    recent = store.recent(10)

    assert [r.id for r in recent] == [first]


def test_recent_empty_store_returns_empty_list(tmp_path: Path):
    store = make_store(tmp_path)
    assert store.recent(5) == []


def test_sqlite_projection_loss_rebuilds_from_journal(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    txn = _drive_to_blessed(store)
    store.close()
    (tmp_path / "txn.db").write_bytes(b"not sqlite")

    reopened = make_store(tmp_path)

    assert reopened.get(txn).status is TxnStatus.BLESSED
    assert reopened.blessed_state() == DesiredState(apps=("firefox",))


def test_journal_append_failure_does_not_change_projection(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)
    prev = DesiredState()
    new = DesiredState(apps=("firefox",))
    inv = _install()

    def fail_append(_payload: Payload, _records: list[object]) -> NoReturn:
        raise JournalError("injected persistence failure")

    monkeypatch.setattr(store.journal, "append_proposal_locked", fail_append)

    with pytest.raises(JournalError, match="persistence failure"):
        store.propose(
            inv, prev, new, decision=_decision(inv, prev, new), catalog_hash=_CATALOG_HASH
        )
    assert store.recent(10) == []


def test_journal_leads_projection_after_injected_rebuild_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)
    monkeypatch.setattr(store, "_rebuild", Mock(side_effect=ProjectionError("injected")))
    invocation = _install()
    prev = DesiredState()
    new = DesiredState(apps=("firefox",))

    with pytest.raises(ProjectionError, match="injected"):
        store.propose(
            invocation,
            prev,
            new,
            decision=_decision(invocation, prev, new),
            catalog_hash=_CATALOG_HASH,
        )

    reopened = make_store(tmp_path)
    assert reopened.get(1).status is TxnStatus.PROPOSED


def test_nonempty_legacy_database_is_not_silently_imported(tmp_path: Path) -> None:
    legacy = sqlite3.connect(tmp_path / "txn.db")
    legacy.execute("CREATE TABLE transactions (id INTEGER PRIMARY KEY, status TEXT NOT NULL)")
    legacy.execute("INSERT INTO transactions VALUES (1, 'blessed')")
    legacy.commit()
    legacy.close()

    with pytest.raises(StoreError, match="legacy unauthenticated state"):
        make_store(tmp_path)


def _propose_in_process(state_dir: str, app: str) -> str:
    store = make_store(Path(state_dir))
    invocation = _install(app)
    prev = DesiredState()
    new = DesiredState(apps=(app,))
    try:
        txn_id = store.propose(
            invocation,
            prev,
            new,
            decision=_decision(invocation, prev, new),
            catalog_hash=_CATALOG_HASH,
        )
    except StoreError as exc:
        return f"error:{exc}"
    finally:
        store.close()
    return f"ok:{txn_id}"


def test_concurrent_proposals_preserve_single_in_flight_transaction(tmp_path: Path) -> None:
    with ProcessPoolExecutor(max_workers=2) as pool:
        results = list(
            pool.map(_propose_in_process, [str(tmp_path), str(tmp_path)], ["firefox", "vlc"])
        )

    assert sum(result.startswith("ok:") for result in results) == 1
    assert sum("still in flight" in result for result in results) == 1
    records = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY).read_verified()
    assert [record.event for record in records] == ["transaction.proposed"]


class _InjectedCrash(Exception):
    pass


def _propose_firefox(store: TransactionStore) -> int:
    invocation = _install()
    prev = DesiredState()
    new = DesiredState(apps=("firefox",))
    return store.propose(
        invocation, prev, new, decision=_decision(invocation, prev, new), catalog_hash=_CATALOG_HASH
    )


def test_crash_before_journal_write_leaves_no_transaction(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)

    def crash_before_write(_fd: int, _data: bytes) -> NoReturn:
        raise _InjectedCrash

    monkeypatch.setattr(journal_module, "_write_all", crash_before_write)
    with pytest.raises(_InjectedCrash):
        _propose_firefox(store)
    monkeypatch.undo()

    assert make_store(tmp_path).recent(10) == []


def test_crash_after_journal_fsync_replays_proposal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)

    def crash_before_checkpoint(_record: object) -> NoReturn:
        raise _InjectedCrash

    monkeypatch.setattr(store.journal, "_write_checkpoint_locked", crash_before_checkpoint)
    with pytest.raises(_InjectedCrash):
        _propose_firefox(store)
    monkeypatch.undo()

    assert make_store(tmp_path).get(1).status is TxnStatus.PROPOSED


def test_crash_after_checkpoint_replace_replays_proposal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)

    def crash_before_directory_fsync() -> NoReturn:
        raise _InjectedCrash

    monkeypatch.setattr(store.journal, "_fsync_state_dir", crash_before_directory_fsync)
    with pytest.raises(_InjectedCrash):
        _propose_firefox(store)
    monkeypatch.undo()

    assert make_store(tmp_path).get(1).status is TxnStatus.PROPOSED


def test_crash_before_projection_replace_replays_proposal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)
    real_replace = projection_module.os.replace

    def crash_on_projection(source: Path, destination: Path) -> None:
        if Path(destination).name == "txn.db" and (tmp_path / "journal.jsonl").exists():
            raise _InjectedCrash
        real_replace(source, destination)

    monkeypatch.setattr(projection_module.os, "replace", crash_on_projection)
    with pytest.raises(_InjectedCrash):
        _propose_firefox(store)
    monkeypatch.undo()

    assert make_store(tmp_path).get(1).status is TxnStatus.PROPOSED


def test_crash_after_projection_replace_replays_proposal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)
    real_fsync_directory = projection_module._fsync_directory  # pyright: ignore[reportPrivateUsage]

    def crash_after_replace(path: Path) -> None:
        if (tmp_path / "journal.jsonl").exists():
            raise _InjectedCrash
        real_fsync_directory(path)

    monkeypatch.setattr(projection_module, "_fsync_directory", crash_after_replace)
    with pytest.raises(_InjectedCrash):
        _propose_firefox(store)
    monkeypatch.undo()

    assert make_store(tmp_path).get(1).status is TxnStatus.PROPOSED


def _projection_rows(db_path: Path) -> dict[str, list[tuple[object, ...]]]:
    connection = sqlite3.connect(db_path)
    rows = {
        "transactions": connection.execute("SELECT * FROM transactions ORDER BY id").fetchall(),
        "events": connection.execute("SELECT * FROM events ORDER BY seq").fetchall(),
        "pointers": connection.execute("SELECT * FROM pointers ORDER BY name").fetchall(),
        "projection_meta": connection.execute("SELECT * FROM projection_meta").fetchall(),
    }
    connection.close()
    return rows


def test_projection_reconstructs_all_rows_exactly(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    blessed = _drive_to_blessed(store)
    store.record_event(blessed, "blessed note")

    invocation = _install("vlc")
    prev = store.blessed_state()
    rejected = store.propose(
        invocation,
        prev,
        DesiredState(apps=("firefox", "vlc")),
        decision=_decision(invocation, prev, DesiredState(apps=("firefox", "vlc"))),
        catalog_hash=_CATALOG_HASH,
    )
    store.transition(rejected, TxnStatus.REJECTED, detail="rejected test")

    invocation = _install("gimp")
    prev = store.blessed_state()
    aborted = store.propose(
        invocation,
        prev,
        DesiredState(apps=("firefox", "gimp")),
        decision=_decision(invocation, prev, DesiredState(apps=("firefox", "gimp"))),
        catalog_hash=_CATALOG_HASH,
    )
    store.transition(aborted, TxnStatus.VALIDATED, rendered_hash="v" * 64)
    store.transition(
        aborted, TxnStatus.BUILT, closure_path="/nix/store/gimp", flake_lock_hash="k" * 64
    )
    store.transition(aborted, TxnStatus.PENDING)
    store.transition(aborted, TxnStatus.ABORTED, detail="aborted test")

    machine_profile = vm_machine_profile()
    graphics_invocation = resolve_invocation(
        {}, "hardware.graphics.profile", {"profile": "integrated"}
    )
    previous = store.blessed_state()
    desired = apply_invocation(previous, graphics_invocation)
    staged = store.propose(
        graphics_invocation,
        previous,
        desired,
        decision=evaluate(
            graphics_invocation,
            {},
            previous,
            desired,
            machine_profile=machine_profile,
        ),
        machine_profile_id=machine_profile.profile_id,
        catalog_hash=_CATALOG_HASH,
    )
    store.transition(staged, TxnStatus.VALIDATED, rendered_hash="a" * 64)
    store.transition(
        staged,
        TxnStatus.BUILT,
        closure_path="/nix/store/graphics-candidate",
        flake_lock_hash="b" * 64,
    )
    store.transition(staged, TxnStatus.PENDING, boot_plan=boot_plan_fixture())
    store.transition(
        staged,
        TxnStatus.ABORTED,
        boot_staging_failure=staging_failure_fixture(),
    )
    store.journal.append("audit.outcome", {"outcome": "one"}, txn_id=None)
    store.journal.append("audit.outcome", {"outcome": "two"}, txn_id=None)
    store.close()

    refreshed = make_store(tmp_path)
    refreshed.close()
    expected = _projection_rows(tmp_path / "txn.db")
    (tmp_path / "txn.db").write_bytes(b"invalid sqlite projection")

    rebuilt = make_store(tmp_path)
    rebuilt.close()

    assert _projection_rows(tmp_path / "txn.db") == expected
