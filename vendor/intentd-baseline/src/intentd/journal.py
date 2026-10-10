from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import stat
from collections.abc import Generator, Mapping
from contextlib import contextmanager
from fcntl import LOCK_EX, LOCK_UN, flock
from pathlib import Path
from typing import cast

import pydantic
from pydantic import JsonValue

from intentd.schema import ClosedModel

type Payload = dict[str, JsonValue]
ZERO_MAC = "0" * 64
_CREDENTIAL_NAME = "intentd-journal-key"


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


class JournalCheckpoint(ClosedModel):
    format_version: int = 1
    journal_id: str
    key_id: str
    seq: int
    mac: str
    auth: str


def load_journal_key(environ: Mapping[str, str] | None = None) -> bytes:
    env = os.environ if environ is None else environ
    credential_dir = env.get("CREDENTIALS_DIRECTORY")
    check_mode = credential_dir is None
    if credential_dir is not None:
        path = Path(credential_dir) / _CREDENTIAL_NAME
    else:
        configured = env.get("INTENTD_JOURNAL_KEY_FILE")
        if configured is None:
            raise JournalError("journal credential is unavailable")
        path = Path(configured)
    try:
        if check_mode and stat.S_IMODE(path.stat().st_mode) != 0o600:
            raise JournalError("journal key permissions must be 0600")
        key = path.read_bytes()
    except JournalError:
        raise
    except OSError as exc:
        raise JournalError(f"journal credential is unavailable: {exc}") from exc
    if len(key) != 32:
        raise JournalError("journal key must contain exactly 32 bytes")
    return key


def _canonical(value: dict[str, JsonValue]) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode(
        "utf-8"
    )


def _body(record: JournalRecord) -> dict[str, JsonValue]:
    raw = cast(dict[str, JsonValue], record.model_dump(mode="json"))
    del raw["mac"]
    return raw


def _key_id(key: bytes) -> str:
    return hashlib.sha256(key).hexdigest()[:16]


def _mac(key: bytes, body: dict[str, JsonValue]) -> str:
    return hmac.new(key, _canonical(body), hashlib.sha256).hexdigest()


def _checkpoint_body(checkpoint: JournalCheckpoint) -> dict[str, JsonValue]:
    raw = cast(dict[str, JsonValue], checkpoint.model_dump(mode="json"))
    del raw["auth"]
    return raw


def _write_all(fd: int, data: bytes) -> None:
    offset = 0
    while offset < len(data):
        written = os.write(fd, data[offset:])
        if written == 0:
            raise JournalError("journal write returned zero bytes")
        offset += written


class AuthenticatedJournal:
    def __init__(self, state_dir: Path, key: bytes, *, journal_id: str | None = None) -> None:
        if len(key) != 32:
            raise JournalError("journal key must contain exactly 32 bytes")
        if journal_id is not None and (
            len(journal_id) != 32 or any(char not in "0123456789abcdef" for char in journal_id)
        ):
            raise JournalError(
                "journal ID must contain exactly 32 lowercase hexadecimal characters"
            )
        self._state_dir = state_dir
        self._path = state_dir / "journal.jsonl"
        self._checkpoint_path = state_dir / "journal.checkpoint.json"
        self._checkpoint_tmp_path = state_dir / "journal.checkpoint.json.tmp"
        self._lock_path = state_dir / "journal.lock"
        self._key = key
        self._key_id = _key_id(key)
        self._journal_id = journal_id

    @property
    def key_id(self) -> str:
        return self._key_id

    def append_proposal(self, payload: Payload) -> JournalRecord:
        with self.exclusive():
            records = self._read_verified_locked()
            return self._append_locked(payload, "transaction.proposed", len(records) + 1, records)

    def append(self, event: str, payload: Payload, *, txn_id: int | None) -> JournalRecord:
        with self.exclusive():
            records = self._read_verified_locked()
            return self._append_locked(payload, event, txn_id, records)

    def read_verified(self) -> list[JournalRecord]:
        with self.exclusive():
            return self._read_verified_locked()

    def read_checkpoint(self) -> JournalCheckpoint:
        with self.exclusive():
            checkpoint = self._read_checkpoint_locked()
            if checkpoint is None:
                raise JournalError("journal checkpoint is unavailable")
            return checkpoint

    def read_verified_locked(self) -> list[JournalRecord]:
        return self._read_verified_locked()

    def append_proposal_locked(
        self, payload: Payload, records: list[JournalRecord]
    ) -> JournalRecord:
        return self._append_locked(payload, "transaction.proposed", len(records) + 1, records)

    def append_locked(
        self,
        event: str,
        payload: Payload,
        *,
        txn_id: int | None,
        records: list[JournalRecord],
    ) -> JournalRecord:
        return self._append_locked(payload, event, txn_id, records)

    @contextmanager
    def exclusive(self) -> Generator[None]:
        self._state_dir.mkdir(parents=True, exist_ok=True)
        lock_fd = os.open(self._lock_path, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            flock(lock_fd, LOCK_EX)
            yield
        finally:
            flock(lock_fd, LOCK_UN)
            os.close(lock_fd)

    def _read_verified_locked(self) -> list[JournalRecord]:
        checkpoint = self._read_checkpoint_locked()
        if not self._path.exists():
            if checkpoint is not None:
                raise JournalError("journal is behind checkpoint")
            return []
        raw = self._path.read_bytes()
        complete_raw, fragment = self._split_complete_lines(raw)
        records: list[JournalRecord] = []
        expected_prev = ZERO_MAC
        expected_journal_id = self._journal_id
        for expected_seq, raw_line in enumerate(complete_raw, start=1):
            try:
                record = JournalRecord.model_validate_json(raw_line)
            except pydantic.ValidationError as exc:
                raise JournalError(f"invalid record at sequence {expected_seq}: {exc}") from exc
            if expected_journal_id is None:
                expected_journal_id = record.journal_id
            if record.format_version != 1:
                raise JournalError(f"unsupported format at sequence {expected_seq}")
            if record.journal_id != expected_journal_id:
                raise JournalError(f"journal ID mismatch at sequence {expected_seq}")
            if record.key_id != self._key_id:
                raise JournalError(f"key ID mismatch at sequence {expected_seq}")
            if record.seq != expected_seq:
                raise JournalError(f"sequence mismatch at sequence {expected_seq}")
            if record.prev_mac != expected_prev:
                raise JournalError(f"predecessor mismatch at sequence {expected_seq}")
            expected_mac = _mac(self._key, _body(record))
            if not hmac.compare_digest(record.mac, expected_mac):
                raise JournalError(f"invalid MAC at sequence {expected_seq}")
            records.append(record)
            expected_prev = record.mac
        self._journal_id = expected_journal_id
        if checkpoint is not None:
            if checkpoint.seq > len(records):
                raise JournalError("journal is behind checkpoint")
            checkpoint_record = records[checkpoint.seq - 1]
            if checkpoint.mac != checkpoint_record.mac:
                raise JournalError("checkpoint does not match journal")
        if fragment:
            self._truncate_locked(sum(len(line) + 1 for line in complete_raw))
        if records and (checkpoint is None or checkpoint.seq < records[-1].seq):
            self._write_checkpoint_locked(records[-1])
        return records

    @staticmethod
    def _split_complete_lines(raw: bytes) -> tuple[list[bytes], bytes]:
        parts = raw.split(b"\n")
        if raw.endswith(b"\n"):
            return parts[:-1], b""
        return parts[:-1], parts[-1]

    def _read_checkpoint_locked(self) -> JournalCheckpoint | None:
        if not self._checkpoint_path.exists():
            return None
        try:
            checkpoint = JournalCheckpoint.model_validate_json(self._checkpoint_path.read_bytes())
        except pydantic.ValidationError as exc:
            raise JournalError(f"invalid journal checkpoint: {exc}") from exc
        expected_auth = _mac(self._key, _checkpoint_body(checkpoint))
        if not hmac.compare_digest(checkpoint.auth, expected_auth):
            raise JournalError("checkpoint authentication failed")
        if checkpoint.format_version != 1:
            raise JournalError("unsupported checkpoint format")
        if checkpoint.key_id != self._key_id:
            raise JournalError("checkpoint key ID mismatch")
        if self._journal_id is not None and checkpoint.journal_id != self._journal_id:
            raise JournalError("checkpoint journal ID mismatch")
        self._journal_id = checkpoint.journal_id
        return checkpoint

    def _append_locked(
        self, payload: Payload, event: str, txn_id: int | None, records: list[JournalRecord]
    ) -> JournalRecord:
        if self._journal_id is None:
            self._journal_id = secrets.token_hex(16)
        seq = len(records) + 1
        body: dict[str, JsonValue] = {
            "format_version": 1,
            "journal_id": self._journal_id,
            "key_id": self._key_id,
            "seq": seq,
            "txn_id": txn_id,
            "event": event,
            "payload": payload,
            "prev_mac": records[-1].mac if records else ZERO_MAC,
        }
        record = JournalRecord.model_validate({**body, "mac": _mac(self._key, body)})
        encoded = _canonical(cast(dict[str, JsonValue], record.model_dump(mode="json"))) + b"\n"
        fd = os.open(self._path, os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o600)
        try:
            _write_all(fd, encoded)
            os.fsync(fd)
        finally:
            os.close(fd)
        self._write_checkpoint_locked(record)
        return record

    def _write_checkpoint_locked(self, record: JournalRecord) -> None:
        body: dict[str, JsonValue] = {
            "format_version": 1,
            "journal_id": record.journal_id,
            "key_id": record.key_id,
            "seq": record.seq,
            "mac": record.mac,
        }
        checkpoint = JournalCheckpoint.model_validate({**body, "auth": _mac(self._key, body)})
        encoded = _canonical(cast(dict[str, JsonValue], checkpoint.model_dump(mode="json")))
        fd = os.open(self._checkpoint_tmp_path, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
        try:
            os.fchmod(fd, 0o600)
            _write_all(fd, encoded)
            os.fsync(fd)
        finally:
            os.close(fd)
        os.replace(self._checkpoint_tmp_path, self._checkpoint_path)
        self._fsync_state_dir()

    def _truncate_locked(self, size: int) -> None:
        fd = os.open(self._path, os.O_WRONLY)
        try:
            os.ftruncate(fd, size)
            os.fsync(fd)
        finally:
            os.close(fd)
        self._fsync_state_dir()

    def _fsync_state_dir(self) -> None:
        fd = os.open(self._state_dir, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
