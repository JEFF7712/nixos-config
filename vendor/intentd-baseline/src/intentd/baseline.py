import os
import sys
from pathlib import Path

from intentd import boot
from intentd.boot import BootBaseline, BootError
from intentd.catalog import digest_catalog, load_catalog
from intentd.executor import file_sha256
from intentd.journal import AuthenticatedJournal, JournalError, load_journal_key
from intentd.machine import load_machine_profile
from intentd.projection import ProjectionError
from intentd.state import DesiredState
from intentd.store import StoreError, TransactionStore
from intentd.tpm import TpmError, system_counter

_STATE_DIR = Path("/var/lib/intentd")
_BOOTED_SYSTEM = Path("/run/booted-system")
_CURRENT_SYSTEM = Path("/run/current-system")
_GC_ROOT = Path("/nix/var/nix/gcroots/intentd-baseline")


def capture_baseline() -> BootBaseline:
    closure = _BOOTED_SYSTEM.resolve(strict=True)
    if _CURRENT_SYSTEM.resolve(strict=True) != closure:
        raise BootError("baseline adoption requires the booted system without a live switch")
    installed_command = closure / "sw/bin/intentd-adopt-baseline"
    package_bin = installed_command.resolve(strict=True).parent
    installed_guard = closure / "sw/bin/intentd-boot-guard"
    if (
        not Path(__file__).resolve(strict=True).is_relative_to(package_bin.parent)
        or installed_guard.resolve(strict=True).parent != package_bin
    ):
        raise BootError("baseline adoption must use the package installed in the booted system")
    evidence_dir = closure / "etc/intentd"
    machine = load_machine_profile(evidence_dir / "machine-profile.json")
    state = DesiredState.model_validate_json((evidence_dir / "initial-state.json").read_bytes())
    lock_hash = file_sha256(evidence_dir / "host-flake.lock")
    observation = boot.observe_boot(_BOOTED_SYSTEM)
    uki = Path(observation.entry_path)
    gc_root = _GC_ROOT.with_name(f"{_GC_ROOT.name}-{closure.name.split('-')[0]}")
    artifact = boot.BootArtifact(
        closure_path=str(closure),
        entry_id=observation.entry_id,
        uki_path=observation.entry_path,
        uki_sha256=file_sha256(uki),
        uki_size_bytes=uki.stat().st_size,
        gc_root=str(gc_root),
    )
    baseline = BootBaseline(
        artifact=artifact,
        observation=observation,
        health=boot.capture_health(machine),
        machine_profile=machine,
        state=state,
        catalog_hash=digest_catalog(load_catalog()),
        flake_lock_hash=lock_hash,
    )
    if gc_root.is_symlink():
        if gc_root.resolve(strict=True) != closure:
            raise BootError("baseline GC root already retains a different closure")
    else:
        gc_root.symlink_to(closure)
        fd = os.open(gc_root.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    boot.verify_artifact(artifact)
    return baseline


def main() -> int:
    if sys.argv[1:] or os.geteuid() != 0:
        print("intentd-adopt-baseline requires root and accepts no arguments", file=sys.stderr)
        return 2
    store: TransactionStore | None = None
    try:
        baseline = capture_baseline()
        key = load_journal_key({"INTENTD_JOURNAL_KEY_FILE": str(_STATE_DIR / "journal.key")})
        journal = AuthenticatedJournal(_STATE_DIR, key)
        os.environ.setdefault("TPM2TOOLS_TCTI", "device:/dev/tpmrm0")
        store = TransactionStore(
            _STATE_DIR / "txn.db",
            journal,
            tpm_counter=system_counter(_STATE_DIR / "nv-counter.bin"),
        )
        store.adopt_boot_baseline(baseline)
        print(baseline.model_dump_json())
    except (
        BootError,
        JournalError,
        OSError,
        ProjectionError,
        StoreError,
        TpmError,
        ValueError,
    ) as exc:
        print(exc, file=sys.stderr)
        return 1
    finally:
        if store is not None:
            store.close()
    return 0
