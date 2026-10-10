import json
import re
import sqlite3
from pathlib import Path
from typing import cast

from pydantic import JsonValue

from intentd.boot import (
    SHA256_PATTERN,
    BootArtifact,
    BootBaseline,
    BootOutcome,
    BootPlan,
    BootStagingFailure,
    entry_path_matches,
)
from intentd.journal import AuthenticatedJournal, JournalRecord, Payload
from intentd.policy import PolicyDecision, PolicyVerdict
from intentd.projection import rebuild_projection
from intentd.registry import REGISTRY, CapabilityInvocation
from intentd.state import DesiredState
from intentd.tpm import NvCounter
from intentd.txn import (
    LEGAL_TRANSITIONS,
    NV_COUNTER_MAX,
    TERMINAL_STATUSES,
    TransactionRecord,
    TransitionError,
    TxnStatus,
)


class StoreError(Exception):
    pass


def _is_healthy_candidate_outcome(outcome: BootOutcome | None, plan: BootPlan) -> bool:
    if outcome is None:
        return False
    observation = outcome.observation
    return (
        outcome.healthy
        and not outcome.recovered
        and not outcome.quarantined
        and not outcome.failures
        and observation.closure_path == plan.candidate.closure_path
        and observation.entry_id == plan.candidate.entry_id
        and entry_path_matches(plan.candidate.entry_id, observation.entry_path)
    )


def _is_failed_quarantined_outcome(outcome: BootOutcome | None) -> bool:
    return bool(
        outcome is not None and not outcome.healthy and outcome.quarantined and outcome.failures
    )


def _valid_staging_failure(
    failure: BootStagingFailure | None,
    plan: BootPlan | None,
) -> bool:
    return bool(
        failure is not None
        and plan is not None
        and failure.quarantined
        and failure.candidate == plan.candidate
    )


class TransactionStore:
    def __init__(
        self,
        db_path: Path,
        journal: AuthenticatedJournal,
        *,
        tpm_counter: NvCounter | None = None,
    ) -> None:
        self._db_path = db_path
        self._journal = journal
        self._tpm_counter = tpm_counter
        self._conn: sqlite3.Connection
        with journal.exclusive():
            records = journal.read_verified_locked()
            if not records:
                self._reject_legacy_state()
            self._replace_projection(records)
            self._verify_rollback_counter()

    @property
    def journal(self) -> AuthenticatedJournal:
        return self._journal

    def close(self) -> None:
        self._conn.close()

    def propose(
        self,
        invocation: CapabilityInvocation,
        prev_state: DesiredState,
        new_state: DesiredState,
        *,
        decision: PolicyDecision,
        catalog_hash: str,
        acks: frozenset[str] = frozenset(),
        machine_profile_id: str | None = None,
    ) -> int:
        if decision.verdict is PolicyVerdict.REJECT:
            raise StoreError("decision is not authorized for proposal")
        if re.fullmatch(SHA256_PATTERN, catalog_hash) is None:
            raise StoreError("proposal requires a SHA-256 catalog hash")
        if not set(decision.required_acks) <= acks:
            missing = sorted(set(decision.required_acks) - acks)
            raise StoreError(f"unacknowledged requirements: {missing}")
        boot_affecting = REGISTRY[invocation.capability].boot_affecting
        if boot_affecting and not machine_profile_id:
            raise StoreError("boot transaction requires an authenticated machine profile")
        if not boot_affecting and machine_profile_id is not None:
            raise StoreError("non-boot transaction cannot carry a machine profile")
        with self._journal.exclusive():
            records = self._journal.read_verified_locked()
            self._replace_projection(records)
            row = self._conn.execute(
                "SELECT id FROM transactions WHERE status NOT IN (?, ?, ?)",
                tuple(TERMINAL_STATUSES),
            ).fetchone()
            if row is not None:
                raise StoreError(f"transaction {row[0]} is still in flight")
            if not self._catalog_floor_satisfied(catalog_hash):
                raise StoreError(
                    "stale catalog: catalog hash does not match the blessed transaction"
                )
            payload: Payload = {
                "catalog_hash": catalog_hash,
                "invocation": cast(JsonValue, invocation.model_dump(mode="json")),
                "prev_state": cast(JsonValue, prev_state.model_dump(mode="json")),
                "new_state": cast(JsonValue, new_state.model_dump(mode="json")),
                "decision": cast(JsonValue, decision.model_dump(mode="json")),
                "acks": cast(JsonValue, sorted(acks)),
                "machine_profile_id": machine_profile_id,
            }
            record = self._journal.append_proposal_locked(payload, records)
            self._rebuild([*records, record])
        if record.txn_id is None:
            raise StoreError("proposal did not receive a transaction ID")
        return record.txn_id

    def transition(
        self,
        txn_id: int,
        to_status: TxnStatus,
        *,
        rendered_hash: str | None = None,
        flake_lock_hash: str | None = None,
        closure_path: str | None = None,
        boot_plan: BootPlan | None = None,
        boot_outcome: BootOutcome | None = None,
        boot_staging_failure: BootStagingFailure | None = None,
        detail: str | None = None,
    ) -> None:
        with self._journal.exclusive():
            records = self._journal.read_verified_locked()
            self._replace_projection(records)
            current = self._status(txn_id)
            if to_status not in LEGAL_TRANSITIONS[current]:
                raise TransitionError(f"illegal transition {current} -> {to_status}")
            if to_status is TxnStatus.VALIDATED and not rendered_hash:
                raise TransitionError("validated requires rendered_hash")
            if to_status is TxnStatus.BUILT and (not closure_path or not flake_lock_hash):
                raise TransitionError("built requires closure_path and flake_lock_hash")
            if to_status is TxnStatus.BLESSED and self._pointer("active") != txn_id:
                raise TransitionError("only the active transaction can be blessed")
            transaction = self.get(txn_id)
            self._validate_boot_transition(
                transaction,
                to_status,
                boot_plan=boot_plan,
                boot_outcome=boot_outcome,
                boot_staging_failure=boot_staging_failure,
            )
            nv_counter = self._prepare_boot_blessing(transaction, to_status)
            existing = self._conn.execute(
                "SELECT rendered_hash, flake_lock_hash, closure_path"
                " FROM transactions WHERE id = ?",
                (txn_id,),
            ).fetchone()
            for name, incoming, stored in (
                ("rendered_hash", rendered_hash, existing[0]),
                ("flake_lock_hash", flake_lock_hash, existing[1]),
                ("closure_path", closure_path, existing[2]),
            ):
                if incoming is not None and stored is not None:
                    raise TransitionError(f"{name} is already pinned")
            payload: Payload = {
                "from_status": current.value,
                "to_status": to_status.value,
                "rendered_hash": rendered_hash,
                "flake_lock_hash": flake_lock_hash,
                "closure_path": closure_path,
                "nv_counter": nv_counter,
                "boot_plan": (
                    None
                    if boot_plan is None
                    else cast(JsonValue, boot_plan.model_dump(mode="json"))
                ),
                "boot_outcome": (
                    None
                    if boot_outcome is None
                    else cast(JsonValue, boot_outcome.model_dump(mode="json"))
                ),
                "boot_staging_failure": (
                    None
                    if boot_staging_failure is None
                    else cast(
                        JsonValue,
                        boot_staging_failure.model_dump(mode="json"),
                    )
                ),
                "detail": detail,
            }
            record = self._journal.append_locked(
                "transaction.transition", payload, txn_id=txn_id, records=records
            )
            self._rebuild([*records, record])
            self._confirm_boot_blessing(nv_counter)

    def _prepare_boot_blessing(
        self, transaction: TransactionRecord, to_status: TxnStatus
    ) -> int | None:
        if to_status is not TxnStatus.BLESSED:
            return None
        if not REGISTRY[transaction.invocation.capability].boot_affecting:
            return None
        counter = self._tpm_counter
        if counter is None:
            raise TransitionError("boot blessing requires an NV rollback counter")
        recorded = self._recorded_nv_counter()
        live = counter.read()
        if recorded is not None:
            if live > recorded:
                raise TransitionError("NV counter is ahead of the journal")
            if live == recorded - 1:
                live = counter.increment()
                if live != recorded:
                    raise TransitionError("NV counter repair diverged from the journal")
            elif live < recorded - 1:
                raise TransitionError("NV counter is behind the journal")
        if live >= NV_COUNTER_MAX:
            raise TransitionError("NV rollback counter is exhausted")
        return live + 1

    def _confirm_boot_blessing(self, nv_counter: int | None) -> None:
        if nv_counter is None or self._tpm_counter is None:
            return
        if self._tpm_counter.increment() != nv_counter:
            raise TransitionError("NV counter advanced out of band during blessing")

    def _verify_rollback_counter(self) -> None:
        recorded = self._recorded_nv_counter()
        if recorded is None:
            return
        counter = self._tpm_counter
        if counter is None:
            raise StoreError("counter-bound state requires an NV rollback counter")
        live = counter.read()
        baseline_only = recorded == 1 and self.boot_baseline() is not None
        if live != recorded and (baseline_only or live != recorded - 1):
            raise StoreError("NV counter disagrees with the blessed transaction")

    def _recorded_nv_counter(self) -> int | None:
        row = self._conn.execute(
            "SELECT nv_counter FROM transactions WHERE nv_counter IS NOT NULL ORDER BY id DESC LIMIT 1"
        ).fetchone()
        if row is not None:
            return int(row[0])
        baseline = self.boot_baseline()
        return None if baseline is None else baseline.nv_counter

    def boot_baseline(self) -> BootBaseline | None:
        row = self._conn.execute("SELECT evidence FROM boot_baseline").fetchone()
        return None if row is None else BootBaseline.model_validate_json(row[0])

    def adopt_boot_baseline(self, baseline: BootBaseline) -> None:
        baseline = BootBaseline.model_validate_json(baseline.model_dump_json())
        with self._journal.exclusive():
            records = self._journal.read_verified_locked()
            self._replace_projection(records)
            if records:
                raise StoreError("boot baseline adoption requires an empty journal")
            if self._tpm_counter is None or self._tpm_counter.read() != baseline.nv_counter:
                raise StoreError("boot baseline requires the provisioned NV counter value 1")
            record = self._journal.append_locked(
                "boot.baseline-adopted",
                cast(Payload, baseline.model_dump(mode="json")),
                txn_id=None,
                records=records,
            )
            self._rebuild([record])

    def get(self, txn_id: int) -> TransactionRecord:
        row = self._conn.execute(
            "SELECT id, status, catalog_hash, invocation, prev_state, new_state, decision, acks,"
            " machine_profile_id, rendered_hash, flake_lock_hash, closure_path,"
            " boot_artifact, boot_plan,"
            " boot_outcome, boot_staging_failure, nv_counter, detail"
            " FROM transactions WHERE id = ?",
            (txn_id,),
        ).fetchone()
        if row is None:
            raise StoreError(f"no transaction {txn_id}")
        return TransactionRecord(
            id=row[0],
            status=TxnStatus(row[1]),
            catalog_hash=row[2],
            nv_counter=row[16],
            invocation=CapabilityInvocation.model_validate_json(row[3]),
            prev_state=DesiredState.model_validate_json(row[4]),
            new_state=DesiredState.model_validate_json(row[5]),
            decision=PolicyDecision.model_validate_json(row[6]),
            acks=tuple(json.loads(row[7])),
            machine_profile_id=row[8],
            rendered_hash=row[9],
            flake_lock_hash=row[10],
            closure_path=row[11],
            boot_artifact=(None if row[12] is None else BootArtifact.model_validate_json(row[12])),
            boot_plan=None if row[13] is None else BootPlan.model_validate_json(row[13]),
            boot_outcome=(None if row[14] is None else BootOutcome.model_validate_json(row[14])),
            boot_staging_failure=(
                None if row[15] is None else BootStagingFailure.model_validate_json(row[15])
            ),
            detail=row[17],
        )

    def _catalog_floor_satisfied(self, catalog_hash: str) -> bool:
        blessed = self.blessed()
        if blessed is not None:
            return blessed.catalog_hash == catalog_hash
        baseline = self.boot_baseline()
        return baseline is None or baseline.catalog_hash == catalog_hash

    def anchor_blessed_boot(self, txn_id: int, artifact: BootArtifact) -> None:
        with self._journal.exclusive():
            records = self._journal.read_verified_locked()
            self._replace_projection(records)
            transaction = self.get(txn_id)
            if transaction.status is not TxnStatus.BLESSED or self._pointer("blessed") != txn_id:
                raise TransitionError("boot anchor requires the current blessed transaction")
            if self.in_flight() is not None:
                raise TransitionError("boot anchor is forbidden while a transaction is in flight")
            if transaction.boot_artifact is not None:
                raise TransitionError("blessed boot is already anchored")
            if artifact.closure_path != transaction.closure_path:
                raise TransitionError("boot anchor closure does not match blessed transaction")
            payload: Payload = {
                "status": TxnStatus.BLESSED.value,
                "artifact": cast(JsonValue, artifact.model_dump(mode="json")),
            }
            record = self._journal.append_locked(
                "transaction.boot-anchored",
                payload,
                txn_id=txn_id,
                records=records,
            )
            self._rebuild([*records, record])

    def _validate_boot_transition(
        self,
        transaction: TransactionRecord,
        to_status: TxnStatus,
        *,
        boot_plan: BootPlan | None,
        boot_outcome: BootOutcome | None,
        boot_staging_failure: BootStagingFailure | None,
    ) -> None:
        boot_affecting = REGISTRY[transaction.invocation.capability].boot_affecting
        if to_status is TxnStatus.PENDING:
            if boot_affecting and boot_plan is None:
                raise TransitionError("boot transaction pending requires a boot plan")
            if not boot_affecting and boot_plan is not None:
                raise TransitionError("non-boot transaction cannot carry a boot plan")
            if boot_plan is not None:
                if boot_plan.candidate.closure_path != transaction.closure_path:
                    raise TransitionError("boot plan candidate closure does not match transaction")
                if boot_plan.rendered_hash != transaction.rendered_hash:
                    raise TransitionError("boot plan rendered hash does not match transaction")
                if boot_plan.flake_lock_hash != transaction.flake_lock_hash:
                    raise TransitionError("boot plan flake-lock hash does not match transaction")
                if boot_plan.machine_profile_id != transaction.machine_profile_id:
                    raise TransitionError("boot plan machine profile does not match transaction")
        elif boot_plan is not None:
            raise TransitionError("boot plan is only valid on the pending transition")

        if to_status is TxnStatus.BLESSED and boot_affecting:
            if boot_staging_failure is not None:
                raise TransitionError("boot staging failure cannot bless a transaction")
            plan = transaction.boot_plan
            if plan is None or not _is_healthy_candidate_outcome(boot_outcome, plan):
                raise TransitionError("boot blessing requires a healthy boot outcome")
        elif to_status is TxnStatus.ABORTED and boot_affecting:
            if (boot_outcome is None) == (boot_staging_failure is None):
                raise TransitionError(
                    "boot abort requires exactly one failed, quarantined boot outcome or staging failure"
                )
            if boot_outcome is not None and not _is_failed_quarantined_outcome(boot_outcome):
                raise TransitionError("boot abort requires a failed, quarantined boot outcome")
            if boot_staging_failure is not None and not _valid_staging_failure(
                boot_staging_failure, transaction.boot_plan
            ):
                raise TransitionError(
                    "boot staging failure candidate does not match the authenticated plan"
                )
        elif boot_outcome is not None or boot_staging_failure is not None:
            if not boot_affecting:
                raise TransitionError("non-boot transaction cannot carry boot failure evidence")
            raise TransitionError("boot failure evidence is only valid when aborting")

    def events(self, txn_id: int) -> list[tuple[int, str, str | None]]:
        self._status(txn_id)
        rows = self._conn.execute(
            "SELECT seq, COALESCE(to_status, event), detail"
            " FROM events WHERE txn_id = ? ORDER BY seq",
            (txn_id,),
        ).fetchall()
        return [(row[0], row[1], row[2]) for row in rows]

    def record_event(self, txn_id: int, note: str) -> None:
        with self._journal.exclusive():
            records = self._journal.read_verified_locked()
            self._replace_projection(records)
            current = self._status(txn_id)
            record = self._journal.append_locked(
                "transaction.note",
                {"status": current.value, "detail": note},
                txn_id=txn_id,
                records=records,
            )
            self._rebuild([*records, record])

    def active(self) -> TransactionRecord | None:
        txn_id = self._pointer("active")
        return None if txn_id is None else self.get(txn_id)

    def blessed(self) -> TransactionRecord | None:
        txn_id = self._pointer("blessed")
        return None if txn_id is None else self.get(txn_id)

    def recent(self, n: int) -> list[TransactionRecord]:
        rows = self._conn.execute(
            "SELECT id FROM transactions ORDER BY id DESC LIMIT ?", (n,)
        ).fetchall()
        return [self.get(row[0]) for row in rows]

    def in_flight(self) -> TransactionRecord | None:
        row = self._conn.execute(
            "SELECT id FROM transactions WHERE status NOT IN (?, ?, ?)",
            tuple(TERMINAL_STATUSES),
        ).fetchone()
        return None if row is None else self.get(row[0])

    def blessed_state(self) -> DesiredState:
        blessed = self.blessed()
        if blessed is not None:
            return blessed.new_state
        baseline = self.boot_baseline()
        return DesiredState() if baseline is None else baseline.state

    def blessed_boot_artifact(self) -> BootArtifact | None:
        blessed = self.blessed()
        if blessed is not None:
            return blessed.boot_artifact
        baseline = self.boot_baseline()
        return None if baseline is None else baseline.artifact

    def revert_target(self) -> DesiredState | None:
        blessed = self.blessed()
        return None if blessed is None else blessed.prev_state

    def _status(self, txn_id: int) -> TxnStatus:
        row = self._conn.execute(
            "SELECT status FROM transactions WHERE id = ?", (txn_id,)
        ).fetchone()
        if row is None:
            raise StoreError(f"no transaction {txn_id}")
        return TxnStatus(row[0])

    def _pointer(self, name: str) -> int | None:
        row = self._conn.execute("SELECT txn_id FROM pointers WHERE name = ?", (name,)).fetchone()
        return None if row is None or row[0] is None else row[0]

    def _rebuild(self, records: list[JournalRecord] | None = None) -> None:
        verified = self._journal.read_verified() if records is None else records
        self._replace_projection(verified)

    def _replace_projection(self, records: list[JournalRecord]) -> None:
        if hasattr(self, "_conn"):
            self._conn.close()
        rebuild_projection(self._db_path, records)
        self._conn = sqlite3.connect(self._db_path)
        self._conn.execute("PRAGMA foreign_keys=ON")

    def _reject_legacy_state(self) -> None:
        if not self._db_path.exists():
            return
        try:
            connection = sqlite3.connect(self._db_path)
            table = connection.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='transactions'"
            ).fetchone()
            count = (
                connection.execute("SELECT count(*) FROM transactions").fetchone()[0]
                if table is not None
                else 0
            )
            connection.close()
        except sqlite3.DatabaseError as exc:
            raise StoreError(
                "legacy unauthenticated state requires a fresh Stage 2 state directory"
            ) from exc
        if count:
            raise StoreError(
                "legacy unauthenticated state requires a fresh Stage 2 state directory"
            )
