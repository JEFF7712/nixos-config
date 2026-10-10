"""The one approved place that assembles a production `Deps` (M4/M5 review
locks: nothing outside wiring.py and tests may construct Deps or call the
executor directly).
"""

from collections.abc import Callable
from pathlib import Path
from typing import Literal

import pydantic

from intentd import boot, executor, health
from intentd.boot import BootArtifact, BootError
from intentd.catalog import load_catalog
from intentd.executor import ExecError, file_sha256
from intentd.journal import AuthenticatedJournal, load_journal_key
from intentd.machine import load_machine_profile
from intentd.orchestrator import ApplyResult, Deps, apply_intent, startup_reconcile
from intentd.registry import CapabilityInvocation
from intentd.store import TransactionStore
from intentd.tpm import system_counter
from intentd.workspace import init_workspace

_SYSTEM_PROFILE = Path("/nix/var/nix/profiles/system")
_MACHINE_PROFILE = Path("/etc/intentd/machine-profile.json")
_RECOVERY_ARTIFACT = Path("/etc/intentd/recovery-artifact.json")
_CANDIDATE_ARTIFACT = Path("etc/intentd/boot-artifact.json")


class _LockPinCell:
    """Mutable cell shared by the build and activate closures produced
    together in `production_deps`.

    `Deps.activate` is `Callable[[str], int]` -- it gets only the closure
    path, no transaction access -- so the pre-activation lock re-verify that
    closes the M4 TOCTOU gap (build pins flake.lock's hash; activation must
    see the same hash still on disk) can't be threaded through `Deps`'
    shape. Instead the build closure stashes the pin here and the activate
    closure reads it back; both closures are created together below so the
    cell is never shared outside one `production_deps` call.
    """

    def __init__(self) -> None:
        self.value: str | None = None


def _read_current_profile(path: Path) -> str | None:
    if not path.exists():
        return None
    return str(path.resolve())


def _read_artifact(path: Path) -> BootArtifact:
    try:
        return BootArtifact.model_validate_json(path.read_bytes())
    except (OSError, pydantic.ValidationError) as exc:
        raise BootError(f"invalid boot artifact manifest {path}: {exc}") from exc


def _inspect_candidate(closure: str) -> BootArtifact:
    artifact = _read_artifact(Path(closure) / _CANDIDATE_ARTIFACT)
    if artifact.closure_path != closure:
        raise BootError("candidate artifact closure does not match the built closure")
    return artifact


def _install_boot_candidate(
    closure: str,
    candidate_entry_id: str,
    prior_entry_id: str,
) -> None:
    executor.install_boot_candidate(closure)
    executor.set_default(prior_entry_id)
    executor.set_oneshot(candidate_entry_id)


def _make_build_and_activate(
    ws: Path, mode: Literal["switch", "test"]
) -> tuple[Callable[[Path], tuple[str, str]], Callable[[str], int]]:
    pin = _LockPinCell()

    def _host_build(workspace: Path) -> tuple[str, str]:
        closure = executor.build_toplevel(workspace)
        lock = workspace / "flake.lock"
        if not lock.exists():
            # A workspace flake without a lock gets one written as a side
            # effect of `nix build`; if it's still missing something is
            # wrong with the build step itself, not just this pin.
            raise ExecError("expected flake.lock after build")
        lock_pin = file_sha256(lock)
        pin.value = lock_pin
        return closure, lock_pin

    def _verified_activate(closure: str) -> int:
        lock = ws / "flake.lock"
        current = file_sha256(lock) if lock.exists() else None
        if pin.value is None or current != pin.value:
            raise ExecError("flake.lock changed between build and activation")
        return executor.switch_to(closure, mode)

    return _host_build, _verified_activate


def production_deps(state_dir: Path, mode: Literal["switch", "test"]) -> Deps:
    state_dir.mkdir(parents=True, exist_ok=True)
    journal = AuthenticatedJournal(state_dir, load_journal_key())
    store = TransactionStore(
        state_dir / "txn.db", journal, tpm_counter=system_counter(state_dir / "nv-counter.bin")
    )
    ws = state_dir / "ws"
    if not ws.exists() or not any(ws.iterdir()):
        init_workspace(ws)
    catalog = load_catalog()
    build, activate = _make_build_and_activate(ws, mode)
    machine_profile = load_machine_profile(_MACHINE_PROFILE)
    return Deps(
        store=store,
        workspace=ws,
        catalog=catalog,
        machine_profile=machine_profile,
        build=build,
        set_profile=executor.set_system_profile,
        activate=activate,
        failed_units=health.failed_units,
        current_profile=lambda: _read_current_profile(_SYSTEM_PROFILE),
        capture_health=lambda: boot.capture_health(machine_profile),
        inspect_candidate=_inspect_candidate,
        verify_artifact=boot.verify_artifact,
        retain_artifact=lambda artifact, role: executor.retain_artifact(
            artifact.closure_path, Path("/var/lib/intentd/gcroots") / role
        ),
        recovery_artifact=lambda: _read_artifact(_RECOVERY_ARTIFACT),
        install_boot_candidate=_install_boot_candidate,
        reboot=executor.reboot,
    )


def apply_with_reconcile(
    deps: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
) -> ApplyResult:
    """The only apply entrypoint the CLI/picker may use: startup reconcile
    always runs immediately before an apply attempt."""
    startup_reconcile(deps)
    return apply_intent(deps, invocation, acks)
