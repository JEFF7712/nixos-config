import pydantic
import pytest

from intentd.catalog import digest_catalog, load_catalog
from intentd.policy import PolicyDecision, PolicyVerdict
from intentd.registry import resolve_invocation
from intentd.state import DesiredState
from intentd.txn import LEGAL_TRANSITIONS, TransactionRecord, TxnStatus

_DECISION = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="test")


def test_status_taxonomy_matches_design_doc():
    assert {s.value for s in TxnStatus} == {
        "proposed",
        "validated",
        "built",
        "pending",
        "blessed",
        "rejected",
        "aborted",
    }


def test_legal_transitions_match_design_doc():
    assert LEGAL_TRANSITIONS == {
        TxnStatus.PROPOSED: frozenset({TxnStatus.VALIDATED, TxnStatus.REJECTED}),
        TxnStatus.VALIDATED: frozenset({TxnStatus.BUILT, TxnStatus.REJECTED}),
        TxnStatus.BUILT: frozenset({TxnStatus.PENDING, TxnStatus.REJECTED}),
        TxnStatus.PENDING: frozenset({TxnStatus.BLESSED, TxnStatus.ABORTED}),
        TxnStatus.BLESSED: frozenset(),
        TxnStatus.REJECTED: frozenset(),
        TxnStatus.ABORTED: frozenset(),
    }


def test_record_round_trips_through_json():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    record = TransactionRecord(
        id=1,
        status=TxnStatus.PROPOSED,
        catalog_hash=digest_catalog(load_catalog()),
        invocation=inv,
        prev_state=DesiredState(),
        new_state=DesiredState(apps=("firefox",)),
        decision=_DECISION,
    )
    restored = TransactionRecord.model_validate_json(record.model_dump_json())
    assert restored == record


def test_record_is_closed():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    with pytest.raises(pydantic.ValidationError):
        TransactionRecord(
            id=1,
            status=TxnStatus.PROPOSED,
            catalog_hash=digest_catalog(load_catalog()),
            invocation=inv,
            prev_state=DesiredState(),
            new_state=DesiredState(apps=("firefox",)),
            decision=_DECISION,
            shell_hook="x",  # type: ignore[call-arg]
        )
