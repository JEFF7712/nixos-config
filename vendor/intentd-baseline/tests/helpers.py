from pathlib import Path

from intentd.boot import (
    BootArtifact,
    BootObservation,
    BootOutcome,
    BootPlan,
    BootStagingFailure,
    BootStagingPhase,
    HealthSnapshot,
)
from intentd.catalog import digest_catalog, load_catalog
from intentd.journal import AuthenticatedJournal, Payload
from intentd.machine import GraphicsBackend, MachineProfile
from intentd.policy import evaluate
from intentd.registry import digest_invocation, resolve_invocation
from intentd.state import DesiredState, apply_invocation
from intentd.store import TransactionStore
from intentd.tpm import INTENTD_NV_INDEX, NvCounter
from intentd.txn import TxnStatus

TEST_JOURNAL_KEY = bytes(range(32))


def memory_nv_counter(start: int = 0) -> NvCounter:
    state = {"value": start}

    def _read() -> int:
        return state["value"]

    def _increment() -> int:
        state["value"] += 1
        return state["value"]

    return NvCounter(index=INTENTD_NV_INDEX, read=_read, increment=_increment)


def vm_machine_profile() -> MachineProfile:
    return MachineProfile(
        profile_id="intentd-vm-v1",
        certified=True,
        graphics_backend=GraphicsBackend.INTENTD_VM,
        intel_pci="0000:00:02.0",
        nvidia_pci="0000:01:00.0",
        critical_units=("intentd-display-ready.service",),
        display_unit="intentd-display-ready.service",
        root_reserve_bytes=268_435_456,
        esp_reserve_bytes=134_217_728,
    )


def proposal_payload(app: str) -> Payload:
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": app})
    prev_state = DesiredState()
    new_state = DesiredState(apps=(app,))
    decision = evaluate(invocation, catalog, prev_state, new_state, machine_profile=None)
    return {
        "catalog_hash": digest_catalog(catalog),
        "invocation": invocation.model_dump(mode="json"),
        "prev_state": prev_state.model_dump(mode="json"),
        "new_state": new_state.model_dump(mode="json"),
        "decision": decision.model_dump(mode="json"),
        "acks": [],
    }


def make_store(state_dir: Path, tpm_counter: NvCounter | None = None) -> TransactionStore:
    state_dir.mkdir(parents=True, exist_ok=True)
    journal = AuthenticatedJournal(state_dir, TEST_JOURNAL_KEY)
    return TransactionStore(state_dir / "txn.db", journal, tpm_counter=tpm_counter)


def boot_artifact_fixture(
    *,
    closure_path: str = "/nix/store/graphics-candidate",
    entry_id: str = "graphics-candidate.efi",
    uki_sha256: str = "c" * 64,
    uki_size_bytes: int = 4096,
) -> BootArtifact:
    name = entry_id.removesuffix(".efi")
    return BootArtifact(
        closure_path=closure_path,
        entry_id=entry_id,
        uki_path=f"/boot/EFI/Linux/{entry_id}",
        uki_sha256=uki_sha256,
        uki_size_bytes=uki_size_bytes,
        gc_root=f"/var/lib/intentd/gcroots/{name}",
    )


def boot_plan_fixture(*, invocation_hash: str | None = None) -> BootPlan:
    if invocation_hash is None:
        invocation = resolve_invocation(
            load_catalog(), "hardware.graphics.profile", {"profile": "integrated"}
        )
        invocation_hash = digest_invocation(invocation)
    return BootPlan(
        invocation_hash=invocation_hash,
        candidate=boot_artifact_fixture(),
        prior_blessed=boot_artifact_fixture(
            closure_path="/nix/store/blessed",
            entry_id="blessed.efi",
            uki_sha256="d" * 64,
        ),
        recovery=boot_artifact_fixture(
            closure_path="/nix/store/recovery",
            entry_id="recovery.efi",
            uki_sha256="e" * 64,
        ),
        baseline=HealthSnapshot(
            failed_units=(),
            inactive_critical_units=(),
            display_ready=True,
            root_free_bytes=536_870_912,
            esp_free_bytes=268_435_456,
        ),
        machine_profile_id="intentd-vm-v1",
        root_reserve_bytes=268_435_456,
        esp_reserve_bytes=134_217_728,
        rendered_hash="a" * 64,
        flake_lock_hash="b" * 64,
    )


def failed_outcome_fixture() -> BootOutcome:
    plan = boot_plan_fixture()
    return BootOutcome(
        healthy=False,
        recovered=False,
        quarantined=True,
        observation=BootObservation(
            closure_path=plan.candidate.closure_path,
            entry_id=plan.candidate.entry_id,
            entry_path=plan.candidate.uki_path,
        ),
        health=plan.baseline.model_copy(update={"display_ready": False}),
        failures=("display is not ready",),
    )


def staging_failure_fixture(
    phase: BootStagingPhase = BootStagingPhase.INSTALL_CANDIDATE,
) -> BootStagingFailure:
    return BootStagingFailure(
        candidate=boot_plan_fixture().candidate,
        phase=phase,
        detail="candidate installation failed",
        quarantined=True,
    )


def built_graphics_transaction(
    tmp_path: Path, tpm_counter: NvCounter | None = None
) -> tuple[TransactionStore, int]:
    store = make_store(tmp_path, tpm_counter=tpm_counter)
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "hardware.graphics.profile", {"profile": "integrated"})
    previous = DesiredState()
    desired = apply_invocation(previous, invocation)
    machine_profile = vm_machine_profile()
    decision = evaluate(
        invocation,
        catalog,
        previous,
        desired,
        machine_profile=machine_profile,
    )
    txn = store.propose(
        invocation,
        previous,
        desired,
        decision=decision,
        catalog_hash=digest_catalog(catalog),
        machine_profile_id=machine_profile.profile_id,
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="a" * 64)
    store.transition(
        txn,
        TxnStatus.BUILT,
        closure_path="/nix/store/graphics-candidate",
        flake_lock_hash="b" * 64,
    )
    return store, txn


def built_app_transaction(tmp_path: Path) -> tuple[TransactionStore, int]:
    store = make_store(tmp_path)
    catalog = load_catalog()
    invocation = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    previous = DesiredState()
    desired = apply_invocation(previous, invocation)
    decision = evaluate(
        invocation,
        catalog,
        previous,
        desired,
        machine_profile=None,
    )
    txn = store.propose(
        invocation, previous, desired, decision=decision, catalog_hash=digest_catalog(catalog)
    )
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash="a" * 64)
    store.transition(
        txn,
        TxnStatus.BUILT,
        closure_path="/nix/store/app-candidate",
        flake_lock_hash="b" * 64,
    )
    return store, txn


def blessed_app_transaction(tmp_path: Path) -> tuple[TransactionStore, int]:
    store, txn = built_app_transaction(tmp_path)
    store.transition(txn, TxnStatus.PENDING)
    store.transition(txn, TxnStatus.BLESSED)
    return store, txn


def pending_graphics_transaction(
    tmp_path: Path, tpm_counter: NvCounter | None = None
) -> tuple[TransactionStore, int]:
    store, txn = built_graphics_transaction(tmp_path, tpm_counter)
    store.transition(txn, TxnStatus.PENDING, boot_plan=boot_plan_fixture())
    return store, txn
