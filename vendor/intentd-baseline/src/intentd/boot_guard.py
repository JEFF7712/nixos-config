import os
import sys
from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

from intentd import boot, executor
from intentd.boot import (
    BootArtifact,
    BootError,
    BootObservation,
    BootOutcome,
    HealthSnapshot,
    entry_path_matches,
    evaluate_boot_health,
)
from intentd.executor import ExecError
from intentd.journal import AuthenticatedJournal, JournalError, load_journal_key
from intentd.machine import load_machine_profile
from intentd.registry import digest_invocation
from intentd.store import StoreError, TransactionStore
from intentd.tpm import TpmError, system_counter
from intentd.txn import TransitionError, TxnStatus

_STATE_DIR = Path("/var/lib/intentd")
_MACHINE_PROFILE = Path("/etc/intentd/machine-profile.json")


class BootGuardError(Exception):
    pass


@dataclass(frozen=True)
class BootGuardDeps:
    store: TransactionStore
    observe_boot: Callable[[], BootObservation]
    capture_health: Callable[[], HealthSnapshot]
    verify_artifact: Callable[[BootArtifact], None]
    mark_bad: Callable[[], None]
    select_entry: Callable[[str], None]
    reboot: Callable[[], None]


class BootGuardResult(StrEnum):
    HEALTHY = "healthy"
    RECOVERED = "recovered"
    REBOOTING = "rebooting"


def _matches(observation: BootObservation, artifact: BootArtifact) -> bool:
    return (
        observation.closure_path == artifact.closure_path
        and observation.entry_id == artifact.entry_id
        and entry_path_matches(artifact.entry_id, observation.entry_path)
    )


def _verify_observed_artifact(
    deps: BootGuardDeps,
    observation: BootObservation,
    artifact: BootArtifact,
) -> None:
    deps.verify_artifact(artifact.model_copy(update={"uki_path": observation.entry_path}))


def _recovered_outcome(
    observation: BootObservation,
    health: HealthSnapshot,
    role: str,
) -> BootOutcome:
    failure = (
        "candidate interrupted before blessing"
        if role == "prior blessed boot"
        else f"candidate was bypassed for authenticated {role}"
    )
    return BootOutcome(
        healthy=False,
        recovered=True,
        quarantined=True,
        observation=observation,
        health=health,
        failures=(failure,),
    )


def reconcile_boot(deps: BootGuardDeps) -> BootGuardResult:
    deps.store.journal.read_verified()
    observation = deps.observe_boot()
    pending = deps.store.in_flight()
    if pending is None:
        artifact = deps.store.blessed_boot_artifact()
        if artifact is None:
            raise BootGuardError("current boot has no authenticated blessed anchor")
        if not _matches(observation, artifact):
            raise BootGuardError("current boot does not match the authenticated blessed anchor")
        _verify_observed_artifact(deps, observation, artifact)
        return BootGuardResult.HEALTHY

    if pending.status is not TxnStatus.PENDING or pending.boot_plan is None:
        raise BootGuardError("in-flight transaction has no authenticated boot plan")
    plan = pending.boot_plan
    if digest_invocation(pending.invocation) != plan.invocation_hash:
        raise BootGuardError("pending boot plan invocation does not match the transaction")

    if _matches(observation, plan.candidate):
        _verify_observed_artifact(deps, observation, plan.candidate)
        outcome = evaluate_boot_health(plan, observation, deps.capture_health())
        if outcome.healthy:
            deps.store.transition(pending.id, TxnStatus.BLESSED, boot_outcome=outcome)
            return BootGuardResult.HEALTHY
        deps.store.transition(pending.id, TxnStatus.ABORTED, boot_outcome=outcome)
        deps.verify_artifact(plan.prior_blessed)
        deps.mark_bad()
        deps.select_entry(plan.prior_blessed.entry_id)
        deps.reboot()
        return BootGuardResult.REBOOTING

    for role, artifact in (
        ("prior blessed boot", plan.prior_blessed),
        ("recovery boot", plan.recovery),
    ):
        if _matches(observation, artifact):
            _verify_observed_artifact(deps, observation, artifact)
            outcome = _recovered_outcome(observation, deps.capture_health(), role)
            deps.store.transition(pending.id, TxnStatus.ABORTED, boot_outcome=outcome)
            return BootGuardResult.RECOVERED

    deps.verify_artifact(plan.recovery)
    deps.select_entry(plan.recovery.entry_id)
    deps.reboot()
    return BootGuardResult.REBOOTING


def _production_deps() -> BootGuardDeps:
    state_dir = Path(os.environ.get("INTENTD_STATE_DIR", _STATE_DIR))
    machine_profile_path = Path(os.environ.get("INTENTD_MACHINE_PROFILE", _MACHINE_PROFILE))
    journal = AuthenticatedJournal(state_dir, load_journal_key())
    store = TransactionStore(
        state_dir / "txn.db", journal, tpm_counter=system_counter(state_dir / "nv-counter.bin")
    )
    machine_profile = load_machine_profile(machine_profile_path)
    return BootGuardDeps(
        store=store,
        observe_boot=boot.observe_boot,
        capture_health=lambda: boot.capture_health(machine_profile),
        verify_artifact=boot.verify_artifact,
        mark_bad=executor.mark_boot_bad,
        select_entry=executor.set_oneshot,
        reboot=executor.reboot,
    )


def main() -> int:
    if sys.argv[1:]:
        return 2
    try:
        reconcile_boot(_production_deps())
    except (
        BootError,
        BootGuardError,
        ExecError,
        JournalError,
        OSError,
        StoreError,
        TpmError,
        TransitionError,
        ValueError,
    ) as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0
