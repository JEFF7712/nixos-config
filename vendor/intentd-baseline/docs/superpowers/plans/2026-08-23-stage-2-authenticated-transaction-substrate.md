# Stage 2 Authenticated Transaction Substrate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SQLite and `audit.jsonl` authority with one durable, MAC-chained event journal whose SQLite projection can be reconstructed exactly after crashes or corruption.

**Architecture:** `AuthenticatedJournal` serializes canonical JSON records under an exclusive file lock, authenticates the chain with HMAC-SHA256, and advances an authenticated checkpoint only after the journal is durable. `TransactionStore` validates commands against a SQLite projection, appends the authoritative event first, then atomically rebuilds the projection. Production loads a 32-byte key from a systemd credential or an explicit development key file and fails closed when neither is available.

**Tech Stack:** Python 3.12, Pydantic 2, SQLite, standard-library `fcntl`, `hashlib`, `hmac`, `json`, `os`, `secrets`, pytest, Ruff, Pyright, Nix.

---

## File structure

- Create `src/intentd/journal.py`: canonical record types, MAC verification,
  locking, append durability, checkpoint recovery, and key loading.
- Create `src/intentd/projection.py`: authoritative-event validation and atomic
  reconstruction of the SQLite query projection.
- Modify `src/intentd/store.py`: validate transaction commands, append journal
  events, rebuild the projection, and preserve the existing query API.
- Modify `src/intentd/audit.py`: append non-transaction outcomes to the
  authenticated journal instead of `audit.jsonl`.
- Modify `src/intentd/cli.py`: pass the store journal to audit recording.
- Modify `src/intentd/wiring.py`: construct one journal and store from the state
  directory and credential environment.
- Create `tests/helpers.py`: one test-only store factory with an explicit key.
- Create `tests/test_journal.py`: codec, authenticity, checkpoint, truncation,
  concurrency, and key-loading tests.
- Create `tests/test_projection.py`: replay, invariant, and atomic replacement
  tests.
- Modify transaction-store, orchestrator, CLI, picker, and wiring tests to use
  the explicit test store factory.
- Modify `docs/host-setup.md`: document the development key-file contract and
  production systemd credential name.

## Locked data contract

Journal file: `<state-dir>/journal.jsonl`

Lock file: `<state-dir>/journal.lock`

Checkpoint file: `<state-dir>/journal.checkpoint.json`

Credential name: `intentd-journal-key`

Development override: `INTENTD_JOURNAL_KEY_FILE`

Record body, encoded with `json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)`:

```json
{
  "event": "transaction.proposed",
  "format_version": 1,
  "journal_id": "32 lowercase hex characters",
  "key_id": "first 16 hex characters of SHA-256(key)",
  "payload": {},
  "prev_mac": "64 lowercase hex characters",
  "seq": 1,
  "txn_id": 1
}
```

The stored record adds `"mac"`, which is HMAC-SHA256 over the canonical UTF-8
body. A proposal uses its journal sequence as its integer transaction ID.
Subsequent transaction events carry that ID. Audit outcomes carry `null`.

Checkpoint body:

```json
{
  "format_version": 1,
  "journal_id": "32 lowercase hex characters",
  "key_id": "16 lowercase hex characters",
  "mac": "journal record MAC at seq",
  "seq": 1
}
```

The stored checkpoint adds `"auth"`, an HMAC-SHA256 over its canonical body.
The file-backed checkpoint used in VMs detects journal-only rollback. The
physical-certification plan replaces its storage backend with a TPM2 monotonic
checkpoint without changing this interface.

### Task 1: Canonical authenticated records

**Files:**
- Create: `src/intentd/journal.py`
- Create: `tests/test_journal.py`

- [ ] **Step 1: Write failing codec and chain tests**

```python
import json
from pathlib import Path

import pytest

from intentd.journal import AuthenticatedJournal, JournalError


KEY = bytes(range(32))


def test_append_round_trip_is_canonical_and_chained(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="a" * 32)

    first = journal.append_proposal({"new_state": {"apps": ["firefox"]}})
    second = journal.append(
        "transaction.transition",
        {"from_status": "proposed", "to_status": "validated"},
        txn_id=first.txn_id,
    )

    assert first.seq == 1
    assert first.txn_id == 1
    assert second.seq == 2
    assert second.prev_mac == first.mac
    assert journal.read_verified() == [first, second]
    lines = (tmp_path / "journal.jsonl").read_text().splitlines()
    assert lines[0] == json.dumps(
        json.loads(lines[0]), sort_keys=True, separators=(",", ":"), ensure_ascii=True
    )


def test_modified_payload_is_rejected(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="b" * 32)
    journal.append("audit.outcome", {"outcome": "content-abstain"}, txn_id=None)
    path = tmp_path / "journal.jsonl"
    path.write_text(path.read_text().replace("content-abstain", "infra-abstain"))

    with pytest.raises(JournalError, match="invalid MAC at sequence 1"):
        journal.read_verified()
```

- [ ] **Step 2: Run the focused tests and confirm the missing module failure**

Run: `uv run pytest tests/test_journal.py -q`

Expected: collection fails with `ModuleNotFoundError: No module named 'intentd.journal'`.

- [ ] **Step 3: Implement the closed record models and canonical codec**

Create these public types and helpers in `src/intentd/journal.py`:

```python
from __future__ import annotations

import hashlib
import hmac
import json
from pathlib import Path
from typing import TypeAlias, cast

from pydantic import JsonValue

from intentd.schema import ClosedModel

Payload: TypeAlias = dict[str, JsonValue]
ZERO_MAC = "0" * 64


class JournalError(Exception):
    pass


class JournalRecord(ClosedModel):
    format_version: int = 1
    journal_id: str
    key_id: str
    seq: int
    txn_id: int | None
    event: str
    payload: Payload
    prev_mac: str
    mac: str


def _canonical(value: dict[str, JsonValue]) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")


def _body(record: JournalRecord) -> dict[str, JsonValue]:
    raw = cast(dict[str, JsonValue], record.model_dump(mode="json"))
    del raw["mac"]
    return raw


def _key_id(key: bytes) -> str:
    return hashlib.sha256(key).hexdigest()[:16]


def _mac(key: bytes, body: dict[str, JsonValue]) -> str:
    return hmac.new(key, _canonical(body), hashlib.sha256).hexdigest()
```

Implement `AuthenticatedJournal` with constructor
`(state_dir: Path, key: bytes, *, journal_id: str | None = None)`, read-only
property `key_id: str`, `append_proposal(payload: Payload) -> JournalRecord`,
`append(event: str, payload: Payload, *, txn_id: int | None) -> JournalRecord`,
and `read_verified() -> list[JournalRecord]`. The implementation rules in the
next paragraph define every accepted and rejected input.

Reject keys whose length is not 32 bytes. Generate a new journal ID with
`secrets.token_hex(16)` only when both journal and checkpoint are absent. Parse
each complete line with `JournalRecord.model_validate_json`, require format 1,
the configured journal and key IDs, consecutive sequences starting at one,
the expected predecessor MAC, and `hmac.compare_digest` for the record MAC.

- [ ] **Step 4: Run codec tests**

Run: `uv run pytest tests/test_journal.py -q`

Expected: both tests pass.

- [ ] **Step 5: Commit the codec**

```fish
git add src/intentd/journal.py tests/test_journal.py
git commit -m "feat: add authenticated journal codec"
```

### Task 2: Durable append and rollback checkpoint

**Files:**
- Modify: `src/intentd/journal.py`
- Modify: `tests/test_journal.py`

- [ ] **Step 1: Add failure and recovery tests**

```python
def test_torn_tail_after_checkpoint_is_discarded(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="c" * 32)
    first = journal.append("audit.outcome", {"outcome": "one"}, txn_id=None)
    with (tmp_path / "journal.jsonl").open("ab") as stream:
        stream.write(b'{"event":"audit.outcome"')

    assert journal.read_verified() == [first]
    assert (tmp_path / "journal.jsonl").read_bytes().endswith(b"\n")


def test_complete_valid_tail_advances_stale_checkpoint(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="d" * 32)
    first = journal.append("audit.outcome", {"outcome": "one"}, txn_id=None)
    checkpoint = (tmp_path / "journal.checkpoint.json").read_bytes()
    second = journal.append("audit.outcome", {"outcome": "two"}, txn_id=None)
    (tmp_path / "journal.checkpoint.json").write_bytes(checkpoint)

    assert journal.read_verified() == [first, second]
    assert journal.read_checkpoint().seq == second.seq


def test_journal_rollback_behind_checkpoint_is_rejected(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="e" * 32)
    journal.append("audit.outcome", {"outcome": "one"}, txn_id=None)
    first_bytes = (tmp_path / "journal.jsonl").read_bytes()
    journal.append("audit.outcome", {"outcome": "two"}, txn_id=None)
    (tmp_path / "journal.jsonl").write_bytes(first_bytes)

    with pytest.raises(JournalError, match="journal is behind checkpoint"):
        journal.read_verified()


def test_wrong_key_rejects_checkpoint(tmp_path: Path) -> None:
    AuthenticatedJournal(tmp_path, KEY, journal_id="f" * 32).append(
        "audit.outcome", {"outcome": "one"}, txn_id=None
    )

    with pytest.raises(JournalError, match="checkpoint authentication failed"):
        AuthenticatedJournal(tmp_path, b"x" * 32).read_verified()
```

- [ ] **Step 2: Run tests and confirm checkpoint APIs are absent**

Run: `uv run pytest tests/test_journal.py -q`

Expected: failures mention `read_checkpoint` and missing checkpoint behavior.

- [ ] **Step 3: Implement authenticated checkpoints and fsync ordering**

Add this model:

```python
class JournalCheckpoint(ClosedModel):
    format_version: int = 1
    journal_id: str
    key_id: str
    seq: int
    mac: str
    auth: str
```

Use this append order while holding an exclusive `fcntl.flock` on
`journal.lock`:

1. Read and verify the current journal and checkpoint.
2. Open the journal path with
   `os.open(self._journal_path, os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o600)`.
3. Write the complete canonical record plus one newline with an `_write_all`
   loop around `os.write`.
4. Call `os.fsync` on the journal descriptor.
5. Write the checkpoint to `journal.checkpoint.json.tmp` with mode `0o600`.
6. Call `os.fsync` on the temporary checkpoint, `os.replace` it, then `fsync`
   the state-directory descriptor.

`read_verified` must authenticate the checkpoint before trusting its sequence.
It may truncate exactly one non-newline-terminated final fragment only when all
complete records verify and the checkpoint does not refer to the fragment. It
must advance a stale checkpoint over complete valid records. Any invalid
complete record, missing middle sequence, journal shorter than checkpoint, or
checkpoint MAC mismatch raises `JournalError` without modifying files.

- [ ] **Step 4: Add a two-process serialization test**

```python
from concurrent.futures import ProcessPoolExecutor


def _append_many(state_dir: str, start: int) -> None:
    journal = AuthenticatedJournal(Path(state_dir), KEY)
    for value in range(start, start + 20):
        journal.append("audit.outcome", {"value": value}, txn_id=None)


def test_concurrent_writers_preserve_one_chain(tmp_path: Path) -> None:
    AuthenticatedJournal(tmp_path, KEY, journal_id="1" * 32).append(
        "audit.outcome", {"value": -1}, txn_id=None
    )
    with ProcessPoolExecutor(max_workers=2) as pool:
        list(pool.map(_append_many, [str(tmp_path), str(tmp_path)], [0, 100]))

    records = AuthenticatedJournal(tmp_path, KEY).read_verified()
    assert len(records) == 41
    assert [record.seq for record in records] == list(range(1, 42))
```

- [ ] **Step 5: Run journal tests and static checks**

Run: `uv run pytest tests/test_journal.py -q`

Expected: all journal tests pass.

Run: `uv run ruff check src/intentd/journal.py tests/test_journal.py && nix develop -c pyright`

Expected: Ruff and Pyright exit 0.

- [ ] **Step 6: Commit durability and checkpointing**

```fish
git add src/intentd/journal.py tests/test_journal.py
git commit -m "feat: make journal writes crash durable"
```

### Task 3: Rebuildable SQLite projection

**Files:**
- Create: `src/intentd/projection.py`
- Create: `tests/test_projection.py`

- [ ] **Step 1: Write replay and invariant tests**

```python
import sqlite3
from pathlib import Path

import pytest

from intentd.journal import AuthenticatedJournal
from intentd.projection import ProjectionError, rebuild_projection

from tests.helpers import proposal_payload


KEY = bytes(range(32))


def test_projection_rebuilds_transaction_and_pointers(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="2" * 32)
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
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="3" * 32)
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
    journal = AuthenticatedJournal(tmp_path, KEY, journal_id="4" * 32)
    journal.append("audit.outcome", {"outcome": "content-abstain"}, txn_id=None)

    rebuild_projection(tmp_path / "txn.db", journal.read_verified())

    conn = sqlite3.connect(tmp_path / "txn.db")
    assert conn.execute("SELECT count(*) FROM transactions").fetchone() == (0,)
    assert conn.execute("SELECT seq FROM projection_meta").fetchone() == (1,)
```

Create `tests/helpers.py` with `TEST_JOURNAL_KEY = bytes(range(32))` and a
`proposal_payload(app: str) -> dict[str, JsonValue]` that serializes the same
invocation, states, decision, and acknowledgement fields used by
`TransactionStore.propose`.

- [ ] **Step 2: Run projection tests and confirm the module is missing**

Run: `uv run pytest tests/test_projection.py -q`

Expected: collection fails for `intentd.projection`.

- [ ] **Step 3: Implement atomic replay**

Define this schema in `src/intentd/projection.py`:

```sql
CREATE TABLE transactions (
    id INTEGER PRIMARY KEY,
    status TEXT NOT NULL,
    invocation TEXT NOT NULL,
    prev_state TEXT NOT NULL,
    new_state TEXT NOT NULL,
    decision TEXT NOT NULL,
    acks TEXT NOT NULL,
    rendered_hash TEXT,
    flake_lock_hash TEXT,
    closure_path TEXT,
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
```

Expose `ProjectionError(Exception)` and
`rebuild_projection(db_path: Path, records: list[JournalRecord]) -> None` as the
only public projection API.

Build `txn.db.next` in the same directory, set `PRAGMA foreign_keys=ON`, apply
every event inside one SQLite transaction, run `PRAGMA integrity_check`, close
and `fsync` the temporary database, then `os.replace` it over `txn.db` and
`fsync` the directory. Delete `txn.db.next` after a failed build, but never
replace the prior projection.

For `transaction.proposed`, require `txn_id == seq`, no in-flight transaction,
and payload keys `invocation`, `prev_state`, `new_state`, `decision`, and `acks`.
For `transaction.transition`, require the stored status to equal
`from_status`, enforce `LEGAL_TRANSITIONS`, evidence requirements, write-once
pins, active-only blessing, and pointer changes from `store.py`. For
`transaction.note`, require an existing transaction and preserve its status.
For `audit.outcome`, require `txn_id is None` and do not create a transaction
row. Reject every unknown event.

- [ ] **Step 4: Test atomic replacement on invalid replay**

Extend `tests/test_projection.py` to first build a valid database, append an
authenticated illegal transition, assert `ProjectionError`, and assert the
original database bytes and `projection_meta` remain unchanged.

- [ ] **Step 5: Run projection and transaction-model tests**

Run: `uv run pytest tests/test_projection.py tests/test_store.py -q`

Expected: projection tests pass; existing store tests still pass because the
store has not yet been migrated.

- [ ] **Step 6: Commit the projection**

```fish
git add src/intentd/projection.py tests/helpers.py tests/test_projection.py
git commit -m "feat: rebuild transaction projection from journal"
```

### Task 4: Make the journal authoritative in TransactionStore

**Files:**
- Modify: `src/intentd/store.py`
- Modify: `tests/helpers.py`
- Modify: `tests/test_store.py`
- Modify: `tests/test_orchestrator.py`
- Modify: `tests/test_cli.py`
- Modify: `tests/test_picker.py`

- [ ] **Step 1: Add the explicit test store factory**

```python
def make_store(state_dir: Path) -> TransactionStore:
    state_dir.mkdir(parents=True, exist_ok=True)
    journal = AuthenticatedJournal(state_dir, TEST_JOURNAL_KEY)
    return TransactionStore(state_dir / "txn.db", journal)
```

Replace direct test constructions with `make_store(tmp_path)` or
`make_store(tmp_path / "state")`. Reopen tests must create a second store with
the same state directory and key. Keep tests that deliberately construct
`TransactionRecord` unchanged. Delete the old white-box
`test_pending_without_active_pointer_rejected`: rebuilding from the journal
correctly repairs direct SQLite pointer mutation, while
`test_projection_rejects_illegal_authenticated_transition` now covers the
authoritative active-only blessing invariant.

- [ ] **Step 2: Add journal authority tests to `tests/test_store.py`**

```python
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

    def fail_append(_payload: dict[str, object]) -> NoReturn:
        raise JournalError("injected persistence failure")

    monkeypatch.setattr(store.journal, "append_proposal", fail_append)

    with pytest.raises(JournalError, match="persistence failure"):
        store.propose(inv, prev, new, decision=_decision(inv, prev, new))
    assert store.recent(10) == []


def test_journal_leads_projection_after_injected_rebuild_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    store = make_store(tmp_path)
    monkeypatch.setattr(store, "_rebuild", Mock(side_effect=ProjectionError("injected")))

    with pytest.raises(ProjectionError, match="injected"):
        store.propose(
            _install(),
            DesiredState(),
            DesiredState(apps=("firefox",)),
            decision=_decision(_install(), DesiredState(), DesiredState(apps=("firefox",))),
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
```

Import `NoReturn` from `typing`, `Mock` from `unittest.mock`, `JournalError`,
and `ProjectionError`.

- [ ] **Step 3: Run store tests and confirm the constructor mismatch**

Run: `uv run pytest tests/test_store.py -q`

Expected: failures show `TransactionStore` does not accept the journal and has
no `journal` property.

- [ ] **Step 4: Replace mutation authority in `TransactionStore`**

Change the constructor and expose the journal:

```python
class TransactionStore:
    def __init__(self, db_path: Path, journal: AuthenticatedJournal) -> None:
        self._db_path = db_path
        self._journal = journal
        self._conn: sqlite3.Connection
        self._rebuild()

    @property
    def journal(self) -> AuthenticatedJournal:
        return self._journal

    def _rebuild(self) -> None:
        records = self._journal.read_verified()
        if hasattr(self, "_conn"):
            self._conn.close()
        rebuild_projection(self._db_path, records)
        self._conn = sqlite3.connect(self._db_path)
        self._conn.execute("PRAGMA foreign_keys=ON")
```

Before the first rebuild, inspect an existing database when the verified
journal is empty. If it contains a `transactions` table with any row, raise
`StoreError("legacy unauthenticated state requires a fresh Stage 2 state directory")`.
An absent database or one that can be verified to contain no transaction rows
is disposable when the journal is empty. A corrupt database or one whose
transaction content cannot be inspected fails closed with the same legacy-state
error. Never synthesize authenticated history from legacy rows.

`propose`, `transition`, and `record_event` keep their existing precondition
checks, but replace direct SQL mutation with these authoritative appends:

```python
record = self._journal.append_proposal(
    {
        "invocation": invocation.model_dump(mode="json"),
        "prev_state": prev_state.model_dump(mode="json"),
        "new_state": new_state.model_dump(mode="json"),
        "decision": decision.model_dump(mode="json"),
        "acks": sorted(acks),
    }
)
self._rebuild()
assert record.txn_id is not None
return record.txn_id
```

```python
self._journal.append(
    "transaction.transition",
    {
        "from_status": current.value,
        "to_status": to_status.value,
        "rendered_hash": rendered_hash,
        "flake_lock_hash": flake_lock_hash,
        "closure_path": closure_path,
        "detail": detail,
    },
    txn_id=txn_id,
)
self._rebuild()
```

```python
self._journal.append(
    "transaction.note",
    {"status": current.value, "detail": note},
    txn_id=txn_id,
)
self._rebuild()
```

Add `AuthenticatedJournal.exclusive()` and locked append/read variants so each
store command holds one journal lock across projection refresh, validation,
append, and projection rebuild. This prevents two CLI processes from both
passing the single-in-flight check. Public journal methods acquire the same
lock when used outside the store.

- [ ] **Step 5: Remove the obsolete SQLite mutation schema**

Delete `_SCHEMA`, SQLite WAL setup, `_set_pointer`, and every direct INSERT or
UPDATE from `store.py`. Keep query methods, `_status`, and `_pointer`. Change
`events()` to select `seq`, `to_status`, and `detail` from the projection, with
`COALESCE(to_status, event)` only for non-transition transaction notes.

- [ ] **Step 6: Run all store consumers**

Run: `uv run pytest tests/test_store.py tests/test_orchestrator.py tests/test_cli.py tests/test_picker.py -q`

Expected: all selected tests pass.

- [ ] **Step 7: Run concurrency and typing checks**

Add a store-level process test in `tests/test_store.py` where two processes
propose different applications against one state directory. Assert exactly one
returns a transaction ID, the other reports `still in flight`, and the verified
journal contains exactly one `transaction.proposed` event.

Run: `uv run pytest tests/test_store.py -q && uv run ruff check . && nix develop -c pyright`

Expected: tests pass, Ruff exits 0, Pyright reports 0 errors and 0 warnings.

- [ ] **Step 8: Commit journal-first transactions**

```fish
git add src/intentd/journal.py src/intentd/store.py tests/helpers.py tests/test_store.py tests/test_orchestrator.py tests/test_cli.py tests/test_picker.py
git commit -m "feat: make journal transaction authority"
```

### Task 5: Authenticate non-transaction audit outcomes

**Files:**
- Modify: `src/intentd/audit.py`
- Modify: `src/intentd/cli.py`
- Modify: `tests/test_audit.py`
- Modify: `tests/test_cli.py`

- [ ] **Step 1: Replace audit file assertions with journal assertions**

```python
def test_append_outcome_writes_authenticated_event(tmp_path: Path) -> None:
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="5" * 32)
    before = time.time()
    append_outcome(journal, "content-abstain", "out of scope", "install a rocket", raw=False)
    after = time.time()

    record = journal.read_verified()[0]
    assert record.event == "audit.outcome"
    assert before <= float(record.payload["ts"]) <= after
    assert record.payload["outcome"] == "content-abstain"
    assert record.payload["reason"] == "out of scope"
    assert "utterance" not in record.payload
    assert record.payload["utterance_sha256"] == hashlib.sha256(b"install a rocket").hexdigest()
    assert not (tmp_path / "audit.jsonl").exists()
```

Retain equivalent tests for raw utterances, absent utterances, and append order.
Add an injected `JournalError` test and assert it propagates to the caller.

- [ ] **Step 2: Run audit tests and confirm the signature mismatch**

Run: `uv run pytest tests/test_audit.py -q`

Expected: tests fail because `append_outcome` still accepts a state path.

- [ ] **Step 3: Change audit recording to use the journal**

```python
def append_outcome(
    journal: AuthenticatedJournal,
    outcome: str,
    reason: str,
    utterance: str | None,
    raw: bool,
) -> None:
    payload: Payload = {"ts": time.time(), "outcome": outcome, "reason": reason}
    if utterance is not None:
        if raw:
            payload["utterance"] = utterance
        else:
            payload["utterance_sha256"] = hashlib.sha256(utterance.encode()).hexdigest()
    journal.append("audit.outcome", payload, txn_id=None)
```

Delete `_AUDIT_FILE` and direct file I/O. In `cli.py`, replace every
`append_outcome` call whose first argument is `state_dir` with one whose first
argument is `deps.store.journal`. Preserve propagation of
`JournalError`: inability to persist an outcome must be visible and must never
be reported as a successfully recorded decision.

- [ ] **Step 4: Update CLI audit assertions**

Read audit events from `deps.store.journal.read_verified()` and select records
whose event is `audit.outcome`. Keep the existing exit-code and redaction
assertions unchanged.

- [ ] **Step 5: Run audit and CLI tests**

Run: `uv run pytest tests/test_audit.py tests/test_cli.py -q`

Expected: all selected tests pass and no test creates `audit.jsonl`.

- [ ] **Step 6: Commit authenticated audit outcomes**

```fish
git add src/intentd/audit.py src/intentd/cli.py tests/test_audit.py tests/test_cli.py
git commit -m "feat: authenticate audit outcomes"
```

### Task 6: Fail-closed production key loading

**Files:**
- Modify: `src/intentd/journal.py`
- Modify: `src/intentd/wiring.py`
- Modify: `tests/test_journal.py`
- Modify: `tests/test_wiring.py`
- Modify: `docs/host-setup.md`

- [ ] **Step 1: Write key-loading tests**

```python
def test_load_key_prefers_systemd_credential(tmp_path: Path) -> None:
    credentials = tmp_path / "credentials"
    credentials.mkdir()
    (credentials / "intentd-journal-key").write_bytes(KEY)
    fallback = tmp_path / "fallback.key"
    fallback.write_bytes(b"x" * 32)

    assert load_journal_key(
        {"CREDENTIALS_DIRECTORY": str(credentials), "INTENTD_JOURNAL_KEY_FILE": str(fallback)}
    ) == KEY


def test_load_key_accepts_explicit_development_file(tmp_path: Path) -> None:
    key_file = tmp_path / "journal.key"
    key_file.write_bytes(KEY)
    key_file.chmod(0o600)

    assert load_journal_key({"INTENTD_JOURNAL_KEY_FILE": str(key_file)}) == KEY


@pytest.mark.parametrize("mode", [0o644, 0o640])
def test_load_key_rejects_group_or_world_access(tmp_path: Path, mode: int) -> None:
    key_file = tmp_path / "journal.key"
    key_file.write_bytes(KEY)
    key_file.chmod(mode)

    with pytest.raises(JournalError, match="permissions must be 0600"):
        load_journal_key({"INTENTD_JOURNAL_KEY_FILE": str(key_file)})


def test_load_key_fails_when_unconfigured() -> None:
    with pytest.raises(JournalError, match="journal credential is unavailable"):
        load_journal_key({})
```

- [ ] **Step 2: Run the focused tests and confirm loader absence**

Run: `uv run pytest tests/test_journal.py -q`

Expected: collection fails because `load_journal_key` is not defined.

- [ ] **Step 3: Implement exact key-source precedence**

```python
_CREDENTIAL_NAME = "intentd-journal-key"


def load_journal_key(environ: Mapping[str, str] | None = None) -> bytes:
    env = os.environ if environ is None else environ
    credential_dir = env.get("CREDENTIALS_DIRECTORY")
    if credential_dir:
        path = Path(credential_dir) / _CREDENTIAL_NAME
    else:
        configured = env.get("INTENTD_JOURNAL_KEY_FILE")
        if configured is None:
            raise JournalError("journal credential is unavailable")
        path = Path(configured)
        if stat.S_IMODE(path.stat().st_mode) != 0o600:
            raise JournalError("journal key permissions must be 0600")
    key = path.read_bytes()
    if len(key) != 32:
        raise JournalError("journal key must contain exactly 32 bytes")
    return key
```

Systemd credential files do not need the development-file mode check because
systemd provides them from a private credentials directory. Missing files and
permission errors must be wrapped as `JournalError` without including key
bytes.

- [ ] **Step 4: Wire one production journal**

Change `production_deps` to:

```python
key = load_journal_key()
journal = AuthenticatedJournal(state_dir, key)
store = TransactionStore(state_dir / "txn.db", journal)
```

Update wiring tests with a fixture that writes a 32-byte mode-0600 key and sets
`INTENTD_JOURNAL_KEY_FILE` through `monkeypatch`. Add assertions that
`journal.jsonl`, `journal.checkpoint.json`, and `txn.db` exist after the first
record, and that production dependency construction fails before workspace
activation when the credential is missing or malformed.

- [ ] **Step 5: Document the authority boundary**

Add a Stage 2 journal section to `docs/host-setup.md` stating:

```text
intentd requires a 32-byte journal authentication key. Production services
receive it as the systemd credential `intentd-journal-key`; it is not placed in
the model-facing environment or state directory. Local development may set
`INTENTD_JOURNAL_KEY_FILE` to a mode-0600 file containing exactly 32 bytes.
Missing or invalid key material makes intentd read-only and blocks every state
transition.
```

Also state that existing Stage 1 databases are unauthenticated and are not
silently imported. A non-empty `txn.db` without `journal.jsonl` must fail with
`legacy unauthenticated state requires a fresh Stage 2 state directory`.

- [ ] **Step 6: Run wiring and CLI tests**

Run: `uv run pytest tests/test_journal.py tests/test_wiring.py tests/test_cli.py -q`

Expected: all selected tests pass.

- [ ] **Step 7: Commit production key wiring**

```fish
git add src/intentd/journal.py src/intentd/wiring.py tests/test_journal.py tests/test_wiring.py docs/host-setup.md
git commit -m "feat: require journal credential"
```

### Task 7: Close the authenticated-substrate gate

**Files:**
- Modify: `tests/test_projection.py`
- Modify: `tests/test_store.py`
- Modify: `handoff.md`

- [ ] **Step 1: Add the crash-boundary matrix**

Parameterize `test_proposal_crash_boundaries_recover_authoritative_state` over
`("before-journal-write", None)`, `("after-journal-fsync",
TxnStatus.PROPOSED)`, `("after-checkpoint-replace", TxnStatus.PROPOSED)`,
`("before-projection-replace", TxnStatus.PROPOSED)`, and
`("after-projection-replace", TxnStatus.PROPOSED)`. Implement injection hooks as test-only callables accepted by
`AuthenticatedJournal` and `rebuild_projection`, defaulting to no-op. At each
boundary raise a dedicated test exception, reopen with hooks disabled, and
assert exactly the expected state. The `before-journal-write` case must have no
event. Every boundary after journal durability must replay one proposed
transaction. No case may produce two events or a SQLite-only transaction.

- [ ] **Step 2: Add exact reconstruction comparison**

Create three transactions ending blessed, rejected, and aborted, plus two audit
outcomes and a transaction note. Save normalized rows from all four projection
tables, overwrite `txn.db` with invalid bytes, reopen, and assert every row is
identical after reconstruction.

- [ ] **Step 3: Run the complete fast gate**

Run: `uv run pytest -q`

Expected: all default tests pass with only the existing opt-in markers
deselected.

Run: `uv run ruff check . && uv run ruff format --check . && nix develop -c pyright`

Expected: Ruff lint and format pass; Pyright reports 0 errors and 0 warnings.

- [ ] **Step 4: Run the Nix and opt-in regression gate**

Run: `nix develop -c uv run pytest -q -o addopts='' -m nix_eval`

Expected: the opt-in Nix evaluation test passes.

Run: `nix develop -c uv run pytest -q -o addopts='' -m claude_live`

Expected: the live resolver test passes or reports an infrastructure-specific
failure that is recorded as such and resolved before completion.

Run: `git ls-files '*.nix' ':!tests/golden/**' | xargs nixfmt --check`

Expected: production Nix files are formatted.

Run: `nix flake check -L`

Expected: the package and all Stage 1 VM checks pass unchanged.

- [ ] **Step 5: Record milestone evidence**

Update `handoff.md` with the implementation commits, exact test counts, journal
file and credential contracts, remaining boot-reliability scope, and any
verification limitation. Do not claim TPM2 binding, boot-path enforcement, or
power-loss recovery from this milestone.

- [ ] **Step 6: Commit the milestone closeout**

```fish
git add tests/test_projection.py tests/test_store.py handoff.md
git commit -m "test: close authenticated journal milestone"
```

## Milestone boundary

Completion of this plan proves durable authenticated transaction authority,
fail-closed audit persistence, exact SQLite reconstruction, and key-source
isolation. It does not prove boot-counted UKIs, health-gated blessing, recovery
image selection, hard-poweroff recovery, TPM2 checkpoint monotonicity, the
graphics capability, or physical-machine certification. Those receive separate
plans in the order fixed by the approved design.
