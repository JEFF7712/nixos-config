import os
import sys
from pathlib import Path

from intentd.journal import AuthenticatedJournal, JournalError, load_journal_key

_STATE_DIR = Path("/var/lib/intentd")


def main() -> int:
    if sys.argv[1:]:
        return 2
    state_dir = Path(os.environ.get("INTENTD_STATE_DIR", _STATE_DIR))
    try:
        records = AuthenticatedJournal(state_dir, load_journal_key()).read_verified()
    except (JournalError, OSError):
        return 1
    for record in records:
        print(record.model_dump_json())
    return 0
