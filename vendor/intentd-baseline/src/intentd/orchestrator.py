from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from intentd.boot import (
    BootArtifact,
    BootError,
    BootPlan,
    BootStagingFailure,
    BootStagingPhase,
    HealthSnapshot,
)
from intentd.catalog import digest_catalog
from intentd.executor import ExecError, file_sha256, rendered_sha256
from intentd.health import new_failures
from intentd.machine import MachineProfile
from intentd.policy import PolicyDecision, PolicyVerdict, evaluate
from intentd.registry import REGISTRY, CapabilityInvocation, digest_invocation
from intentd.render import RenderError, render
from intentd.schema import CatalogApp
from intentd.state import StateError, apply_invocation
from intentd.store import TransactionStore
from intentd.txn import TransactionRecord, TxnStatus
from intentd.workspace import TamperError, repair_manifest, verify_workspace, write_generated

_INTERRUPTED = "interrupted by restart"
_INTERRUPTIBLE_BEFORE_PENDING = (TxnStatus.PROPOSED, TxnStatus.VALIDATED, TxnStatus.BUILT)
_GC_ROOTS = Path("/var/lib/intentd/gcroots")


class BootStagingError(Exception):
    pass


@dataclass(frozen=True)
class Deps:
    store: TransactionStore
    workspace: Path
    catalog: dict[str, CatalogApp]
    machine_profile: MachineProfile
    build: Callable[[Path], tuple[str, str]]
    set_profile: Callable[[str], None]
    activate: Callable[[str], int]
    failed_units: Callable[[], frozenset[str]]
    current_profile: Callable[[], str | None]
    capture_health: Callable[[], HealthSnapshot]
    inspect_candidate: Callable[[str], BootArtifact]
    verify_artifact: Callable[[BootArtifact], None]
    retain_artifact: Callable[[BootArtifact, str], None]
    recovery_artifact: Callable[[], BootArtifact]
    install_boot_candidate: Callable[[str, str, str], None]
    reboot: Callable[[], None]


@dataclass(frozen=True)
class ApplyResult:
    decision: PolicyDecision
    record: TransactionRecord | None


def _restore_to_blessed(deps: Deps, txn_id: int, pre_profile: str | None) -> None:
    rendered = render(deps.store.blessed_state(), deps.catalog, deps.machine_profile)
    write_generated(deps.workspace, rendered)
    blessed = deps.store.blessed()
    target = blessed.closure_path if blessed is not None else None
    if target is None:
        target = pre_profile
    if target is not None:
        deps.set_profile(target)
        deps.activate(target)
    else:
        deps.store.record_event(txn_id, "no restore target: system profile left on aborted closure")


def _abort(deps: Deps, txn_id: int, detail: str, pre_profile: str | None) -> TransactionRecord:
    deps.store.transition(txn_id, TxnStatus.ABORTED, detail=detail)
    try:
        _restore_to_blessed(deps, txn_id, pre_profile)
    except Exception as exc:
        deps.store.record_event(txn_id, f"restore to blessed failed: {exc}")
        # Restore failure propagates by design (deterministic recovery beyond
        # this is Stage 2); the recorded event makes it discoverable.
        raise
    return deps.store.get(txn_id)


def _apply_live_candidate(deps: Deps, txn: int, closure: str) -> TransactionRecord:
    baseline = deps.failed_units()
    pre_profile = deps.current_profile()
    deps.store.transition(txn, TxnStatus.PENDING)
    deps.set_profile(closure)
    activation_error: str | None = None
    try:
        deps.activate(closure)
    except ExecError as exc:
        activation_error = str(exc)

    fresh = new_failures(baseline, deps.failed_units())
    if activation_error is not None or fresh:
        detail = activation_error or f"health check found new failed units: {sorted(fresh)}"
        return _abort(deps, txn, detail, pre_profile)

    deps.store.transition(txn, TxnStatus.BLESSED)
    return deps.store.get(txn)


def _stage_boot_candidate(
    deps: Deps,
    txn: int,
    invocation: CapabilityInvocation,
    closure: str,
    rendered_hash: str,
    lock_pin: str,
) -> TransactionRecord:
    try:
        baseline = deps.capture_health()
        candidate = deps.inspect_candidate(closure)
        prior_blessed = deps.store.blessed_boot_artifact()
        if prior_blessed is None:
            raise BootStagingError("missing authenticated blessed boot anchor")
        deps.verify_artifact(prior_blessed)
        recovery = deps.recovery_artifact()
        deps.verify_artifact(recovery)
        deps.verify_artifact(candidate)
        if baseline.root_free_bytes < deps.machine_profile.root_reserve_bytes:
            raise BootStagingError("root free space is below the certified reserve")
        if baseline.esp_free_bytes < (
            deps.machine_profile.esp_reserve_bytes + candidate.uki_size_bytes
        ):
            raise BootStagingError("ESP free space cannot retain the reserve after installation")
        deps.retain_artifact(prior_blessed, "blessed")
        deps.retain_artifact(recovery, "recovery")
        candidate_role = f"candidate-{txn}"
        deps.retain_artifact(candidate, candidate_role)
        prior_blessed = prior_blessed.model_copy(update={"gc_root": str(_GC_ROOTS / "blessed")})
        recovery = recovery.model_copy(update={"gc_root": str(_GC_ROOTS / "recovery")})
        candidate = candidate.model_copy(update={"gc_root": str(_GC_ROOTS / candidate_role)})
    except (BootError, BootStagingError, ExecError) as exc:
        deps.store.transition(txn, TxnStatus.REJECTED, detail=str(exc))
        return deps.store.get(txn)

    plan = BootPlan(
        candidate=candidate,
        prior_blessed=prior_blessed,
        recovery=recovery,
        baseline=baseline,
        invocation_hash=digest_invocation(invocation),
        machine_profile_id=deps.machine_profile.profile_id,
        root_reserve_bytes=deps.machine_profile.root_reserve_bytes,
        esp_reserve_bytes=deps.machine_profile.esp_reserve_bytes,
        rendered_hash=rendered_hash,
        flake_lock_hash=lock_pin,
    )
    deps.store.transition(txn, TxnStatus.PENDING, boot_plan=plan)
    for phase, operation in (
        (BootStagingPhase.SET_PROFILE, lambda: deps.set_profile(closure)),
        (
            BootStagingPhase.INSTALL_CANDIDATE,
            lambda: deps.install_boot_candidate(
                closure,
                candidate.entry_id,
                prior_blessed.entry_id,
            ),
        ),
    ):
        try:
            operation()
        except ExecError as exc:
            failure = BootStagingFailure(
                candidate=candidate,
                phase=phase,
                detail=str(exc),
                quarantined=True,
            )
            deps.store.transition(
                txn,
                TxnStatus.ABORTED,
                boot_staging_failure=failure,
                detail=str(exc),
            )
            return deps.store.get(txn)
    deps.reboot()
    return deps.store.get(txn)


def apply_intent(
    deps: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
) -> ApplyResult:
    prev = deps.store.blessed_state()
    is_revert = invocation.capability == "change.revert"
    revert_target = deps.store.revert_target() if is_revert else None

    if is_revert:
        new = revert_target if revert_target is not None else prev
    else:
        try:
            new = apply_invocation(prev, invocation)
        except StateError as exc:
            decision = PolicyDecision(verdict=PolicyVerdict.REJECT, reason=str(exc))
            return ApplyResult(decision, None)

    decision = evaluate(
        invocation,
        deps.catalog,
        prev,
        new,
        machine_profile=deps.machine_profile,
        acknowledged_unfree=acks,
        revert_target=revert_target,
    )
    if decision.verdict is PolicyVerdict.REJECT:
        return ApplyResult(decision, None)
    if decision.verdict is PolicyVerdict.NEEDS_ACK and not set(decision.required_acks) <= acks:
        return ApplyResult(decision, None)

    boot_affecting = REGISTRY[invocation.capability].boot_affecting
    txn = deps.store.propose(
        invocation,
        prev,
        new,
        decision=decision,
        catalog_hash=digest_catalog(deps.catalog),
        acks=acks,
        machine_profile_id=deps.machine_profile.profile_id if boot_affecting else None,
    )

    try:
        rendered = render(new, deps.catalog, deps.machine_profile)
        write_generated(deps.workspace, rendered)
    except (RenderError, TamperError) as exc:
        deps.store.transition(txn, TxnStatus.REJECTED, detail=str(exc))
        return ApplyResult(decision, deps.store.get(txn))
    rendered_hash = rendered_sha256(rendered)
    deps.store.transition(txn, TxnStatus.VALIDATED, rendered_hash=rendered_hash)

    try:
        verify_workspace(deps.workspace)
        closure, lock_pin = deps.build(deps.workspace)
    except (ExecError, TamperError) as exc:
        deps.store.transition(txn, TxnStatus.REJECTED, detail=str(exc))
        return ApplyResult(decision, deps.store.get(txn))
    deps.store.transition(txn, TxnStatus.BUILT, closure_path=closure, flake_lock_hash=lock_pin)

    if boot_affecting:
        record = _stage_boot_candidate(deps, txn, invocation, closure, rendered_hash, lock_pin)
    else:
        record = _apply_live_candidate(deps, txn, closure)
    return ApplyResult(decision, record)


def startup_reconcile(deps: Deps) -> None:
    try:
        verify_workspace(deps.workspace)
    except TamperError:
        active = deps.store.active()
        generated = deps.workspace / "generated.nix"
        if (
            active is not None
            and active.rendered_hash is not None
            and generated.exists()
            and active.rendered_hash == file_sha256(generated)
        ):
            repair_manifest(deps.workspace)
        else:
            raise

    in_flight = deps.store.in_flight()
    if in_flight is None:
        return
    if in_flight.status is TxnStatus.PENDING and in_flight.boot_plan is None:
        _abort(deps, in_flight.id, _INTERRUPTED, None)
    elif in_flight.status in _INTERRUPTIBLE_BEFORE_PENDING:
        deps.store.transition(in_flight.id, TxnStatus.REJECTED, detail=_INTERRUPTED)
