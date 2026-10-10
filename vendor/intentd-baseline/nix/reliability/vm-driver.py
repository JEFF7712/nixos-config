import hashlib
import json
import os
import re
import sys
from pathlib import Path

from intentd import boot, executor
from intentd.boot import BootArtifact
from intentd.catalog import digest_catalog, load_catalog
from intentd.journal import AuthenticatedJournal, load_journal_key
from intentd.machine import load_machine_profile
from intentd.orchestrator import Deps, apply_intent
from intentd.policy import evaluate
from intentd.registry import resolve_invocation
from intentd.render import render
from intentd.state import DesiredState, apply_invocation
from intentd.store import TransactionStore
from intentd.tpm import system_counter
from intentd.txn import TransactionRecord, TxnStatus
from intentd.workspace import init_workspace

_STATE_DIR = Path("/var/lib/intentd")
_WORKSPACE = _STATE_DIR / "ws"
_GC_ROOTS = _STATE_DIR / "gcroots"
_REBOOT_MARKER = Path("/run/intentd-reboot-requested")
_COUNT_SUFFIX = re.compile(r"\+[0-9]+(?:-[0-9]+)?(?=\.efi$)")
_SCENARIOS = {
    "stage-integrated": "integrated",
    "stage-hybrid": "hybrid",
    "stage-unhealthy": "unhealthy",
    "stage-critfail": "critfail",
    "stage-powerloss": "powerloss",
}


def _store() -> TransactionStore:
    journal = AuthenticatedJournal(_STATE_DIR, load_journal_key())
    return TransactionStore(
        _STATE_DIR / "txn.db",
        journal,
        tpm_counter=system_counter(_STATE_DIR / "nv-counter.bin"),
    )


def _ensure_gc_root(role: str, closure: str) -> Path:
    _GC_ROOTS.mkdir(parents=True, exist_ok=True)
    root = _GC_ROOTS / role
    if root.is_symlink():
        if str(root.resolve()) == str(Path(closure).resolve()):
            return root
        root.unlink()
    elif root.exists():
        raise RuntimeError(f"GC root is not a symlink: {root}")
    temporary = root.with_name(f".{root.name}.new")
    if temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(closure)
    temporary.replace(root)
    return root


def _artifact(closure: str, entry_id: str, uki_path: Path, role: str) -> BootArtifact:
    root = _ensure_gc_root(role, closure)
    content = uki_path.read_bytes()
    return BootArtifact(
        closure_path=closure,
        entry_id=entry_id,
        uki_path=str(uki_path),
        uki_sha256=hashlib.sha256(content).hexdigest(),
        uki_size_bytes=len(content),
        gc_root=str(root),
    )


def _selected_artifact(role: str) -> BootArtifact:
    observation = boot.observe_boot()
    return _artifact(
        observation.closure_path,
        observation.entry_id,
        Path(observation.entry_path),
        role,
    )


def _specialisation_artifact(name: str, closure: str, role: str) -> BootArtifact:
    matches = sorted(Path("/boot/EFI/Linux").glob(f"*specialisation-{name}-*.efi"))
    if not matches:
        raise RuntimeError(f"no installed UKI for specialisation {name}")
    counted = [path for path in matches if _COUNT_SUFFIX.search(path.name)]
    path = counted[-1] if counted else matches[-1]
    entry_id = _COUNT_SUFFIX.sub("", path.name)
    return _artifact(closure, entry_id, path, role)


def _candidate_closure(name: str) -> str:
    variable = f"INTENTD_CANDIDATE_{name.upper()}"
    closure = os.environ.get(variable)
    if closure is None:
        raise RuntimeError(f"missing fixed candidate closure: {variable}")
    return closure


def _set_vm_profile(closure: str) -> None:
    profile = Path("/nix/var/nix/profiles/system")
    temporary = profile.with_name(".intentd-system.new")
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(closure)
    temporary.replace(profile)


def _seed_blessed() -> dict[str, object]:
    store = _store()
    existing = store.blessed()
    if existing is not None:
        if existing.boot_artifact is None:
            raise RuntimeError("existing blessed transaction has no boot anchor")
        return {
            "txn": existing.id,
            "artifact": existing.boot_artifact.model_dump(mode="json"),
        }
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    previous = DesiredState()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(invocation, catalog, previous, desired, machine_profile=None)
    rendered_hash = hashlib.sha256(render(desired, catalog, None).encode()).hexdigest()
    lock_hash = hashlib.sha256(b"intentd-vm-seed").hexdigest()
    closure = str(Path("/run/current-system").resolve(strict=True))
    txn = store.propose(
        invocation, previous, desired, decision=decision, catalog_hash=digest_catalog(catalog)
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash=rendered_hash)
    store.transition(
        txn,
        TxnStatus.BUILT,
        closure_path=closure,
        flake_lock_hash=lock_hash,
    )
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)
    artifact = _selected_artifact("blessed")
    boot.verify_artifact(artifact)
    store.anchor_blessed_boot(txn, artifact)
    return {"txn": txn, "artifact": artifact.model_dump(mode="json")}


def _retain(artifact: BootArtifact, role: str) -> None:
    _ensure_gc_root(role, artifact.closure_path)


def _stage(verb: str) -> dict[str, object]:
    name = _SCENARIOS[verb]
    closure = _candidate_closure(name)
    recovery_closure = _candidate_closure("recovery")
    candidate = _specialisation_artifact(name, closure, "candidate")
    recovery = _specialisation_artifact("recovery", recovery_closure, "recovery")
    profile = load_machine_profile(Path("/etc/intentd/machine-profile.json"))
    baseline = boot.capture_health(profile)
    if baseline.root_free_bytes < profile.root_reserve_bytes:
        raise RuntimeError("root capacity is below the VM reserve")
    if baseline.esp_free_bytes < profile.esp_reserve_bytes + candidate.uki_size_bytes:
        raise RuntimeError("ESP capacity cannot retain the VM reserve")
    if not _WORKSPACE.exists():
        init_workspace(_WORKSPACE)
    store = _store()
    catalog = load_catalog()
    lock_hash = hashlib.sha256(f"intentd-vm-{name}".encode()).hexdigest()

    def install(
        candidate_closure: str,
        candidate_entry_id: str,
        prior_entry_id: str,
    ) -> None:
        executor.install_boot_candidate(candidate_closure)
        executor.set_default(prior_entry_id)
        executor.set_oneshot(candidate_entry_id)

    deps = Deps(
        store=store,
        workspace=_WORKSPACE,
        catalog=catalog,
        machine_profile=profile,
        build=lambda workspace: (closure, lock_hash),
        set_profile=_set_vm_profile,
        activate=lambda candidate_closure: 0,
        failed_units=boot.failed_units,
        current_profile=lambda: str(Path("/run/current-system").resolve()),
        capture_health=lambda: boot.capture_health(profile),
        inspect_candidate=lambda candidate_closure: candidate,
        verify_artifact=boot.verify_artifact,
        retain_artifact=_retain,
        recovery_artifact=lambda: recovery,
        install_boot_candidate=install,
        reboot=lambda: _REBOOT_MARKER.touch(exist_ok=False),
    )
    profile_name = "hybrid-nvidia" if name == "hybrid" else "integrated"
    invocation = resolve_invocation({}, "hardware.graphics.profile", {"profile": profile_name})
    result = apply_intent(deps, invocation)
    if result.record is None:
        raise RuntimeError(result.decision.reason)
    if result.record.status is not TxnStatus.PENDING:
        raise RuntimeError(json.dumps(_record_payload(result.record), sort_keys=True))
    return _record_payload(result.record)


def _record_payload(record: TransactionRecord) -> dict[str, object]:
    return record.model_dump(mode="json")


def _oneshot_recovery() -> dict[str, object]:
    recovery = _specialisation_artifact("recovery", _candidate_closure("recovery"), "recovery")
    boot.verify_artifact(recovery)
    esp_matches = sorted(path.name for path in Path("/boot/EFI/Linux").glob("*.efi"))
    executor.set_oneshot(recovery.entry_id)
    return {"entry_id": recovery.entry_id, "esp_entries": esp_matches}


def _status() -> dict[str, object]:
    store = _store()
    blessed = store.blessed()
    active = store.active()
    pending = store.in_flight()
    recent = store.recent(1)
    return {
        "blessed_txn": None if blessed is None else blessed.id,
        "blessed": None if blessed is None else _record_payload(blessed),
        "active_txn": None if active is None else active.id,
        "pending_txn": None if pending is None else pending.id,
        "failed_txn": None if not recent else _record_payload(recent[0]),
        "boot_outcome": (
            None
            if active is None or active.boot_outcome is None
            else active.boot_outcome.model_dump(mode="json")
        ),
        "booted_closure": str(Path("/run/current-system").resolve(strict=True)),
        "boot": boot.observe_boot().model_dump(mode="json"),
    }


def _journal() -> list[dict[str, object]]:
    return [record.model_dump(mode="json") for record in _store().journal.read_verified()]


def main() -> int:
    if len(sys.argv) != 2:
        return 2
    verb = sys.argv[1]
    if verb == "seed-blessed":
        output: object = _seed_blessed()
    elif verb == "oneshot-recovery":
        output = _oneshot_recovery()
    elif verb in _SCENARIOS:
        output = _stage(verb)
    elif verb == "status":
        output = _status()
    elif verb == "journal":
        output = _journal()
    else:
        return 2
    print(json.dumps(output, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
