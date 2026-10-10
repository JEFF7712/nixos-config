import json
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import pytest

from intentd.journal import AuthenticatedJournal, JournalError, load_journal_key

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


@pytest.mark.parametrize("journal_id", ["short", "Z" * 32, "g" * 32])
def test_invalid_journal_id_is_rejected(tmp_path: Path, journal_id: str) -> None:
    with pytest.raises(JournalError, match="lowercase hexadecimal"):
        AuthenticatedJournal(tmp_path, KEY, journal_id=journal_id)


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


def test_load_key_prefers_systemd_credential(tmp_path: Path) -> None:
    credentials = tmp_path / "credentials"
    credentials.mkdir()
    (credentials / "intentd-journal-key").write_bytes(KEY)
    fallback = tmp_path / "fallback.key"
    fallback.write_bytes(b"x" * 32)

    assert (
        load_journal_key(
            {
                "CREDENTIALS_DIRECTORY": str(credentials),
                "INTENTD_JOURNAL_KEY_FILE": str(fallback),
            }
        )
        == KEY
    )


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
