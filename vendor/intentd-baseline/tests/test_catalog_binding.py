from pathlib import Path

import pytest

from intentd.catalog import digest_catalog, load_catalog
from intentd.journal import AuthenticatedJournal
from intentd.policy import evaluate
from intentd.projection import ProjectionError
from intentd.registry import resolve_invocation
from intentd.schema import CatalogApp
from intentd.state import DesiredState, apply_invocation
from intentd.store import StoreError, TransactionStore
from intentd.txn import TxnStatus
from tests.helpers import TEST_JOURNAL_KEY, blessed_app_transaction, make_store

_STALE_SUMMARY = "Web browser with a stale catalog entry"


def _mutated_catalog() -> dict[str, CatalogApp]:
    catalog = dict(load_catalog())
    firefox = catalog["firefox"]
    catalog["firefox"] = firefox.model_copy(update={"summary": _STALE_SUMMARY})
    return catalog


def _drive_to_blessed(store: TransactionStore, catalog_hash: str) -> int:
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "vlc"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=None)
    txn = store.propose(invocation, previous, desired, decision=decision, catalog_hash=catalog_hash)
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/vlc", flake_lock_hash="l" * 64)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)
    return txn


def test_digest_is_deterministic_and_order_independent() -> None:
    catalog = load_catalog()
    assert digest_catalog(catalog) == digest_catalog(dict(reversed(list(catalog.items()))))
    assert digest_catalog({}) == digest_catalog({})
    assert digest_catalog({}) != digest_catalog(catalog)


def test_first_blessed_establishes_floor_and_same_catalog_proceeds(tmp_path: Path) -> None:
    store, blessed = blessed_app_transaction(tmp_path)
    record = store.get(blessed)
    assert record.catalog_hash == digest_catalog(load_catalog())
    followup = _drive_to_blessed(store, digest_catalog(load_catalog()))
    assert store.get(followup).status is TxnStatus.BLESSED


def test_stale_catalog_rejected_before_pending(tmp_path: Path) -> None:
    store, _blessed = blessed_app_transaction(tmp_path)
    stale = _mutated_catalog()
    assert digest_catalog(stale) != digest_catalog(load_catalog())
    invocation = resolve_invocation(stale, "app.install", {"app": "vlc"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, stale, previous, desired, machine_profile=None)
    proposals = [
        record for record in store.journal.read_verified() if record.event == "transaction.proposed"
    ]
    with pytest.raises(StoreError, match="stale catalog"):
        store.propose(
            invocation, previous, desired, decision=decision, catalog_hash=digest_catalog(stale)
        )
    assert store.in_flight() is None
    assert [
        record for record in store.journal.read_verified() if record.event == "transaction.proposed"
    ] == proposals


def test_rolled_back_catalog_rejected(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    stale = _mutated_catalog()
    _drive_to_blessed(store, digest_catalog(stale))
    current = digest_catalog(load_catalog())
    invocation = resolve_invocation(load_catalog(), "app.install", {"app": "chromium"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, load_catalog(), previous, desired, machine_profile=None)
    with pytest.raises(StoreError, match="stale catalog"):
        store.propose(invocation, previous, desired, decision=decision, catalog_hash=current)
    assert store.in_flight() is None


def test_malformed_catalog_hash_refused(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    previous = DesiredState()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=None)
    with pytest.raises(StoreError, match="catalog hash"):
        store.propose(invocation, previous, desired, decision=decision, catalog_hash="bogus")


def test_stale_proposal_rejected_on_replay(tmp_path: Path) -> None:
    store, _blessed = blessed_app_transaction(tmp_path)
    stale = _mutated_catalog()
    invocation = resolve_invocation(stale, "app.install", {"app": "vlc"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, stale, previous, desired, machine_profile=None)
    store.journal.append_proposal(
        {
            "catalog_hash": digest_catalog(stale),
            "invocation": invocation.model_dump(mode="json"),
            "prev_state": previous.model_dump(mode="json"),
            "new_state": desired.model_dump(mode="json"),
            "decision": decision.model_dump(mode="json"),
            "acks": [],
        }
    )
    journal = AuthenticatedJournal(tmp_path, TEST_JOURNAL_KEY)
    with pytest.raises(ProjectionError, match="stale catalog"):
        TransactionStore(tmp_path / "txn.db", journal)
