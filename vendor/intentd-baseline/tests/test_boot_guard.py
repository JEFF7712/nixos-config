from collections.abc import Callable
from pathlib import Path
from typing import cast

import pytest

import intentd.boot_guard as boot_guard
from intentd.boot import BootArtifact, BootObservation, HealthSnapshot
from intentd.boot_guard import BootGuardDeps, BootGuardError, BootGuardResult, reconcile_boot
from intentd.catalog import digest_catalog, load_catalog
from intentd.executor import ExecError
from intentd.journal import JournalError
from intentd.policy import evaluate
from intentd.registry import digest_invocation, resolve_invocation
from intentd.state import DesiredState, apply_invocation
from intentd.store import TransactionStore
from intentd.txn import TxnStatus
from tests.helpers import (
    boot_artifact_fixture,
    boot_plan_fixture,
    make_store,
    memory_nv_counter,
    vm_machine_profile,
)

_CATALOG_HASH = digest_catalog(load_catalog())


class _Fakes:
    def __init__(
        self,
        observation: BootObservation,
        *,
        health: HealthSnapshot | None = None,
        reboot_fails: bool = False,
        assert_durable: Callable[[], None] | None = None,
    ) -> None:
        self.observation = observation
        self.health = health or boot_plan_fixture().baseline
        self.reboot_fails = reboot_fails
        self.assert_durable = assert_durable
        self.calls: list[tuple[str, ...]] = []
        self.verified_paths: list[str] = []

    def observe_boot(self) -> BootObservation:
        self.calls.append(("observe",))
        return self.observation

    def capture_health(self) -> HealthSnapshot:
        self.calls.append(("capture-health",))
        return self.health

    def verify_artifact(self, artifact: BootArtifact) -> None:
        self.calls.append(("verify", artifact.entry_id))
        self.verified_paths.append(artifact.uki_path)

    def mark_bad(self) -> None:
        if self.assert_durable is not None:
            self.assert_durable()
        self.calls.append(("mark-bad",))

    def select_entry(self, entry_id: str) -> None:
        if self.assert_durable is not None:
            self.assert_durable()
        self.calls.append(("select-entry", entry_id))

    def reboot(self) -> None:
        if self.assert_durable is not None:
            self.assert_durable()
        self.calls.append(("reboot",))
        if self.reboot_fails:
            raise ExecError("reboot failed")


def _observation(artifact: BootArtifact) -> BootObservation:
    return BootObservation(
        closure_path=artifact.closure_path,
        entry_id=artifact.entry_id,
        entry_path=artifact.uki_path,
    )


def _seed_blessed(store: TransactionStore) -> int:
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    previous = DesiredState()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=None)
    txn = store.propose(
        invocation, previous, desired, decision=decision, catalog_hash=_CATALOG_HASH
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="f" * 64)
    store.transition(
        txn,
        TxnStatus.BUILT,
        closure_path="/nix/store/blessed",
        flake_lock_hash="e" * 64,
    )
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)
    store.anchor_blessed_boot(
        txn,
        boot_artifact_fixture(
            closure_path="/nix/store/blessed",
            entry_id="blessed.efi",
            uki_sha256="d" * 64,
        ),
    )
    return txn


def _seed_pending(tmp_path: Path) -> tuple[TransactionStore, int, int]:
    store = make_store(tmp_path, tpm_counter=memory_nv_counter())
    blessed_txn = _seed_blessed(store)
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "hardware.graphics.profile", {"profile": "integrated"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    profile = vm_machine_profile()
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=profile)
    pending_txn = store.propose(
        invocation,
        previous,
        desired,
        decision=decision,
        machine_profile_id=profile.profile_id,
        catalog_hash=_CATALOG_HASH,
    )
    plan = boot_plan_fixture()
    store.transition(pending_txn, TxnStatus.VALIDATED, rendered_hash=plan.rendered_hash)
    store.transition(
        pending_txn,
        TxnStatus.BUILT,
        closure_path=plan.candidate.closure_path,
        flake_lock_hash=plan.flake_lock_hash,
    )
    store.transition(pending_txn, TxnStatus.PENDING, boot_plan=plan)
    return store, blessed_txn, pending_txn


def _deps(store: TransactionStore, fakes: _Fakes) -> BootGuardDeps:
    return BootGuardDeps(
        store=store,
        observe_boot=fakes.observe_boot,
        capture_health=fakes.capture_health,
        verify_artifact=fakes.verify_artifact,
        mark_bad=fakes.mark_bad,
        select_entry=fakes.select_entry,
        reboot=fakes.reboot,
    )


def test_matching_healthy_candidate_is_blessed_before_success(tmp_path: Path) -> None:
    store, _blessed_txn, pending_txn = _seed_pending(tmp_path)
    plan = boot_plan_fixture()
    fakes = _Fakes(_observation(plan.candidate))

    result = reconcile_boot(_deps(store, fakes))

    assert result is BootGuardResult.HEALTHY
    record = store.get(pending_txn)
    assert record.status is TxnStatus.BLESSED
    assert record.boot_outcome is not None and record.boot_outcome.healthy
    assert fakes.calls == [
        ("observe",),
        ("verify", "graphics-candidate.efi"),
        ("capture-health",),
    ]


@pytest.mark.parametrize(
    ("txn_profile", "plan_profile"),
    [("integrated", "hybrid-nvidia"), ("hybrid-nvidia", "integrated")],
)
def test_wrong_intent_candidate_never_blesses(
    tmp_path: Path, txn_profile: str, plan_profile: str
) -> None:
    store = make_store(tmp_path)
    blessed_txn = _seed_blessed(store)
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "hardware.graphics.profile", {"profile": txn_profile})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    profile = vm_machine_profile()
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=profile)
    pending_txn = store.propose(
        invocation,
        previous,
        desired,
        decision=decision,
        catalog_hash=_CATALOG_HASH,
        machine_profile_id=profile.profile_id,
    )
    plan_invocation = resolve_invocation(
        catalog, "hardware.graphics.profile", {"profile": plan_profile}
    )
    plan = boot_plan_fixture(invocation_hash=digest_invocation(plan_invocation))
    store.transition(pending_txn, TxnStatus.VALIDATED, rendered_hash=plan.rendered_hash)
    store.transition(
        pending_txn,
        TxnStatus.BUILT,
        closure_path=plan.candidate.closure_path,
        flake_lock_hash=plan.flake_lock_hash,
    )
    store.transition(pending_txn, TxnStatus.PENDING, boot_plan=plan)
    fakes = _Fakes(_observation(plan.candidate))

    with pytest.raises(BootGuardError, match="invocation"):
        reconcile_boot(_deps(store, fakes))

    assert store.get(pending_txn).status is TxnStatus.PENDING
    blessed = store.blessed()
    active = store.active()
    assert blessed is not None and blessed.id == blessed_txn
    assert active is not None and active.id == pending_txn
    assert fakes.calls == [("observe",)]


def test_counted_candidate_rename_verifies_observed_uki_and_blesses(
    tmp_path: Path,
) -> None:
    store, _blessed_txn, pending_txn = _seed_pending(tmp_path)
    plan = boot_plan_fixture()
    counted_path = "/boot/EFI/Linux/graphics-candidate+0-1.efi"
    observation = _observation(plan.candidate).model_copy(update={"entry_path": counted_path})
    fakes = _Fakes(observation)

    result = reconcile_boot(_deps(store, fakes))

    assert result is BootGuardResult.HEALTHY
    assert store.get(pending_txn).status is TxnStatus.BLESSED
    assert fakes.verified_paths == [counted_path]


def test_matching_unhealthy_candidate_aborts_before_mark_bad_and_reboot(
    tmp_path: Path,
) -> None:
    store, _blessed_txn, pending_txn = _seed_pending(tmp_path)
    plan = boot_plan_fixture()
    health = plan.baseline.model_copy(update={"display_ready": False})

    def assert_aborted() -> None:
        assert store.get(pending_txn).status is TxnStatus.ABORTED

    fakes = _Fakes(
        _observation(plan.candidate),
        health=health,
        assert_durable=assert_aborted,
    )

    result = reconcile_boot(_deps(store, fakes))

    assert result is BootGuardResult.REBOOTING
    record = store.get(pending_txn)
    assert record.status is TxnStatus.ABORTED
    assert record.boot_outcome is not None and record.boot_outcome.quarantined
    assert fakes.calls[-4:] == [
        ("verify", "blessed.efi"),
        ("mark-bad",),
        ("select-entry", "blessed.efi"),
        ("reboot",),
    ]


@pytest.mark.parametrize(
    ("role", "expected_failure"),
    [
        ("prior_blessed", "candidate interrupted before blessing"),
        ("recovery", "candidate was bypassed for authenticated recovery boot"),
    ],
)
def test_authenticated_fallback_aborts_as_recovered(
    tmp_path: Path,
    role: str,
    expected_failure: str,
) -> None:
    store, blessed_txn, pending_txn = _seed_pending(tmp_path)
    plan = boot_plan_fixture()
    artifact = getattr(plan, role)
    fakes = _Fakes(_observation(artifact))

    result = reconcile_boot(_deps(store, fakes))

    assert result is BootGuardResult.RECOVERED
    record = store.get(pending_txn)
    assert record.status is TxnStatus.ABORTED
    assert record.boot_outcome is not None and record.boot_outcome.recovered
    assert record.boot_outcome.failures == (expected_failure,)
    active = store.active()
    assert active is not None and active.id == blessed_txn
    assert ("mark-bad",) not in fakes.calls
    assert ("reboot",) not in fakes.calls


def test_no_pending_matching_blessed_is_healthy_without_mutation(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    blessed_txn = _seed_blessed(store)
    artifact = store.get(blessed_txn).boot_artifact
    assert artifact is not None
    fakes = _Fakes(_observation(artifact))

    result = reconcile_boot(_deps(store, fakes))

    assert result is BootGuardResult.HEALTHY
    assert store.get(blessed_txn).status is TxnStatus.BLESSED
    assert fakes.calls == [("observe",), ("verify", "blessed.efi")]


@pytest.mark.parametrize(
    "observation",
    [
        BootObservation(
            closure_path="/nix/store/unknown",
            entry_id="graphics-candidate.efi",
            entry_path="/boot/EFI/Linux/graphics-candidate.efi",
        ),
        BootObservation(
            closure_path="/nix/store/graphics-candidate",
            entry_id="unknown.efi",
            entry_path="/boot/EFI/Linux/unknown.efi",
        ),
    ],
)
def test_unknown_boot_selects_authenticated_recovery_once_and_reboots(
    tmp_path: Path, observation: BootObservation
) -> None:
    store, _blessed_txn, pending_txn = _seed_pending(tmp_path)
    fakes = _Fakes(observation)

    result = reconcile_boot(_deps(store, fakes))

    assert result is BootGuardResult.REBOOTING
    assert store.get(pending_txn).status is TxnStatus.PENDING
    assert fakes.calls[-3:] == [
        ("verify", "recovery.efi"),
        ("select-entry", "recovery.efi"),
        ("reboot",),
    ]


def test_reboot_failure_on_unknown_identity_propagates_without_blessing(
    tmp_path: Path,
) -> None:
    store, _blessed_txn, pending_txn = _seed_pending(tmp_path)
    unknown = BootObservation(
        closure_path="/nix/store/unknown",
        entry_id="unknown.efi",
        entry_path="/boot/EFI/Linux/unknown.efi",
    )
    fakes = _Fakes(unknown, reboot_fails=True)

    with pytest.raises(ExecError, match="reboot failed"):
        reconcile_boot(_deps(store, fakes))

    assert store.get(pending_txn).status is TxnStatus.PENDING


def test_invalid_journal_fails_before_observation_or_blessing(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    blessed_txn = _seed_blessed(store)
    artifact = store.get(blessed_txn).boot_artifact
    assert artifact is not None
    journal_path = tmp_path / "journal.jsonl"
    journal_path.write_text(journal_path.read_text().replace("firefox", "chromium", 1))
    fakes = _Fakes(_observation(artifact))

    with pytest.raises(JournalError, match="invalid MAC"):
        reconcile_boot(_deps(store, fakes))

    assert fakes.calls == []
    assert store.get(blessed_txn).status is TxnStatus.BLESSED


@pytest.mark.parametrize(
    ("result", "expected"),
    [
        (BootGuardResult.HEALTHY, 0),
        (BootGuardResult.RECOVERED, 0),
        (BootGuardResult.REBOOTING, 0),
    ],
)
def test_main_exit_status_matches_guard_result(
    monkeypatch: pytest.MonkeyPatch,
    result: BootGuardResult,
    expected: int,
) -> None:
    deps = cast(BootGuardDeps, object())

    def reconcile(actual: BootGuardDeps) -> BootGuardResult:
        assert actual is deps
        return result

    monkeypatch.setattr(boot_guard, "_production_deps", lambda: deps)
    monkeypatch.setattr(boot_guard, "reconcile_boot", reconcile)
    monkeypatch.setattr(boot_guard.sys, "argv", ["intentd-boot-guard"])

    assert boot_guard.main() == expected


def test_main_returns_nonzero_when_authenticated_state_is_invalid(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    deps = cast(BootGuardDeps, object())
    monkeypatch.setattr(boot_guard, "_production_deps", lambda: deps)

    def fail(_deps: BootGuardDeps) -> BootGuardResult:
        raise JournalError("invalid MAC")

    monkeypatch.setattr(boot_guard, "reconcile_boot", fail)
    monkeypatch.setattr(boot_guard.sys, "argv", ["intentd-boot-guard"])

    assert boot_guard.main() == 1
    assert capsys.readouterr().err == "invalid MAC\n"


def test_main_rejects_arguments(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(boot_guard.sys, "argv", ["intentd-boot-guard", "shell-text"])

    assert boot_guard.main() == 2
