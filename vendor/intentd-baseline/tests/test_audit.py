import hashlib
import time
from pathlib import Path
from typing import NoReturn

import pytest

from intentd.audit import append_outcome
from intentd.journal import AuthenticatedJournal, JournalError, Payload
from tests.helpers import TEST_JOURNAL_KEY


def _journal(tmp_path: Path) -> AuthenticatedJournal:
    return AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY, journal_id="5" * 32)


def test_append_outcome_writes_authenticated_event(tmp_path: Path) -> None:
    journal = _journal(tmp_path)
    before = time.time()
    append_outcome(journal, "content-abstain", "out of scope", "install a rocket", raw=False)
    after = time.time()

    record = journal.read_verified()[0]
    assert record.event == "audit.outcome"
    timestamp = record.payload["ts"]
    assert isinstance(timestamp, (int, float))
    assert before <= timestamp <= after
    assert record.payload["outcome"] == "content-abstain"
    assert record.payload["reason"] == "out of scope"
    assert "utterance" not in record.payload
    assert record.payload["utterance_sha256"] == hashlib.sha256(b"install a rocket").hexdigest()
    assert not (tmp_path / "audit.jsonl").exists()


def test_append_outcome_raw_opts_into_plaintext_utterance(tmp_path: Path) -> None:
    journal = _journal(tmp_path)
    append_outcome(journal, "infra-abstain", "model call failed", "install firefox", raw=True)

    payload = journal.read_verified()[0].payload
    assert payload["utterance"] == "install firefox"
    assert "utterance_sha256" not in payload


def test_append_outcome_utterance_none_omits_utterance_fields(tmp_path: Path) -> None:
    journal = _journal(tmp_path)
    append_outcome(journal, "policy-reject", "no blessed txn to revert", None, raw=False)

    payload = journal.read_verified()[0].payload
    assert "utterance" not in payload
    assert "utterance_sha256" not in payload


def test_append_outcome_preserves_order(tmp_path: Path) -> None:
    journal = _journal(tmp_path)
    append_outcome(journal, "content-abstain", "first", "a", raw=False)
    append_outcome(journal, "policy-reject", "second", "b", raw=False)

    records = journal.read_verified()
    assert [record.payload["reason"] for record in records] == ["first", "second"]


def test_append_outcome_propagates_persistence_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    journal = _journal(tmp_path)

    def fail_append(_event: str, _payload: Payload, *, txn_id: int | None) -> NoReturn:
        raise JournalError("injected persistence failure")

    monkeypatch.setattr(journal, "append", fail_append)

    with pytest.raises(JournalError, match="persistence failure"):
        append_outcome(journal, "content-abstain", "out of scope", "test", raw=False)
