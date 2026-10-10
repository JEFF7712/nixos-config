from enum import StrEnum

from pydantic import Field

from intentd.boot import (
    SHA256_PATTERN,
    BootArtifact,
    BootOutcome,
    BootPlan,
    BootStagingFailure,
)
from intentd.policy import PolicyDecision
from intentd.registry import CapabilityInvocation
from intentd.schema import ClosedModel
from intentd.state import DesiredState


class TxnStatus(StrEnum):
    PROPOSED = "proposed"
    VALIDATED = "validated"
    BUILT = "built"
    PENDING = "pending"
    BLESSED = "blessed"
    REJECTED = "rejected"
    ABORTED = "aborted"


LEGAL_TRANSITIONS: dict[TxnStatus, frozenset[TxnStatus]] = {
    TxnStatus.PROPOSED: frozenset({TxnStatus.VALIDATED, TxnStatus.REJECTED}),
    TxnStatus.VALIDATED: frozenset({TxnStatus.BUILT, TxnStatus.REJECTED}),
    TxnStatus.BUILT: frozenset({TxnStatus.PENDING, TxnStatus.REJECTED}),
    TxnStatus.PENDING: frozenset({TxnStatus.BLESSED, TxnStatus.ABORTED}),
    TxnStatus.BLESSED: frozenset(),
    TxnStatus.REJECTED: frozenset(),
    TxnStatus.ABORTED: frozenset(),
}

TERMINAL_STATUSES: frozenset[TxnStatus] = frozenset(
    {TxnStatus.BLESSED, TxnStatus.REJECTED, TxnStatus.ABORTED}
)


class TransitionError(Exception):
    pass


NV_COUNTER_MAX = 2**64 - 1


class TransactionRecord(ClosedModel):
    id: int
    status: TxnStatus
    catalog_hash: str = Field(pattern=SHA256_PATTERN)
    nv_counter: int | None = Field(default=None, ge=0, le=NV_COUNTER_MAX)
    invocation: CapabilityInvocation
    prev_state: DesiredState
    new_state: DesiredState
    decision: PolicyDecision
    acks: tuple[str, ...] = ()
    machine_profile_id: str | None = None
    rendered_hash: str | None = None
    flake_lock_hash: str | None = None
    closure_path: str | None = None
    boot_artifact: BootArtifact | None = None
    boot_plan: BootPlan | None = None
    boot_outcome: BootOutcome | None = None
    boot_staging_failure: BootStagingFailure | None = None
    detail: str | None = None
