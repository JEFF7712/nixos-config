import hashlib
import time

from intentd.journal import AuthenticatedJournal, Payload


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
