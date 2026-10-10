from pathlib import Path

import pydantic
import pytest

from intentd.boot import BootBaseline, BootObservation
from intentd.boot_guard import BootGuardDeps, BootGuardResult, reconcile_boot
from intentd.catalog import digest_catalog, load_catalog
from intentd.policy import evaluate
from intentd.projection import ProjectionError
from intentd.recovery_console import RecoveryConsoleDeps, run_console
from intentd.registry import resolve_invocation
from intentd.schema import GraphicsProfile
from intentd.state import DesiredState, apply_invocation
from intentd.store import StoreError, TransactionStore
from intentd.txn import TxnStatus
from tests.helpers import (
    boot_plan_fixture,
    make_store,
    memory_nv_counter,
    proposal_payload,
    vm_machine_profile,
)


def _baseline() -> BootBaseline:
    plan = boot_plan_fixture()
    artifact = plan.prior_blessed
    return BootBaseline(
        artifact=artifact,
        observation=BootObservation(
            closure_path=artifact.closure_path,
            entry_id=artifact.entry_id,
            entry_path=artifact.uki_path,
        ),
        health=plan.baseline,
        machine_profile=vm_machine_profile(),
        state=DesiredState(graphics_profile=GraphicsProfile.HYBRID_NVIDIA),
        catalog_hash=digest_catalog(load_catalog()),
        flake_lock_hash="a" * 64,
    )


def _bless_app(store: TransactionStore) -> None:
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    txn = store.propose(
        invocation,
        previous,
        desired,
        decision=evaluate(invocation, catalog, previous, desired, machine_profile=None),
        catalog_hash=digest_catalog(catalog),
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="b" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/app", flake_lock_hash="c" * 64)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)


def test_adoption_replays_without_a_synthetic_transaction(tmp_path: Path) -> None:
    counter = memory_nv_counter(1)
    store = make_store(tmp_path, counter)
    baseline = _baseline()
    store.adopt_boot_baseline(baseline)
    assert store.blessed() is None
    assert store.active() is None
    assert store.recent(10) == []
    assert store.blessed_state() == baseline.state
    assert store.blessed_boot_artifact() == baseline.artifact
    assert counter.read() == 1
    record = store.journal.read_verified()[0]
    assert record.txn_id is None
    assert record.event == "boot.baseline-adopted"
    store.close()
    reopened = make_store(tmp_path, counter)
    assert reopened.boot_baseline() == baseline
    reopened.close()


@pytest.mark.parametrize("start", [0, 2])
def test_adoption_refuses_unprovisioned_or_advanced_counter(tmp_path: Path, start: int) -> None:
    store = make_store(tmp_path, memory_nv_counter(start))
    with pytest.raises(StoreError, match="provisioned NV counter"):
        store.adopt_boot_baseline(_baseline())
    assert store.journal.read_verified() == []


def test_adoption_requires_a_counter(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    with pytest.raises(StoreError, match="provisioned NV counter"):
        store.adopt_boot_baseline(_baseline())


@pytest.mark.parametrize("existing", ["baseline", "audit", "proposal"])
def test_adoption_cannot_replace_existing_history(tmp_path: Path, existing: str) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    if existing == "baseline":
        store.adopt_boot_baseline(_baseline())
    elif existing == "audit":
        store.journal.append("audit.outcome", {}, txn_id=None)
    else:
        store.journal.append_proposal(proposal_payload("firefox"))
    before = store.journal.read_verified()
    with pytest.raises(StoreError, match="empty journal"):
        store.adopt_boot_baseline(_baseline())
    assert store.journal.read_verified() == before


@pytest.mark.parametrize("extra", [True, False])
def test_replay_rejects_invalid_baseline_evidence(tmp_path: Path, extra: bool) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    payload = _baseline().model_dump(mode="json")
    if extra:
        payload["unexpected"] = True
    else:
        payload["health"]["display_ready"] = False
    store.journal.append("boot.baseline-adopted", payload, txn_id=None)
    store.close()
    with pytest.raises(ProjectionError, match="invalid boot baseline"):
        make_store(tmp_path, memory_nv_counter(1))


def test_replay_rejects_baseline_after_other_history(tmp_path: Path) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    store.journal.append("audit.outcome", {}, txn_id=None)
    store.journal.append("boot.baseline-adopted", _baseline().model_dump(mode="json"), txn_id=None)
    store.close()
    with pytest.raises(ProjectionError, match="first event"):
        make_store(tmp_path, memory_nv_counter(1))


@pytest.mark.parametrize("live", [0, 2])
def test_baseline_has_no_counter_increment_crash_gap(tmp_path: Path, live: int) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    store.adopt_boot_baseline(_baseline())
    store.close()
    with pytest.raises(StoreError, match="NV counter disagrees"):
        make_store(tmp_path, memory_nv_counter(live))


def test_baseline_rollback_floor_survives_app_blessing(tmp_path: Path) -> None:
    counter = memory_nv_counter(1)
    store = make_store(tmp_path, counter)
    store.adopt_boot_baseline(_baseline())
    _bless_app(store)
    store.close()
    counter.increment()
    with pytest.raises(StoreError, match="NV counter disagrees"):
        make_store(tmp_path, counter)


def test_baseline_establishes_catalog_floor(tmp_path: Path) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    store.adopt_boot_baseline(_baseline().model_copy(update={"catalog_hash": "f" * 64}))
    with pytest.raises(StoreError, match="stale catalog"):
        _bless_app(store)
    assert len(store.journal.read_verified()) == 1


def test_guard_verifies_baseline_without_mutating_history(tmp_path: Path) -> None:
    baseline = _baseline()
    store = make_store(tmp_path, memory_nv_counter(1))
    store.adopt_boot_baseline(baseline)
    verified: list[str] = []

    def forbidden() -> None:
        pytest.fail("baseline reconciliation must not reboot or change boot selection")

    deps = BootGuardDeps(
        store=store,
        observe_boot=lambda: baseline.observation,
        capture_health=lambda: baseline.health,
        verify_artifact=lambda artifact: verified.append(artifact.uki_path),
        mark_bad=forbidden,
        select_entry=lambda _: forbidden(),
        reboot=forbidden,
    )
    assert reconcile_boot(deps) is BootGuardResult.HEALTHY
    assert verified == [baseline.observation.entry_path]
    assert len(store.journal.read_verified()) == 1


def test_recovery_can_select_baseline_without_a_blessed_transaction(tmp_path: Path) -> None:
    baseline = _baseline()
    store = make_store(tmp_path, memory_nv_counter(1))
    store.adopt_boot_baseline(baseline)
    selected: list[str] = []
    verified: list[str] = []
    deps = RecoveryConsoleDeps(
        store=store,
        observe_boot=lambda: baseline.observation,
        verify_artifact=lambda artifact: verified.append(artifact.entry_id),
        select_entry=selected.append,
        reboot=lambda: None,
        poweroff=lambda: None,
    )
    assert run_console(["select-blessed"], deps) == 0
    assert selected == verified == [baseline.artifact.entry_id]


def test_baseline_revalidates_model_copy_before_append(tmp_path: Path) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    bad = _baseline().model_copy(update={"nv_counter": 2})
    with pytest.raises(pydantic.ValidationError):
        store.adopt_boot_baseline(bad)
    assert store.journal.read_verified() == []


@pytest.mark.parametrize(
    "field,value",
    [
        ("root_free_bytes", 0),
        ("esp_free_bytes", 0),
        ("inactive_critical_units", ["intentd-display-ready.service"]),
        ("display_ready", False),
    ],
)
def test_baseline_refuses_unhealthy_boot_evidence(field: str, value: object) -> None:
    evidence = _baseline().model_dump(mode="json")
    evidence["health"][field] = value
    with pytest.raises(pydantic.ValidationError):
        BootBaseline.model_validate(evidence)


def test_catalog_floor_is_also_enforced_during_replay(tmp_path: Path) -> None:
    store = make_store(tmp_path, memory_nv_counter(1))
    store.adopt_boot_baseline(_baseline().model_copy(update={"catalog_hash": "f" * 64}))
    store.journal.append_proposal(proposal_payload("firefox"))
    store.close()
    with pytest.raises(ProjectionError, match="stale catalog"):
        make_store(tmp_path, memory_nv_counter(1))


def test_boot_counter_floor_survives_later_app_blessing(tmp_path: Path) -> None:
    from tests.test_rollback_counter import _bless_boot_txn

    counter = memory_nv_counter(1)
    store = make_store(tmp_path, counter)
    store.adopt_boot_baseline(_baseline())
    _bless_boot_txn(store)
    assert counter.read() == 2
    _bless_app(store)
    store.close()
    counter.increment()
    with pytest.raises(StoreError, match="NV counter disagrees"):
        make_store(tmp_path, counter)


def test_first_boot_transaction_uses_baseline_and_can_recover(tmp_path: Path) -> None:
    from intentd.orchestrator import apply_intent
    from intentd.workspace import init_workspace
    from tests.test_orchestrator import _Fakes, _graphics, _make_deps

    baseline = _baseline()
    store = make_store(tmp_path, memory_nv_counter(1))
    store.adopt_boot_baseline(baseline)
    workspace = tmp_path / "workspace"
    init_workspace(workspace)
    fakes = _Fakes(closure="/nix/store/graphics-candidate", lock_pin="b" * 64)
    result = apply_intent(_make_deps(store, workspace, load_catalog(), fakes), _graphics())
    assert result.record is not None
    assert result.record.status is TxnStatus.PENDING
    assert result.record.boot_plan is not None
    assert result.record.boot_plan.prior_blessed.closure_path == baseline.artifact.closure_path
    deps = BootGuardDeps(
        store=store,
        observe_boot=lambda: baseline.observation,
        capture_health=lambda: baseline.health,
        verify_artifact=lambda _: None,
        mark_bad=lambda: pytest.fail("recovered boot must not be marked bad"),
        select_entry=lambda _: pytest.fail("already booted the fallback"),
        reboot=lambda: pytest.fail("already booted the fallback"),
    )
    assert reconcile_boot(deps) is BootGuardResult.RECOVERED
    assert store.get(result.record.id).status is TxnStatus.ABORTED
    assert store.blessed_state() == baseline.state
    assert store.blessed_boot_artifact() == baseline.artifact
