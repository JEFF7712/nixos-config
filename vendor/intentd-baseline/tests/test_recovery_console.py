import ast
import json
from pathlib import Path

import pytest

from intentd.boot import BootArtifact, BootObservation
from intentd.recovery_console import RecoveryConsoleDeps, run_console
from intentd.store import TransactionStore
from intentd.txn import TxnStatus
from tests.helpers import blessed_app_transaction, boot_artifact_fixture, make_store

_CONSOLE = Path(__file__).resolve().parent.parent / "src" / "intentd" / "recovery_console.py"


def _anchored_blessed(tmp_path: Path) -> tuple[TransactionStore, int]:
    store, txn = blessed_app_transaction(tmp_path)
    store.anchor_blessed_boot(
        txn,
        boot_artifact_fixture(
            closure_path="/nix/store/app-candidate",
            entry_id="blessed.efi",
            uki_sha256="d" * 64,
        ),
    )
    return store, txn


def test_console_module_has_no_model_network_or_shell_imports() -> None:
    tree = ast.parse(_CONSOLE.read_text())
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module is not None:
            imported.add(node.module.split(".")[0])
    assert not (imported & {"socket", "urllib", "http", "ssl", "websocket", "xmlrpc"})
    assert "intentd.resolver" not in {
        f"{node.module}" for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)
    }
    assert "resolver" not in imported


class _Fakes:
    def __init__(self, store: TransactionStore) -> None:
        self.store = store
        self.calls: list[tuple[str, ...]] = []

    def observe_boot(self) -> BootObservation:
        artifact = boot_artifact_fixture(
            closure_path="/nix/store/app-candidate",
            entry_id="blessed.efi",
            uki_sha256="d" * 64,
        )
        return BootObservation(
            closure_path=artifact.closure_path,
            entry_id=artifact.entry_id,
            entry_path=artifact.uki_path,
        )

    def verify_artifact(self, artifact: BootArtifact) -> None:
        self.calls.append(("verify", artifact.entry_id))

    def select_entry(self, entry_id: str) -> None:
        self.calls.append(("select-entry", entry_id))

    def reboot(self) -> None:
        self.calls.append(("reboot",))

    def poweroff(self) -> None:
        self.calls.append(("poweroff",))

    def deps(self) -> RecoveryConsoleDeps:
        return RecoveryConsoleDeps(
            store=self.store,
            observe_boot=self.observe_boot,
            verify_artifact=self.verify_artifact,
            select_entry=self.select_entry,
            reboot=self.reboot,
            poweroff=self.poweroff,
        )


def test_unknown_verb_exits_without_acting(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    store, _txn = blessed_app_transaction(tmp_path)
    fakes = _Fakes(store)

    assert run_console(["format-disk"], fakes.deps()) == 2
    assert fakes.calls == []
    assert "usage" in capsys.readouterr().err


def test_inspect_reports_pointers_without_transitions(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    store, txn = blessed_app_transaction(tmp_path)
    fakes = _Fakes(store)
    events_before = store.events(txn)

    assert run_console(["inspect"], fakes.deps()) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["journal_ok"] is True
    assert payload["blessed_txn"] == txn
    assert payload["pending_txn"] is None
    assert store.events(txn) == events_before
    assert fakes.calls == []


def test_select_blessed_verifies_and_selects_without_journal_transition(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    store, txn = _anchored_blessed(tmp_path)
    fakes = _Fakes(store)
    events_before = store.events(txn)

    assert run_console(["select-blessed"], fakes.deps()) == 0
    assert fakes.calls == [("verify", "blessed.efi"), ("select-entry", "blessed.efi")]
    assert store.events(txn) == events_before
    assert "blessed.efi" in capsys.readouterr().out


def test_select_blessed_without_anchor_fails_closed(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    fakes = _Fakes(make_store(tmp_path))

    assert run_console(["select-blessed"], fakes.deps()) == 1
    assert "no authenticated blessed generation" in capsys.readouterr().err
    assert fakes.calls == []


def test_reboot_and_poweroff_call_only_constrained_primitives(tmp_path: Path) -> None:
    store, _txn = blessed_app_transaction(tmp_path)
    fakes = _Fakes(store)

    assert run_console(["reboot"], fakes.deps()) == 0
    assert run_console(["poweroff"], fakes.deps()) == 0
    assert fakes.calls == [("reboot",), ("poweroff",)]
    blessed = store.blessed()
    assert blessed is not None and store.get(blessed.id).status is TxnStatus.BLESSED
