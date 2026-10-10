import json
from pathlib import Path

import pytest

import intentd.journal_inspect as journal_inspect
from intentd.journal import AuthenticatedJournal
from tests.helpers import TEST_JOURNAL_KEY


def test_inspector_prints_only_verified_records(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    key_path = tmp_path / "journal.key"
    key_path.write_bytes(TEST_JOURNAL_KEY)
    key_path.chmod(0o600)
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY)
    journal.append("audit.outcome", {"outcome": "healthy"}, txn_id=None)
    monkeypatch.setenv("INTENTD_JOURNAL_KEY_FILE", str(key_path))
    monkeypatch.setenv("INTENTD_STATE_DIR", str(tmp_path))
    monkeypatch.setattr(journal_inspect.sys, "argv", ["intentd-journal-inspect"])

    assert journal_inspect.main() == 0

    output = capsys.readouterr().out.splitlines()
    assert len(output) == 1
    assert json.loads(output[0])["payload"] == {"outcome": "healthy"}


def test_inspector_fails_closed_on_tampered_journal(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    key_path = tmp_path / "journal.key"
    key_path.write_bytes(TEST_JOURNAL_KEY)
    key_path.chmod(0o600)
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY)
    journal.append("audit.outcome", {"outcome": "healthy"}, txn_id=None)
    path = tmp_path / "journal.jsonl"
    path.write_text(path.read_text().replace("healthy", "tampered"))
    monkeypatch.setenv("INTENTD_JOURNAL_KEY_FILE", str(key_path))
    monkeypatch.setenv("INTENTD_STATE_DIR", str(tmp_path))
    monkeypatch.setattr(journal_inspect.sys, "argv", ["intentd-journal-inspect"])

    assert journal_inspect.main() == 1
    assert capsys.readouterr().out == ""


def test_inspector_rejects_arguments(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(journal_inspect.sys, "argv", ["intentd-journal-inspect", "command"])

    assert journal_inspect.main() == 2
