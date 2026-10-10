import shutil
from pathlib import Path

import pytest

from intentd.boot import BootOutcome
from intentd.catalog import digest_catalog, load_catalog
from intentd.policy import evaluate
from intentd.registry import resolve_invocation
from intentd.state import DesiredState, apply_invocation
from intentd.store import StoreError, TransactionStore
from intentd.tpm import INTENTD_NV_INDEX, NvCounter
from intentd.txn import NV_COUNTER_MAX, TransitionError, TxnStatus
from tests.helpers import (
    boot_plan_fixture,
    failed_outcome_fixture,
    make_store,
    memory_nv_counter,
    vm_machine_profile,
)


class _AdjustableCounter:
    def __init__(self, value: int = 0) -> None:
        self.value = value
        self.counter = NvCounter(index=INTENTD_NV_INDEX, read=self._read, increment=self._increment)

    def _read(self) -> int:
        return self.value

    def _increment(self) -> int:
        self.value += 1
        return self.value


def _pending_boot_txn(store: TransactionStore) -> int:
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "hardware.graphics.profile", {"profile": "integrated"})
    previous = store.blessed_state()
    desired = apply_invocation(previous, invocation)
    profile = vm_machine_profile()
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=profile)
    txn = store.propose(
        invocation,
        previous,
        desired,
        decision=decision,
        catalog_hash=digest_catalog(catalog),
        machine_profile_id=profile.profile_id,
    )
    plan = boot_plan_fixture()
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash=plan.rendered_hash)
    store.transition(
        txn,
        TxnStatus.BUILT,
        closure_path=plan.candidate.closure_path,
        flake_lock_hash=plan.flake_lock_hash,
    )
    store.transition(txn, TxnStatus.PENDING, boot_plan=plan)
    return txn


def _healthy_outcome() -> BootOutcome:
    failed = failed_outcome_fixture()
    return failed.model_copy(
        update={
            "healthy": True,
            "quarantined": False,
            "health": boot_plan_fixture().baseline,
            "failures": (),
        }
    )


def _bless_boot_txn(store: TransactionStore) -> int:
    txn = _pending_boot_txn(store)
    store.transition(txn, TxnStatus.BLESSED, boot_outcome=_healthy_outcome())
    return txn


def test_boot_bless_without_counter_is_refused(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    txn = _pending_boot_txn(store)
    with pytest.raises(TransitionError, match="NV rollback counter"):
        store.transition(txn, TxnStatus.BLESSED, boot_outcome=_healthy_outcome())


def test_boot_bless_records_incremented_counter(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    txn = _bless_boot_txn(store)
    assert store.get(txn).nv_counter == 1
    assert fake.value == 1
    store.close()
    reopened = make_store(tmp_path, tpm_counter=fake.counter)
    assert reopened.get(txn).nv_counter == 1
    reopened.close()


def test_sequential_boot_blessings_advance_monotonically(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    first = _bless_boot_txn(store)
    second = _bless_boot_txn(store)
    assert store.get(first).nv_counter == 1
    assert store.get(second).nv_counter == 2
    assert fake.value == 2
    store.close()


def test_non_boot_bless_needs_no_counter_and_records_none(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    previous = DesiredState()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=None)
    txn = store.propose(
        invocation, previous, desired, decision=decision, catalog_hash=digest_catalog(catalog)
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="a" * 64)
    store.transition(txn, TxnStatus.BUILT, closure_path="/nix/store/app", flake_lock_hash="b" * 64)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)
    assert store.get(txn).nv_counter is None
    store.close()


def test_crash_gap_reopens_and_next_bless_repairs(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    _bless_boot_txn(store)
    store.close()
    fake.value = 0
    repaired = make_store(tmp_path, tpm_counter=fake.counter)
    second = _bless_boot_txn(repaired)
    assert repaired.get(second).nv_counter == 2
    assert fake.value == 2
    repaired.close()


def test_out_of_band_increment_refuses_reopen(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    _bless_boot_txn(store)
    store.close()
    fake.value = 2
    with pytest.raises(StoreError, match="NV counter disagrees"):
        make_store(tmp_path, tpm_counter=fake.counter)


def test_journal_ahead_by_two_refuses_reopen(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    _bless_boot_txn(store)
    _bless_boot_txn(store)
    store.close()
    fake.value = 0
    with pytest.raises(StoreError, match="NV counter disagrees"):
        make_store(tmp_path, tpm_counter=fake.counter)


def test_counter_bound_state_without_counter_refuses_reopen(tmp_path: Path) -> None:
    store = make_store(tmp_path, tpm_counter=memory_nv_counter())
    _bless_boot_txn(store)
    store.close()
    with pytest.raises(StoreError, match="counter-bound state"):
        make_store(tmp_path)


def test_bless_refuses_when_counter_is_ahead_of_journal(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    _bless_boot_txn(store)
    fake.value = 5
    txn = _pending_boot_txn(store)
    with pytest.raises(TransitionError, match="ahead of the journal"):
        store.transition(txn, TxnStatus.BLESSED, boot_outcome=_healthy_outcome())
    store.close()


def _snapshot_journal(state_dir: Path, backup_dir: Path) -> None:
    backup_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(state_dir / "journal.jsonl", backup_dir / "journal.jsonl")
    shutil.copy2(state_dir / "journal.checkpoint.json", backup_dir / "journal.checkpoint.json")


def _restore_journal(state_dir: Path, backup_dir: Path) -> None:
    shutil.copy2(backup_dir / "journal.jsonl", state_dir / "journal.jsonl")
    shutil.copy2(backup_dir / "journal.checkpoint.json", state_dir / "journal.checkpoint.json")


def test_rewound_journal_refuses_reopen(tmp_path: Path) -> None:
    fake = _AdjustableCounter()
    store = make_store(tmp_path, tpm_counter=fake.counter)
    _bless_boot_txn(store)
    _snapshot_journal(tmp_path, tmp_path / "backup")
    _bless_boot_txn(store)
    assert fake.value == 2
    store.close()
    _restore_journal(tmp_path, tmp_path / "backup")
    with pytest.raises(StoreError, match="NV counter disagrees"):
        make_store(tmp_path, tpm_counter=fake.counter)


def test_counter_exhaustion_refuses_blessing(tmp_path: Path) -> None:
    fake = _AdjustableCounter(NV_COUNTER_MAX)
    store = make_store(tmp_path, tpm_counter=fake.counter)
    txn = _pending_boot_txn(store)
    with pytest.raises(TransitionError, match="exhausted"):
        store.transition(txn, TxnStatus.BLESSED, boot_outcome=_healthy_outcome())
    store.close()
