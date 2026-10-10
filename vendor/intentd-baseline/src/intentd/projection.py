import json
import os
import sqlite3
from pathlib import Path

import pydantic
from pydantic import Field

from intentd.boot import (
    SHA256_PATTERN,
    BootArtifact,
    BootBaseline,
    BootOutcome,
    BootPlan,
    BootStagingFailure,
    entry_path_matches,
)
from intentd.journal import JournalRecord
from intentd.policy import PolicyDecision, PolicyVerdict
from intentd.registry import REGISTRY, CapabilityInvocation
from intentd.schema import ClosedModel
from intentd.state import DesiredState
from intentd.txn import LEGAL_TRANSITIONS, TERMINAL_STATUSES, TxnStatus


class ProjectionError(Exception):
    pass


class _ProposalEvent(ClosedModel):
    catalog_hash: str = Field(pattern=SHA256_PATTERN)
    invocation: CapabilityInvocation
    prev_state: DesiredState
    new_state: DesiredState
    decision: PolicyDecision
    acks: tuple[str, ...]
    machine_profile_id: str | None = None


class _TransitionEvent(ClosedModel):
    from_status: TxnStatus
    to_status: TxnStatus
    rendered_hash: str | None = None
    flake_lock_hash: str | None = None
    closure_path: str | None = None
    boot_plan: BootPlan | None = None
    boot_outcome: BootOutcome | None = None
    boot_staging_failure: BootStagingFailure | None = None
    nv_counter: int | None = None
    detail: str | None = None


class _BootAnchorEvent(ClosedModel):
    status: TxnStatus
    artifact: BootArtifact


class _NoteEvent(ClosedModel):
    status: TxnStatus
    detail: str


_SCHEMA = """
CREATE TABLE transactions (
    id INTEGER PRIMARY KEY,
    status TEXT NOT NULL,
    catalog_hash TEXT NOT NULL,
    invocation TEXT NOT NULL,
    prev_state TEXT NOT NULL,
    new_state TEXT NOT NULL,
    decision TEXT NOT NULL,
    acks TEXT NOT NULL,
    machine_profile_id TEXT,
    rendered_hash TEXT,
    flake_lock_hash TEXT,
    closure_path TEXT,
    boot_artifact TEXT,
    boot_plan TEXT,
    boot_outcome TEXT,
    boot_staging_failure TEXT,
    nv_counter INTEGER,
    detail TEXT
);
CREATE TABLE events (
    seq INTEGER PRIMARY KEY,
    txn_id INTEGER REFERENCES transactions(id),
    event TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    detail TEXT,
    mac TEXT NOT NULL
);
CREATE TABLE boot_baseline (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    evidence TEXT NOT NULL
);
CREATE TABLE pointers (
    name TEXT PRIMARY KEY CHECK (name IN ('active', 'blessed')),
    txn_id INTEGER REFERENCES transactions(id)
);
CREATE TABLE projection_meta (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    journal_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    mac TEXT NOT NULL
);
"""


def rebuild_projection(db_path: Path, records: list[JournalRecord]) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = db_path.with_name(f"{db_path.name}.next")
    if temporary.exists():
        temporary.unlink()
    connection = sqlite3.connect(temporary)
    try:
        connection.execute("PRAGMA foreign_keys=ON")
        with connection:
            connection.executescript(_SCHEMA)
            for record in records:
                _apply_record(connection, record)
            if records:
                final = records[-1]
                connection.execute(
                    "INSERT INTO projection_meta (singleton, journal_id, seq, mac)"
                    " VALUES (1, ?, ?, ?)",
                    (final.journal_id, final.seq, final.mac),
                )
        result = connection.execute("PRAGMA integrity_check").fetchone()
        if result != ("ok",):
            raise ProjectionError(f"SQLite integrity check failed: {result}")
    except Exception:
        connection.close()
        if temporary.exists():
            temporary.unlink()
        raise
    connection.close()
    fd = os.open(temporary, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    os.replace(temporary, db_path)
    _fsync_directory(db_path.parent)


def _require_catalog_floor(connection: sqlite3.Connection, catalog_hash: str) -> None:
    blessed_id = _pointer(connection, "blessed")
    if blessed_id is None:
        row = connection.execute("SELECT evidence FROM boot_baseline").fetchone()
        if (
            row is not None
            and BootBaseline.model_validate_json(row[0]).catalog_hash != catalog_hash
        ):
            raise ProjectionError("stale catalog: catalog hash does not match the boot baseline")
        return
    row = connection.execute(
        "SELECT catalog_hash FROM transactions WHERE id = ?", (blessed_id,)
    ).fetchone()
    if row is None or row[0] != catalog_hash:
        raise ProjectionError("stale catalog: catalog hash does not match the blessed transaction")


def _apply_record(connection: sqlite3.Connection, record: JournalRecord) -> None:
    if record.event == "boot.baseline-adopted":
        if record.seq != 1 or record.txn_id is not None:
            raise ProjectionError("boot baseline must be the first event without a transaction ID")
        try:
            baseline = BootBaseline.model_validate(record.payload)
        except pydantic.ValidationError as exc:
            raise ProjectionError(f"invalid boot baseline payload: {exc}") from exc
        connection.execute(
            "INSERT INTO boot_baseline (singleton, evidence) VALUES (1, ?)",
            (baseline.model_dump_json(),),
        )
        _insert_event(connection, record, None, None, None)
    elif record.event == "transaction.proposed":
        _apply_proposal(connection, record)
    elif record.event == "transaction.transition":
        _apply_transition(connection, record)
    elif record.event == "transaction.note":
        _apply_note(connection, record)
    elif record.event == "transaction.boot-anchored":
        _apply_boot_anchor(connection, record)
    elif record.event == "audit.outcome":
        if record.txn_id is not None:
            raise ProjectionError("audit outcome cannot reference a transaction")
        _insert_event(connection, record, None, None, None)
    else:
        raise ProjectionError(f"unknown journal event {record.event}")


def _apply_proposal(connection: sqlite3.Connection, record: JournalRecord) -> None:
    if record.txn_id != record.seq:
        raise ProjectionError("proposal transaction ID must equal its journal sequence")
    row = connection.execute(
        "SELECT id FROM transactions WHERE status NOT IN (?, ?, ?)",
        tuple(TERMINAL_STATUSES),
    ).fetchone()
    if row is not None:
        raise ProjectionError(f"transaction {row[0]} is still in flight")
    try:
        event = _ProposalEvent.model_validate(record.payload)
    except pydantic.ValidationError as exc:
        raise ProjectionError(f"invalid proposal payload: {exc}") from exc
    if event.decision.verdict is PolicyVerdict.REJECT:
        raise ProjectionError("rejected decision cannot create a proposal")
    missing = sorted(set(event.decision.required_acks) - set(event.acks))
    if missing:
        raise ProjectionError(f"proposal has unacknowledged requirements: {missing}")
    boot_affecting = REGISTRY[event.invocation.capability].boot_affecting
    if boot_affecting and not event.machine_profile_id:
        raise ProjectionError("boot transaction requires an authenticated machine profile")
    if not boot_affecting and event.machine_profile_id is not None:
        raise ProjectionError("non-boot transaction cannot carry a machine profile")
    _require_catalog_floor(connection, event.catalog_hash)
    connection.execute(
        "INSERT INTO transactions"
        " (id, status, catalog_hash, invocation, prev_state, new_state,"
        " decision, acks, machine_profile_id)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            record.txn_id,
            TxnStatus.PROPOSED,
            event.catalog_hash,
            event.invocation.model_dump_json(),
            event.prev_state.model_dump_json(),
            event.new_state.model_dump_json(),
            event.decision.model_dump_json(),
            json.dumps(list(event.acks)),
            event.machine_profile_id,
        ),
    )
    _insert_event(connection, record, None, TxnStatus.PROPOSED, None)


def _apply_transition(connection: sqlite3.Connection, record: JournalRecord) -> None:
    if record.txn_id is None:
        raise ProjectionError("transaction transition requires a transaction ID")
    try:
        event = _TransitionEvent.model_validate(record.payload)
    except pydantic.ValidationError as exc:
        raise ProjectionError(f"invalid transition payload: {exc}") from exc
    row = connection.execute(
        "SELECT status, invocation, machine_profile_id, rendered_hash, flake_lock_hash, closure_path,"
        " boot_artifact, boot_plan, boot_outcome, boot_staging_failure"
        " FROM transactions WHERE id = ?",
        (record.txn_id,),
    ).fetchone()
    if row is None:
        raise ProjectionError(f"no transaction {record.txn_id}")
    current = TxnStatus(row[0])
    if current is not event.from_status:
        raise ProjectionError(
            f"transition source mismatch: recorded {event.from_status}, projected {current}"
        )
    if event.to_status not in LEGAL_TRANSITIONS[current]:
        raise ProjectionError(f"illegal transition {current} -> {event.to_status}")
    if event.to_status is TxnStatus.VALIDATED and not event.rendered_hash:
        raise ProjectionError("validated requires rendered_hash")
    if event.to_status is TxnStatus.BUILT and (not event.closure_path or not event.flake_lock_hash):
        raise ProjectionError("built requires closure_path and flake_lock_hash")
    if event.to_status is TxnStatus.BLESSED and _pointer(connection, "active") != record.txn_id:
        raise ProjectionError("only the active transaction can be blessed")
    invocation = CapabilityInvocation.model_validate_json(row[1])
    boot_affecting = REGISTRY[invocation.capability].boot_affecting
    stored_plan = None if row[7] is None else BootPlan.model_validate_json(row[7])
    _validate_boot_transition(
        boot_affecting=boot_affecting,
        to_status=event.to_status,
        event=event,
        machine_profile_id=row[2],
        rendered_hash=row[3],
        flake_lock_hash=row[4],
        closure_path=row[5],
        stored_plan=stored_plan,
    )
    for name, incoming, stored in (
        ("rendered_hash", event.rendered_hash, row[3]),
        ("flake_lock_hash", event.flake_lock_hash, row[4]),
        ("closure_path", event.closure_path, row[5]),
    ):
        if incoming is not None and stored is not None:
            raise ProjectionError(f"{name} is already pinned")
    blessed_artifact = (
        stored_plan.candidate.model_dump_json()
        if event.to_status is TxnStatus.BLESSED and stored_plan is not None
        else None
    )
    connection.execute(
        "UPDATE transactions SET status = ?,"
        " rendered_hash = COALESCE(?, rendered_hash),"
        " flake_lock_hash = COALESCE(?, flake_lock_hash),"
        " closure_path = COALESCE(?, closure_path),"
        " boot_plan = COALESCE(?, boot_plan),"
        " boot_outcome = COALESCE(?, boot_outcome),"
        " boot_staging_failure = COALESCE(?, boot_staging_failure),"
        " boot_artifact = COALESCE(?, boot_artifact),"
        " nv_counter = COALESCE(?, nv_counter),"
        " detail = COALESCE(?, detail) WHERE id = ?",
        (
            event.to_status,
            event.rendered_hash,
            event.flake_lock_hash,
            event.closure_path,
            None if event.boot_plan is None else event.boot_plan.model_dump_json(),
            None if event.boot_outcome is None else event.boot_outcome.model_dump_json(),
            (
                None
                if event.boot_staging_failure is None
                else event.boot_staging_failure.model_dump_json()
            ),
            blessed_artifact,
            event.nv_counter,
            event.detail,
            record.txn_id,
        ),
    )
    if event.to_status is TxnStatus.PENDING:
        _set_pointer(connection, "active", record.txn_id)
    elif event.to_status is TxnStatus.BLESSED:
        _set_pointer(connection, "blessed", record.txn_id)
    elif event.to_status is TxnStatus.ABORTED:
        _set_pointer(connection, "active", _pointer(connection, "blessed"))
    _insert_event(connection, record, current, event.to_status, event.detail)


def _validate_boot_transition(
    *,
    boot_affecting: bool,
    to_status: TxnStatus,
    event: _TransitionEvent,
    machine_profile_id: str | None,
    rendered_hash: str | None,
    flake_lock_hash: str | None,
    closure_path: str | None,
    stored_plan: BootPlan | None,
) -> None:
    if to_status is TxnStatus.PENDING:
        if boot_affecting and event.boot_plan is None:
            raise ProjectionError("boot transaction pending requires a boot plan")
        if not boot_affecting and event.boot_plan is not None:
            raise ProjectionError("non-boot transaction cannot carry a boot plan")
        if event.boot_plan is not None:
            plan = event.boot_plan
            if plan.candidate.closure_path != closure_path:
                raise ProjectionError("boot plan candidate closure does not match transaction")
            if plan.rendered_hash != rendered_hash:
                raise ProjectionError("boot plan rendered hash does not match transaction")
            if plan.flake_lock_hash != flake_lock_hash:
                raise ProjectionError("boot plan flake-lock hash does not match transaction")
            if plan.machine_profile_id != machine_profile_id:
                raise ProjectionError("boot plan machine profile does not match transaction")
    elif event.boot_plan is not None:
        raise ProjectionError("boot plan is only valid on the pending transition")

    if to_status is TxnStatus.BLESSED and boot_affecting:
        if event.boot_staging_failure is not None:
            raise ProjectionError("boot staging failure cannot bless a transaction")
        if stored_plan is None:
            raise ProjectionError("boot transaction has no authenticated boot plan")
        if not _is_healthy_candidate_outcome(event.boot_outcome, stored_plan):
            raise ProjectionError("boot blessing requires a healthy boot outcome")
    elif to_status is TxnStatus.ABORTED and boot_affecting:
        if (event.boot_outcome is None) == (event.boot_staging_failure is None):
            raise ProjectionError(
                "boot abort requires exactly one failed, quarantined boot outcome or staging failure"
            )
        if event.boot_outcome is not None and not _is_failed_quarantined_outcome(
            event.boot_outcome
        ):
            raise ProjectionError("boot abort requires a failed, quarantined boot outcome")
        if event.boot_staging_failure is not None and not _valid_staging_failure(
            event.boot_staging_failure, stored_plan
        ):
            raise ProjectionError(
                "boot staging failure candidate does not match the authenticated plan"
            )
    elif event.boot_outcome is not None or event.boot_staging_failure is not None:
        if not boot_affecting:
            raise ProjectionError("non-boot transaction cannot carry boot failure evidence")
        raise ProjectionError("boot failure evidence is only valid when aborting")


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


def _apply_boot_anchor(connection: sqlite3.Connection, record: JournalRecord) -> None:
    if record.txn_id is None:
        raise ProjectionError("boot anchor requires a transaction ID")
    try:
        event = _BootAnchorEvent.model_validate(record.payload)
    except pydantic.ValidationError as exc:
        raise ProjectionError(f"invalid boot anchor payload: {exc}") from exc
    row = connection.execute(
        "SELECT status, closure_path, boot_artifact FROM transactions WHERE id = ?",
        (record.txn_id,),
    ).fetchone()
    if row is None:
        raise ProjectionError(f"no transaction {record.txn_id}")
    current = TxnStatus(row[0])
    if event.status is not TxnStatus.BLESSED or current is not TxnStatus.BLESSED:
        raise ProjectionError("boot anchor requires a blessed transaction")
    if _pointer(connection, "blessed") != record.txn_id:
        raise ProjectionError("boot anchor requires the current blessed transaction")
    in_flight = connection.execute(
        "SELECT id FROM transactions WHERE status NOT IN (?, ?, ?)",
        tuple(TERMINAL_STATUSES),
    ).fetchone()
    if in_flight is not None:
        raise ProjectionError("boot anchor is forbidden while a transaction is in flight")
    if row[2] is not None:
        raise ProjectionError("blessed boot is already anchored")
    if event.artifact.closure_path != row[1]:
        raise ProjectionError("boot anchor closure does not match blessed transaction")
    connection.execute(
        "UPDATE transactions SET boot_artifact = ? WHERE id = ?",
        (event.artifact.model_dump_json(), record.txn_id),
    )
    _insert_event(connection, record, current, current, None)


def _apply_note(connection: sqlite3.Connection, record: JournalRecord) -> None:
    if record.txn_id is None:
        raise ProjectionError("transaction note requires a transaction ID")
    try:
        event = _NoteEvent.model_validate(record.payload)
    except pydantic.ValidationError as exc:
        raise ProjectionError(f"invalid transaction note: {exc}") from exc
    row = connection.execute(
        "SELECT status FROM transactions WHERE id = ?", (record.txn_id,)
    ).fetchone()
    if row is None:
        raise ProjectionError(f"no transaction {record.txn_id}")
    current = TxnStatus(row[0])
    if event.status is not current:
        raise ProjectionError(
            f"transaction note status mismatch: recorded {event.status}, projected {current}"
        )
    _insert_event(connection, record, current, current, event.detail)


def _insert_event(
    connection: sqlite3.Connection,
    record: JournalRecord,
    from_status: TxnStatus | None,
    to_status: TxnStatus | None,
    detail: str | None,
) -> None:
    connection.execute(
        "INSERT INTO events (seq, txn_id, event, from_status, to_status, detail, mac)"
        " VALUES (?, ?, ?, ?, ?, ?, ?)",
        (record.seq, record.txn_id, record.event, from_status, to_status, detail, record.mac),
    )


def _pointer(connection: sqlite3.Connection, name: str) -> int | None:
    row = connection.execute("SELECT txn_id FROM pointers WHERE name = ?", (name,)).fetchone()
    return None if row is None or row[0] is None else int(row[0])


def _set_pointer(connection: sqlite3.Connection, name: str, txn_id: int | None) -> None:
    connection.execute(
        "INSERT INTO pointers (name, txn_id) VALUES (?, ?)"
        " ON CONFLICT(name) DO UPDATE SET txn_id = excluded.txn_id",
        (name, txn_id),
    )


def _fsync_directory(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
