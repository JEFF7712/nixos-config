# Stage 2 Staging Evidence Correction

Date: 2026-08-23

## Purpose

Repair two gaps in the Stage 2 boot reliability contract before implementing
boot staging:

1. Candidate staging must prove both root filesystem and EFI System Partition
   capacity, but the current health and machine-profile models only represent
   root capacity.
2. A failure after the transaction becomes pending but before reboot is not a
   boot attempt. It cannot truthfully be represented by `BootOutcome`, because
   that model requires an observed boot identity.

The correction preserves the authenticated journal as the sole authority and
keeps SQLite as a reconstructible projection.

## Capacity Evidence

`MachineProfile` gains `esp_reserve_bytes`, a positive certified minimum.
`HealthSnapshot` gains `esp_free_bytes`, a nonnegative observation captured
from `/boot` with `statvfs`.

`BootArtifact` gains a positive `uki_size_bytes` field. Artifact inspection
records the exact size alongside the existing hash. `capture_health` records
root and ESP free bytes in the same snapshot. Boot staging rejects a candidate
before entering pending when root free space is below the root reserve or when
ESP free space is less than the ESP reserve plus the candidate UKI size. The
snapshot stored in `BootPlan` remains the complete pre-change baseline for
relative unit-health evaluation.

Post-boot health evaluates capacity against the certified reserves, not the
raw pre-install free-space values. Comparing ESP free space directly with its
baseline would reject every successful UKI installation. To make the thresholds
replayable without loading mutable host configuration, `BootPlan` gains
`root_reserve_bytes` and `esp_reserve_bytes`. Both values must be positive and
are bound to the machine profile used to authorize and render the transaction.

## Staging Failure Evidence

Add these closed models:

```python
class BootStagingPhase(StrEnum):
    SET_PROFILE = "set-profile"
    INSTALL_CANDIDATE = "install-candidate"


class BootStagingFailure(ClosedModel):
    candidate: BootArtifact
    phase: BootStagingPhase
    detail: str
    quarantined: Literal[True] = True
```

The candidate must exactly equal the candidate in the authenticated boot plan.
The detail must be nonempty. The closed phase enum prevents arbitrary workflow
states from entering the journal.

`TransactionRecord` gains `boot_staging_failure`. Transition payloads and the
SQLite projection gain the matching optional JSON field.

For a boot-affecting transaction moving from `PENDING` to `ABORTED`, exactly one
failure form is legal:

- `boot_outcome`: an actual boot was observed, evaluated, and quarantined.
- `boot_staging_failure`: profile selection or candidate installation failed
  before reboot.

Replay applies the same exclusivity, candidate-identity, quarantine, and phase
checks as the pre-append store boundary. Non-boot transactions reject both
forms. Blessing still requires a healthy `BootOutcome`; staging evidence can
never bless a transaction.

## Staging Flow

For a boot-affecting transaction, orchestration performs this sequence:

1. Capture the complete baseline.
2. Inspect and verify the candidate artifact.
3. Reject insufficient root or ESP capacity, including the candidate UKI size.
4. Require and verify the current blessed anchor.
5. Load and verify the fixed recovery artifact.
6. Retain blessed and recovery closures through their fixed GC roots.
7. Append `PENDING` with the complete authenticated `BootPlan`.
8. Set the system profile.
9. Install the candidate boot entry.
10. Request reboot.

If steps 8 or 9 fail, append `ABORTED` with `BootStagingFailure` before
returning. No reboot is requested. If the reboot request itself fails, retain
the pending transaction: the candidate and pending evidence already agree, so
the request can be retried without inventing a staging or boot failure.

Application transactions retain the existing live activation and health path.

## Boot Guard Boundary

The boot guard consumes only actual `BootObservation` and `HealthSnapshot`
values. It never constructs staging evidence. A pending boot plan observed on
the prior blessed or recovery artifact is aborted with a recovered
`BootOutcome`. A matching unhealthy candidate is aborted with a failed,
quarantined `BootOutcome`. Unknown identity remains fail-closed.

## Testing

Tests must prove:

- machine profiles require positive root and ESP reserves;
- boot artifacts authenticate a positive UKI size;
- health capture records both filesystems;
- staging stops before pending for insufficient root or ESP capacity;
- profile and installation failures append authenticated staging evidence
  before returning and never request reboot;
- replay rejects missing, duplicate, mismatched, or non-quarantined staging
  evidence;
- a staging failure cannot be used to bless;
- reconstruction preserves the new JSON field exactly;
- existing non-boot activation behavior is unchanged;
- post-boot health uses authenticated reserve thresholds and never consults
  network or model availability.

## Scope

This correction does not add a second state file, free-form commands, network
checks, model access, retry loops, TPM binding, or physical-machine
certification. It changes only the evidence needed to implement the existing
Stage 2 milestone safely.
