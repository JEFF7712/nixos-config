"""Constrained recovery console: four typed actions, no model, no network, no shell."""

import json
import os
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from intentd.boot import BootArtifact, BootError, BootObservation, observe_boot, verify_artifact
from intentd.executor import ExecError, poweroff, reboot, set_default
from intentd.journal import AuthenticatedJournal, JournalError, load_journal_key
from intentd.store import StoreError, TransactionStore
from intentd.tpm import TpmError, system_counter
from intentd.txn import TransitionError

_STATE_DIR = Path("/var/lib/intentd")

_VERBS = ("inspect", "select-blessed", "reboot", "poweroff")


@dataclass(frozen=True)
class RecoveryConsoleDeps:
    store: TransactionStore
    observe_boot: Callable[[], BootObservation]
    verify_artifact: Callable[[BootArtifact], None]
    select_entry: Callable[[str], None]
    reboot: Callable[[], None]
    poweroff: Callable[[], None]


def _status(deps: RecoveryConsoleDeps) -> dict[str, object]:
    deps.store.journal.read_verified()
    blessed = deps.store.blessed()
    active = deps.store.active()
    pending = deps.store.in_flight()
    observation = deps.observe_boot()
    artifact = deps.store.blessed_boot_artifact()
    return {
        "journal_ok": True,
        "blessed_txn": None if blessed is None else blessed.id,
        "blessed_closure": None if artifact is None else artifact.closure_path,
        "active_txn": None if active is None else active.id,
        "pending_txn": None if pending is None else pending.id,
        "booted_closure": observation.closure_path,
        "booted_entry_id": observation.entry_id,
    }


def run_console(argv: list[str], deps: RecoveryConsoleDeps) -> int:
    if len(argv) != 1 or argv[0] not in _VERBS:
        print(f"usage: intentd-recovery-console [{'|'.join(_VERBS)}]", file=sys.stderr)
        return 2
    verb = argv[0]
    try:
        if verb == "inspect":
            print(json.dumps(_status(deps), sort_keys=True))
            return 0
        if verb == "select-blessed":
            artifact = deps.store.blessed_boot_artifact()
            if artifact is None:
                print("no authenticated blessed generation to select", file=sys.stderr)
                return 1
            deps.verify_artifact(artifact)
            deps.select_entry(artifact.entry_id)
            print(json.dumps({"selected": artifact.entry_id}, sort_keys=True))
            return 0
        if verb == "reboot":
            deps.reboot()
            print(json.dumps({"rebooting": True}, sort_keys=True))
            return 0
        deps.poweroff()
        print(json.dumps({"powering-off": True}, sort_keys=True))
        return 0
    except (
        BootError,
        ExecError,
        JournalError,
        OSError,
        StoreError,
        TpmError,
        TransitionError,
    ) as exc:
        print(exc, file=sys.stderr)
        return 1


def _production_deps() -> RecoveryConsoleDeps:
    state_dir = Path(os.environ.get("INTENTD_STATE_DIR", _STATE_DIR))
    journal = AuthenticatedJournal(state_dir, load_journal_key())
    store = TransactionStore(
        state_dir / "txn.db", journal, tpm_counter=system_counter(state_dir / "nv-counter.bin")
    )
    return RecoveryConsoleDeps(
        store=store,
        observe_boot=observe_boot,
        verify_artifact=verify_artifact,
        select_entry=set_default,
        reboot=reboot,
        poweroff=poweroff,
    )


def main() -> int:
    return run_console(sys.argv[1:], _production_deps())


if __name__ == "__main__":
    raise SystemExit(main())
