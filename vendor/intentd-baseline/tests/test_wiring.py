from pathlib import Path
from typing import Literal

import pytest

from intentd import wiring
from intentd.executor import ExecError, file_sha256
from intentd.journal import JournalError
from intentd.machine import MachineProfile
from intentd.orchestrator import ApplyResult, Deps
from intentd.policy import PolicyDecision, PolicyVerdict
from intentd.registry import CapabilityInvocation
from intentd.wiring import (
    _read_current_profile,  # pyright: ignore[reportPrivateUsage]
    apply_with_reconcile,
    production_deps,
)
from intentd.workspace import verify_workspace
from tests.helpers import vm_machine_profile


def _load_vm_profile(path: Path) -> MachineProfile:
    assert path == Path("/etc/intentd/machine-profile.json")
    return vm_machine_profile()


@pytest.fixture(autouse=True)
def _journal_key(  # pyright: ignore[reportUnusedFunction]
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    key_file = tmp_path / "journal.key"
    key_file.write_bytes(bytes(range(32)))
    key_file.chmod(0o600)
    monkeypatch.setenv("INTENTD_JOURNAL_KEY_FILE", str(key_file))
    monkeypatch.setattr(wiring, "load_machine_profile", _load_vm_profile)


def _deps_with_stub_build(
    tmp_path: Path, mode: Literal["switch", "test"] = "switch"
) -> tuple[Deps, Path]:
    deps = production_deps(tmp_path / "state", mode)
    return deps, deps.workspace


def _stub_build_toplevel(path: Path) -> str:
    return "/nix/store/closure-a"


def _stub_switch_to_ok(closure: str, action: Literal["switch", "test"]) -> int:
    return 0


def test_lock_reverify_raises_on_mismatch(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    deps, ws = _deps_with_stub_build(tmp_path)
    lock = ws / "flake.lock"
    lock.write_text("lock-v1")

    monkeypatch.setattr(wiring.executor, "build_toplevel", _stub_build_toplevel)
    monkeypatch.setattr(wiring.executor, "switch_to", _stub_switch_to_ok)

    closure, lock_pin = deps.build(ws)
    assert closure == "/nix/store/closure-a"
    assert lock_pin == file_sha256(lock)

    lock.write_text("lock-v2-mutated")

    with pytest.raises(ExecError, match="changed between build and activation"):
        deps.activate(closure)


def test_lock_reverify_passes_when_unchanged(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    deps, ws = _deps_with_stub_build(tmp_path)
    lock = ws / "flake.lock"
    lock.write_text("lock-v1")

    monkeypatch.setattr(wiring.executor, "build_toplevel", _stub_build_toplevel)

    switch_calls: list[tuple[str, str]] = []

    def _record_switch(closure: str, action: Literal["switch", "test"]) -> int:
        switch_calls.append((closure, action))
        return 0

    monkeypatch.setattr(wiring.executor, "switch_to", _record_switch)

    closure, _lock_pin = deps.build(ws)
    rc = deps.activate(closure)

    assert rc == 0
    assert switch_calls == [("/nix/store/closure-a", "switch")]


def test_missing_lock_after_build_raises(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    deps, ws = _deps_with_stub_build(tmp_path)
    assert not (ws / "flake.lock").exists()

    monkeypatch.setattr(wiring.executor, "build_toplevel", _stub_build_toplevel)

    with pytest.raises(ExecError, match="expected flake.lock after build"):
        deps.build(ws)


def test_activate_before_any_build_raises(tmp_path: Path):
    deps, ws = _deps_with_stub_build(tmp_path)
    (ws / "flake.lock").write_text("lock-v1")

    with pytest.raises(ExecError, match="changed between build and activation"):
        deps.activate("/nix/store/closure-a")


def test_test_mode_passes_test_action_to_switch(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    deps, ws = _deps_with_stub_build(tmp_path, mode="test")
    lock = ws / "flake.lock"
    lock.write_text("lock-v1")
    monkeypatch.setattr(wiring.executor, "build_toplevel", _stub_build_toplevel)

    switch_calls: list[tuple[str, str]] = []

    def _record_switch(closure: str, action: Literal["switch", "test"]) -> int:
        switch_calls.append((closure, action))
        return 0

    monkeypatch.setattr(wiring.executor, "switch_to", _record_switch)

    closure, _lock_pin = deps.build(ws)
    deps.activate(closure)

    assert switch_calls == [("/nix/store/closure-a", "test")]


def test_reconcile_runs_before_apply(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    deps, _ws = _deps_with_stub_build(tmp_path)
    calls: list[str] = []

    def fake_reconcile(d: Deps) -> None:
        assert d is deps
        calls.append("reconcile")

    def fake_apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        assert d is deps
        calls.append("apply")
        return ApplyResult(decision=_dummy_decision(), record=None)

    monkeypatch.setattr(wiring, "startup_reconcile", fake_reconcile)
    monkeypatch.setattr(wiring, "apply_intent", fake_apply)

    inv = CapabilityInvocation(capability="change.revert", params={})
    result = apply_with_reconcile(deps, inv)

    assert calls == ["reconcile", "apply"]
    assert result.record is None


def _dummy_decision() -> PolicyDecision:
    return PolicyDecision(verdict=PolicyVerdict.REJECT, reason="test stub")


def test_first_run_inits_workspace_second_run_does_not_reinit(tmp_path: Path):
    state_dir = tmp_path / "state"

    deps1 = production_deps(state_dir, "switch")
    ws = deps1.workspace
    assert (ws / "flake.nix").exists()
    assert (ws / "manifest.json").exists()
    verify_workspace(ws)

    deps2 = production_deps(state_dir, "switch")

    assert deps2.workspace == deps1.workspace
    verify_workspace(ws)


def test_production_deps_creates_state_dir(tmp_path: Path):
    state_dir = tmp_path / "does" / "not" / "exist" / "yet"
    assert not state_dir.exists()

    deps = production_deps(state_dir, "switch")

    assert state_dir.exists()
    assert (state_dir / "txn.db").exists()
    assert deps.workspace == state_dir / "ws"


def test_production_deps_loads_catalog_and_shapes_deps(tmp_path: Path):
    deps = production_deps(tmp_path / "state", "switch")

    assert "firefox" in deps.catalog
    assert deps.machine_profile == vm_machine_profile()
    assert deps.set_profile is wiring.executor.set_system_profile
    assert deps.failed_units is wiring.health.failed_units


def test_production_deps_fails_closed_without_journal_key(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("INTENTD_JOURNAL_KEY_FILE")
    monkeypatch.delenv("CREDENTIALS_DIRECTORY", raising=False)

    with pytest.raises(JournalError, match="journal credential is unavailable"):
        production_deps(tmp_path / "state", "switch")


def test_read_current_profile_returns_none_when_absent(tmp_path: Path):
    missing = tmp_path / "no-such-profile"
    assert _read_current_profile(missing) is None


def test_read_current_profile_resolves_symlink(tmp_path: Path):
    target = tmp_path / "generation-42"
    target.mkdir()
    profile = tmp_path / "system"
    profile.symlink_to(target)

    assert _read_current_profile(profile) == str(target.resolve())
