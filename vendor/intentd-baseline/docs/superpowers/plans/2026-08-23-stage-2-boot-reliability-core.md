# Stage 2 Boot Reliability Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the model-free boot reliability core that stages one boot-counted graphics candidate, authenticates all boot evidence, blesses healthy boots, and returns to the prior blessed generation by boot attempt two after a failed or interrupted candidate.

**Status:** Complete on `stage2-boot-reliability-core` as of 2026-08-26. The remaining Stage 2 failure matrix, constrained recovery console, TPM2 checkpoint binding, and physical-host certification are explicitly outside this milestone.

**Architecture:** Keep systemd-boot and Lanzaboote responsible for entry selection, attempt decrementing, UKI signing, and fallback. intentd owns a one-time authenticated anchor for the pre-existing blessed boot, typed boot plans, authenticated pending and outcome evidence, artifact retention, health comparison, boot identity verification, and reconciliation through a separate `intentd-boot-guard` executable ordered before `boot-complete.target`. A new persistent UEFI NixOS VM check reuses Lanzaboote 1.1.0's image pattern and proves success, failed health, and sudden-power-loss paths without model or network access.

**Tech Stack:** Python 3.12, Pydantic 2, SQLite projection replay, HMAC-SHA256 journal, NixOS modules, Lanzaboote 1.1.0, systemd 260 Automatic Boot Assessment, systemd-boot, OVMF, QEMU, pytest, Ruff, Pyright.

---

## Scope boundary

This plan implements Stage 2 delivery milestone 2 from `docs/superpowers/specs/2026-08-23-stage-2-reliability-prototype-design.md`:

- boot-affecting transaction metadata, initial blessed boot anchoring, and authenticated outcomes;
- `hardware.graphics.profile` with `integrated` and `hybrid-nvidia`;
- a model-free boot guard and bounded baseline health gate;
- boot-counted signed UKIs with one candidate attempt;
- prior-blessed and fixed-recovery artifact retention;
- persistent UEFI VM proof for healthy reboot, failed health, and sudden power loss.

The remaining failure-matrix injections and interactive constrained recovery application stay in milestone 3. TPM2 monotonic checkpoint binding and UX3404VC physical certification stay in milestone 4. The milestone 2 VM contains a fixed recovery UKI and proves its identity and selectability, but does not yet expose the final recovery menu.

Authoritative implementation references:

- `https://github.com/systemd/systemd/blob/main/docs/AUTOMATIC_BOOT_ASSESSMENT.md`
- `https://github.com/nix-community/lanzaboote/blob/v1.1.0/nix/modules/lanzaboote.nix`
- `https://github.com/nix-community/lanzaboote/blob/v1.1.0/nix/tests/lanzaboote/boot-counting.nix`

## File map

- Create `src/intentd/machine.py`: closed machine-profile and graphics-profile models plus root-owned profile loading.
- Create `src/intentd/boot.py`: boot artifact, plan, observation, baseline, and outcome models; bootctl parsing; artifact verification; health decision.
- Create `src/intentd/boot_guard.py`: the model-free boot reconciliation entrypoint.
- Create `tests/test_machine.py`, `tests/test_boot.py`, and `tests/test_boot_guard.py`: focused domain and reconciliation tests.
- Modify `src/intentd/schema.py`, `registry.py`, `state.py`, `policy.py`, and `render.py`: closed graphics capability and deterministic Nix rendering.
- Modify `src/intentd/txn.py`, `projection.py`, `store.py`, and their tests: authenticated boot plan and outcome projection.
- Modify `src/intentd/executor.py`, `orchestrator.py`, `wiring.py`, `cli.py`, and tests: candidate installation, GC roots, pending response, and boot dispatch.
- Create `nix/reliability/module.nix`: boot guard, credential, watchdog, and health-gate service wiring.
- Create `nix/reliability/recovery.nix`: fixed recovery configuration used by the VM artifact.
- Create `nix/reliability/vm-boot.nix`: persistent UEFI, Secure Boot, reboot, fallback, and power-loss proof.
- Modify `flake.nix` and `flake.lock`: pin Lanzaboote 1.1.0, expose the NixOS module, and register the VM check.
- Modify `pyproject.toml`, `docs/host-setup.md`, and `handoff.md`: executable registration and accurate milestone boundary.

### Task 1: Pin Lanzaboote and prove raw boot counting

**Files:**
- Modify: `flake.nix:1-44`
- Modify: `flake.lock`
- Create: `nix/reliability/vm-boot-counting.nix`

- [x] **Step 1: Add the failing flake check reference**

Add the input and check wiring to `flake.nix` before creating the referenced file:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  lanzaboote = {
    url = "github:nix-community/lanzaboote/v1.1.0";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

outputs =
  { self, nixpkgs, lanzaboote }:
  # existing outputs

checks.x86_64-linux.vm-boot-counting =
  (import ./nix/reliability/vm-boot-counting.nix {
    inherit self nixpkgs lanzaboote;
  }).test;
```

- [x] **Step 2: Verify the missing check fails evaluation**

Run: `nix flake check --no-build`

Expected: FAIL because `nix/reliability/vm-boot-counting.nix` does not exist.

- [x] **Step 3: Add the minimal persistent UEFI check**

Create `nix/reliability/vm-boot-counting.nix` by adapting the pinned upstream `boot-counting.nix` and its `common/image.nix` pattern. Keep these intentd-specific assertions:

```nix
{
  self,
  nixpkgs,
  lanzaboote,
}:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  test = pkgs.testers.runNixOSTest {
    name = "intentd-boot-counting";
    extraBaseModules.imports = [ lanzaboote.nixosModules.lanzaboote ];
    nodes.machine = {
      imports = [ "${lanzaboote}/nix/tests/lanzaboote/common/lanzaboote.nix" ];
      boot.lanzaboote.bootCounting.initialTries = 1;
      systemd.targets.boot-complete.after = [ "multi-user.target" ];
      specialisation.bad.configuration = {
        boot.lanzaboote.sortKey = nixpkgs.lib.mkForce "intentd-candidate";
        systemd.services.intentd-failing-health = {
          requiredBy = [ "boot-complete.target" ];
          before = [ "boot-complete.target" ];
          serviceConfig.Type = "oneshot";
          script = "exit 1";
        };
      };
    };
    testScript = { nodes, ... }:
      let
        original = nodes.machine.system.build.toplevel;
        bad = nodes.machine.specialisation.bad.configuration.system.build.toplevel;
      in
      (import "${lanzaboote}/nix/tests/lanzaboote/common/image-helper.nix" {
        inherit (nodes) machine;
      }) + ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        assert machine.succeed("readlink -f /run/current-system").strip() == "${bad}"
        machine.shutdown()

        machine.start()
        machine.wait_for_unit("multi-user.target")
        assert machine.succeed("readlink -f /run/current-system").strip() == "${original}"
        machine.wait_for_unit("systemd-bless-boot.service")
        machine.shutdown()
      '';
  };
in
{ inherit test; }
```

If the upstream common module cannot be imported as a module closure, copy only its image construction into this file and retain the pinned fixture paths under `${lanzaboote}/nix/tests/fixtures/uefi-keys`.

- [x] **Step 4: Lock and run the focused check**

Run:

```fish
nix flake update lanzaboote
nix build -L .#checks.x86_64-linux.vm-boot-counting
```

Expected: PASS, first boot is the one-attempt bad candidate and second boot is the original generation.

- [x] **Step 5: Commit**

```fish
git add flake.nix flake.lock nix/reliability/vm-boot-counting.nix
git commit -m "harness: prove boot-counted fallback"
```

### Task 2: Add closed graphics and machine-profile models

**Files:**
- Create: `src/intentd/machine.py`
- Create: `tests/test_machine.py`
- Modify: `src/intentd/schema.py:26-42`
- Modify: `src/intentd/registry.py:8-93`
- Modify: `src/intentd/state.py:11-35`
- Test: `tests/test_schema.py`, `tests/test_registry.py`, `tests/test_state.py`

- [x] **Step 1: Write failing model and state tests**

Add tests that establish the closed contract:

```python
def test_graphics_profile_params_are_closed() -> None:
    with pytest.raises(pydantic.ValidationError):
        GraphicsProfileParams.model_validate(
            {"profile": "integrated", "kernel_parameter": "init=/bin/sh"}
        )


def test_graphics_profile_is_boot_affecting() -> None:
    cap = REGISTRY["hardware.graphics.profile"]
    assert cap.boot_affecting is True
    assert cap.params_model is GraphicsProfileParams


def test_graphics_profile_replaces_only_graphics_state() -> None:
    before = DesiredState(apps=("firefox",), graphics_profile=GraphicsProfile.INTEGRATED)
    invocation = resolve_invocation(
        {}, "hardware.graphics.profile", {"profile": "hybrid-nvidia"}
    )
    assert apply_invocation(before, invocation) == DesiredState(
        apps=("firefox",), graphics_profile=GraphicsProfile.HYBRID_NVIDIA
    )
```

In `tests/test_machine.py`, cover root-owned JSON loading, unknown keys, unsupported profile IDs, wrong PCI addresses, and a test profile marked certified.

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_machine.py tests/test_schema.py tests/test_registry.py tests/test_state.py -q`

Expected: FAIL because the graphics and machine-profile types do not exist.

- [x] **Step 3: Implement the closed types**

Create `src/intentd/machine.py` with these public models:

```python
from enum import StrEnum
from pathlib import Path

from intentd.schema import ClosedModel


class GraphicsProfile(StrEnum):
    INTEGRATED = "integrated"
    HYBRID_NVIDIA = "hybrid-nvidia"


class GraphicsBackend(StrEnum):
    INTENTD_VM = "intentd-vm"
    UX3404VC = "ux3404vc"


class MachineProfile(ClosedModel):
    profile_id: str
    certified: bool
    graphics_backend: GraphicsBackend
    intel_pci: str
    nvidia_pci: str | None
    critical_units: tuple[str, ...]
    display_unit: str
    root_reserve_bytes: int
    esp_reserve_bytes: int


def load_machine_profile(path: Path) -> MachineProfile:
    profile = MachineProfile.model_validate_json(path.read_bytes())
    if not profile.certified:
        raise ValueError(f"machine profile {profile.profile_id!r} is not certified")
    return profile
```

In `src/intentd/schema.py`, add `GraphicsProfileParams(profile: GraphicsProfile)` and `boot_affecting: bool = False` to `CapabilityDef`. Register `hardware.graphics.profile` as reversible and boot-affecting. Add `graphics_profile: GraphicsProfile | None = None` to `DesiredState` and handle the invocation without changing `apps`.

- [x] **Step 4: Run focused tests**

Run: `nix develop -c uv run pytest tests/test_machine.py tests/test_schema.py tests/test_registry.py tests/test_state.py -q`

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/machine.py src/intentd/schema.py src/intentd/registry.py src/intentd/state.py tests/test_machine.py tests/test_schema.py tests/test_registry.py tests/test_state.py
git commit -m "feat: define boot-affecting graphics state"
```

### Task 3: Render and authorize the graphics capability

**Files:**
- Modify: `src/intentd/render.py:1-48`
- Modify: `src/intentd/policy.py:20-69`
- Modify: `src/intentd/orchestrator.py:64-109`
- Modify: `src/intentd/wiring.py:72-90`
- Test: `tests/test_render.py`, `tests/test_policy.py`, `tests/test_orchestrator.py`, `tests/test_wiring.py`

- [x] **Step 1: Write failing render and policy tests**

Cover all policy bindings and exact output:

```python
def test_graphics_policy_requires_certified_matching_machine() -> None:
    vm_profile = MachineProfile(
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
    invocation = resolve_invocation(
        {}, "hardware.graphics.profile", {"profile": "hybrid-nvidia"}
    )
    previous = DesiredState(graphics_profile=GraphicsProfile.INTEGRATED)
    desired = DesiredState(graphics_profile=GraphicsProfile.HYBRID_NVIDIA)
    assert evaluate(invocation, {}, previous, desired, machine_profile=None).verdict is PolicyVerdict.REJECT
    assert (
        evaluate(invocation, {}, previous, desired, machine_profile=vm_profile).verdict
        is PolicyVerdict.AUTO_APPLY
    )


def test_hybrid_profile_render_is_closed() -> None:
    vm_profile = MachineProfile(
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
    rendered = render(
        DesiredState(graphics_profile=GraphicsProfile.HYBRID_NVIDIA), {}, vm_profile
    )
    assert "hardware.nvidia.prime.offload.enable = true;" in rendered
    assert "hardware.nvidia.prime.intelBusId = \"PCI:0:2:0\";" in rendered
    assert "hardware.nvidia.prime.nvidiaBusId = \"PCI:1:0:0\";" in rendered
```

Also prove that invocation params cannot affect bus IDs, package names, driver names, kernel parameters, or arbitrary Nix text.

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_render.py tests/test_policy.py tests/test_orchestrator.py tests/test_wiring.py -q`

Expected: FAIL because render and policy do not accept machine profiles.

- [x] **Step 3: Implement deterministic policy and rendering**

Change the public signatures so `render` requires `machine_profile: MachineProfile | None` as its third positional argument and `evaluate` requires the same type as a keyword-only argument. Keep every existing parameter and return type unchanged. Update every call site in the same commit so there is no compatibility wrapper.

For graphics, require a certified profile, exact state recomputation, backend membership in `{"intentd-vm", "ux3404vc"}`, Intel PCI `0000:00:02.0`, and NVIDIA PCI `0000:01:00.0` for hybrid mode. Keep the physical `ux3404vc` profile absent from repository configuration until milestone 4; only the test profile is accepted in milestone 2 integration.

Update `Deps` with `machine_profile: MachineProfile`, thread it through every render and policy call, and load it from `/etc/intentd/machine-profile.json` in `production_deps`.

- [x] **Step 4: Run focused and full fast tests**

Run:

```fish
nix develop -c uv run pytest tests/test_render.py tests/test_policy.py tests/test_orchestrator.py tests/test_wiring.py -q
nix develop -c uv run pytest -q
```

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/render.py src/intentd/policy.py src/intentd/orchestrator.py src/intentd/wiring.py tests/test_render.py tests/test_policy.py tests/test_orchestrator.py tests/test_wiring.py
git commit -m "feat: authorize certified graphics profiles"
```

### Task 4: Define boot plans, observations, and health outcomes

**Files:**
- Create: `src/intentd/boot.py`
- Create: `tests/test_boot.py`
- Modify: `src/intentd/health.py`
- Modify: `tests/test_health.py`

- [x] **Step 1: Write failing closed-model and health tests**

Use fixed 64-character lowercase hashes and cover:

```python
def test_parse_bootctl_selects_exactly_one_current_entry() -> None:
    raw = json.dumps([
        {"id": "old.efi", "path": "/boot/EFI/Linux/old.efi", "isSelected": False},
        {"id": "new.efi", "path": "/boot/EFI/Linux/new+0-1.efi", "isSelected": True},
    ])
    assert parse_bootctl_list(raw).entry_id == "new.efi"


def test_health_rejects_identity_mismatch() -> None:
    observation = BootObservation(
        closure_path="/nix/store/candidate",
        entry_id="candidate.efi",
        entry_path="/boot/EFI/Linux/candidate.efi",
    )
    current = HealthSnapshot(
        failed_units=(),
        inactive_critical_units=(),
        display_ready=True,
        root_free_bytes=536_870_912,
    )
    decision = evaluate_boot_health(
        plan=boot_plan_fixture(),
        observation=observation.model_copy(update={"closure_path": "/nix/store/wrong"}),
        current=current,
    )
    assert decision.healthy is False
    assert decision.failures == ("booted closure does not match candidate",)


def test_network_and_model_are_not_health_inputs() -> None:
    assert "network" not in HealthSnapshot.model_fields
    assert "model" not in HealthSnapshot.model_fields
```

Also test duplicate selected entries, no selected entry, malformed bootctl JSON, UKI hash mismatch, missing prior/recovery artifacts, new failed units, missing critical units, display failure, root reserve regression, and healthy exact matches.

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_boot.py tests/test_health.py -q`

Expected: FAIL because the boot models do not exist.

- [x] **Step 3: Implement focused boot models**

Create these closed models in `src/intentd/boot.py`:

```python
class BootArtifact(ClosedModel):
    closure_path: str
    entry_id: str
    uki_path: str
    uki_sha256: str
    uki_size_bytes: int
    gc_root: str


class HealthSnapshot(ClosedModel):
    failed_units: tuple[str, ...]
    inactive_critical_units: tuple[str, ...]
    display_ready: bool
    root_free_bytes: int
    esp_free_bytes: int


class BootPlan(ClosedModel):
    candidate: BootArtifact
    prior_blessed: BootArtifact
    recovery: BootArtifact
    baseline: HealthSnapshot
    machine_profile_id: str
    root_reserve_bytes: int
    esp_reserve_bytes: int
    rendered_hash: str
    flake_lock_hash: str


class BootObservation(ClosedModel):
    closure_path: str
    entry_id: str
    entry_path: str


class BootOutcome(ClosedModel):
    healthy: bool
    recovered: bool
    quarantined: bool
    observation: BootObservation
    health: HealthSnapshot
    failures: tuple[str, ...]


class BootStagingPhase(StrEnum):
    SET_PROFILE = "set-profile"
    INSTALL_CANDIDATE = "install-candidate"


class BootStagingFailure(ClosedModel):
    candidate: BootArtifact
    phase: BootStagingPhase
    detail: str
    quarantined: Literal[True] = True
```

Implement `parse_bootctl_list`, `observe_boot`, `verify_artifact`, `capture_health`, and `evaluate_boot_health`. Use `bootctl list --json=short`, the single `isSelected` entry, `/run/current-system`, `sha256` of the selected UKI, `systemctl is-active` for configured critical/display units, and `statvfs` for root free bytes. Because systemd-boot renames counted entries as attempts are consumed and when they are blessed, authenticate the canonical entry ID and permit only its valid `+tries` or `+tries-done` suffix under `/boot/EFI/Linux`; verify size and hash against the selected observed path rather than a stale pre-reboot filename. Every subprocess gets an explicit timeout of at most 10 seconds; the service-level total timeout is added in Task 9.

Capture ESP free space from `/boot`, authenticate exact UKI sizes, and evaluate
root and ESP capacity against the positive reserve thresholds carried by the
boot plan. Do not compare post-install ESP free space with the raw pre-install
baseline because the candidate UKI itself consumes ESP capacity.

Define `boot_plan_fixture()` locally in `tests/test_boot.py`; it must return a complete `BootPlan` whose candidate closure is `/nix/store/candidate`, prior closure is `/nix/store/blessed`, recovery closure is `/nix/store/recovery`, hashes are 64 lowercase hexadecimal characters, baseline has no failures, and all artifact paths are under `/boot/EFI/Linux` or `/var/lib/intentd/gcroots`.

- [x] **Step 4: Run focused tests**

Run: `nix develop -c uv run pytest tests/test_boot.py tests/test_health.py -q`

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/boot.py src/intentd/health.py tests/test_boot.py tests/test_health.py
git commit -m "feat: model deterministic boot health"
```

### Task 5: Authenticate boot plans and outcomes in transaction transitions

**Files:**
- Modify: `src/intentd/txn.py:38-49`
- Modify: `src/intentd/projection.py:18-225`
- Modify: `src/intentd/store.py`
- Modify: `tests/test_projection.py`
- Modify: `tests/test_store.py`

- [x] **Step 1: Write failing replay invariant tests**

Add tests for these rules:

```python
def test_boot_affecting_pending_requires_boot_plan(tmp_path: Path) -> None:
    store, txn = built_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="boot plan"):
        store.transition(txn, TxnStatus.PENDING)


def test_non_boot_pending_rejects_boot_plan(tmp_path: Path) -> None:
    store, txn = built_app_transaction(tmp_path)
    with pytest.raises(TransitionError, match="non-boot transaction"):
        store.transition(txn, TxnStatus.PENDING, boot_plan=boot_plan_fixture())


def test_boot_bless_requires_healthy_outcome(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="healthy boot outcome"):
        store.transition(txn, TxnStatus.BLESSED, boot_outcome=failed_outcome_fixture())


def test_existing_blessed_boot_requires_one_exact_anchor(tmp_path: Path) -> None:
    store, blessed = blessed_app_transaction(tmp_path)
    artifact = boot_artifact_fixture(closure_path=store.get(blessed).closure_path)
    store.anchor_blessed_boot(blessed, artifact)
    assert store.get(blessed).boot_artifact == artifact
    with pytest.raises(TransitionError, match="already anchored"):
        store.anchor_blessed_boot(blessed, artifact)
```

Replay must also reject a boot plan whose candidate closure, rendered hash, flake-lock hash, or machine profile differs from already authenticated transaction fields. `transaction.boot-anchored` is accepted exactly once, only for the current blessed transaction, only with an artifact whose closure equals that transaction's authenticated closure, and only while no transaction is in flight. `ABORTED` for a boot transaction must carry a failed, quarantined outcome. Exact reconstruction must include boot JSON columns.

Add `boot_artifact_fixture`, `boot_plan_fixture`, `failed_outcome_fixture`, `built_graphics_transaction`, `built_app_transaction`, `blessed_app_transaction`, and `pending_graphics_transaction` to `tests/helpers.py`. Each helper must construct state through the public `TransactionStore` API; none may write journal or SQLite bytes directly.

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_projection.py tests/test_store.py -q`

Expected: FAIL because transition payloads cannot carry boot evidence.

- [x] **Step 3: Extend the transaction and projection schema**

Add to `TransactionRecord`:

```python
boot_artifact: BootArtifact | None = None
boot_plan: BootPlan | None = None
boot_outcome: BootOutcome | None = None
```

Add `boot_artifact TEXT`, `boot_plan TEXT`, and `boot_outcome TEXT` columns to `_SCHEMA`. Add a closed `_BootAnchorEvent` carrying `status=blessed` and `artifact`. Extend `_TransitionEvent` with the plan and outcome models. Change `TransactionStore.transition` to accept keyword-only `boot_plan` and `boot_outcome`, serialize them into the authenticated transition payload, and enforce the rules from Step 1 both before append and during replay. Add `TransactionStore.anchor_blessed_boot`, backed by the authenticated `transaction.boot-anchored` event. When a boot transaction becomes blessed, projection sets `boot_artifact` from its authenticated candidate artifact.

Do not create a second mutable boot-state file. SQLite remains a projection and all authoritative boot evidence stays inside transition or boot-anchor journal records.

- [x] **Step 4: Run focused and reconstruction tests**

Run:

```fish
nix develop -c uv run pytest tests/test_projection.py tests/test_store.py -q
nix develop -c uv run pytest tests/test_store.py -k reconstructs_all_rows -q
```

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/txn.py src/intentd/projection.py src/intentd/store.py tests/test_projection.py tests/test_store.py
git commit -m "feat: authenticate boot transaction evidence"
```

### Task 6: Add constrained boot executor primitives and artifact retention

**Files:**
- Modify: `src/intentd/executor.py:1-88`
- Create: `tests/test_boot_executor.py`
- Modify: `tests/test_executor.py`

- [x] **Step 1: Write failing argv and validation tests**

Cover only fixed commands with validated store paths and boot entry IDs:

```python
def test_install_boot_candidate_argv() -> None:
    assert install_boot_candidate_argv("/nix/store/abc-system") == [
        "/nix/store/abc-system/bin/switch-to-configuration",
        "boot",
    ]


def test_gc_root_rejects_escape() -> None:
    with pytest.raises(ExecError):
        retain_artifact_argv("/nix/store/abc", Path("/var/lib/intentd/gcroots/../escape"))


def test_set_oneshot_rejects_option_like_entry() -> None:
    with pytest.raises(ExecError):
        set_oneshot_argv("--help")
```

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_boot_executor.py tests/test_executor.py -q`

Expected: FAIL because the boot primitives do not exist.

- [x] **Step 3: Implement the fixed primitives**

Add:

```python
def install_boot_candidate_argv(closure: str) -> list[str]:
    return [f"{_require_store_path(closure)}/bin/switch-to-configuration", "boot"]


def retain_artifact_argv(closure: str, root: Path) -> list[str]:
    expected = Path("/var/lib/intentd/gcroots")
    if root.parent != expected or root.name not in {"blessed", "recovery"}:
        raise ExecError("GC root is outside the intentd retention directory")
    return ["nix-store", "--add-root", str(root), "--indirect", "--realise", _require_store_path(closure)]


def set_oneshot_argv(entry_id: str) -> list[str]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+@-]{0,254}", entry_id):
        raise ExecError("invalid boot entry ID")
    return ["bootctl", "set-oneshot", entry_id]
```

Add wrappers for candidate installation, artifact retention, `bootctl set-default`, `bootctl set-oneshot`, `systemd-bless-boot bad`, and `systemctl reboot`. Both boot selection wrappers enforce the same closed entry ID grammar. No wrapper accepts arbitrary commands or shell text.

- [x] **Step 4: Run focused tests**

Run: `nix develop -c uv run pytest tests/test_boot_executor.py tests/test_executor.py -q`

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/executor.py tests/test_boot_executor.py tests/test_executor.py
git commit -m "feat: constrain boot executor primitives"
```

### Task 7: Split live activation from boot staging in the orchestrator

**Files:**
- Modify: `src/intentd/orchestrator.py:20-152`
- Modify: `src/intentd/wiring.py:45-99`
- Modify: `src/intentd/cli.py`
- Modify: `tests/test_orchestrator.py`
- Modify: `tests/test_wiring.py`
- Modify: `tests/test_cli.py`

- [x] **Step 1: Write failing boot-staging tests**

Use fakes to prove exact ordering:

```python
def test_boot_affecting_apply_stages_and_returns_pending() -> None:
    invocation = resolve_invocation(
        {}, "hardware.graphics.profile", {"profile": "integrated"}
    )
    result = apply_intent(deps, invocation)
    assert result.record is not None
    assert result.record.status is TxnStatus.PENDING
    assert calls == [
        "capture-baseline",
        "inspect-candidate",
        "verify-blessed-anchor",
        "verify-recovery",
        "retain-blessed",
        "retain-recovery",
        "journal-pending",
        "set-profile",
        "install-boot-candidate",
        "reboot",
    ]
```

Add negative tests proving that missing recovery, missing blessed boot anchor, insufficient root or ESP reserve, UKI mismatch, boot installation failure, or journal append failure prevents reboot. ESP staging requires `baseline.esp_free_bytes >= machine_profile.esp_reserve_bytes + candidate.uki_size_bytes`. Existing application transactions must preserve their live activation path.

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_orchestrator.py tests/test_wiring.py tests/test_cli.py -q`

Expected: FAIL because `Deps` lacks boot staging functions.

- [x] **Step 3: Add explicit boot dependencies and branch**

Extend `Deps` with typed callables:

```python
capture_health: Callable[[], HealthSnapshot]
inspect_candidate: Callable[[str], BootArtifact]
verify_artifact: Callable[[BootArtifact], None]
retain_artifact: Callable[[BootArtifact, Literal["blessed", "recovery"]], None]
recovery_artifact: Callable[[], BootArtifact]
install_boot_candidate: Callable[[str], None]
reboot: Callable[[], None]
```

Extract `_apply_live_candidate` and `_stage_boot_candidate`. `_stage_boot_candidate` constructs and verifies the complete `BootPlan`, including the certified root and ESP reserves, and checks:

```python
if baseline.root_free_bytes < deps.machine_profile.root_reserve_bytes:
    raise BootStagingError("root free space is below the certified reserve")
if baseline.esp_free_bytes < (
    deps.machine_profile.esp_reserve_bytes + candidate.uki_size_bytes
):
    raise BootStagingError("ESP free space cannot retain the reserve after installation")
```

It appends `PENDING` with that plan before changing profile or boot preference,
installs the boot entry, then requests reboot. It returns the authenticated
pending record. If setting the profile or installing the candidate fails after
pending, append `ABORTED` with `BootStagingFailure` for the exact authenticated
candidate and phase before returning. Do not request reboot after either
failure. If the reboot call itself fails, leave the transaction pending because
the authenticated plan and installed candidate already agree.

Update CLI JSON and text output so a boot-affecting request reports `outcome: "pending-reboot"` and never claims blessing before reboot.

- [x] **Step 4: Run focused and full tests**

Run:

```fish
nix develop -c uv run pytest tests/test_orchestrator.py tests/test_wiring.py tests/test_cli.py -q
nix develop -c uv run pytest -q
```

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/orchestrator.py src/intentd/wiring.py src/intentd/cli.py tests/test_orchestrator.py tests/test_wiring.py tests/test_cli.py
git commit -m "feat: stage boot-affecting transactions"
```

### Task 8: Implement model-free boot reconciliation

**Files:**
- Create: `src/intentd/boot_guard.py`
- Create: `tests/test_boot_guard.py`
- Modify: `pyproject.toml:11-12`

- [x] **Step 1: Write failing reconciliation table tests**

Parameterize these cases:

| Authenticated state | Boot observation | Required result |
| --- | --- | --- |
| pending boot plan | matching candidate, healthy | bless and release boot completion |
| pending boot plan | matching candidate, unhealthy | abort, quarantine, mark bad, reboot |
| pending boot plan | matching prior blessed | abort as recovered, active returns to blessed |
| pending boot plan | matching recovery | abort as recovered, active returns to blessed |
| no pending | matching blessed | no mutation, release boot completion |
| any state | unknown closure or entry | fail closed, select recovery once, reboot |
| invalid journal | any observation | fail closed without blessing |

The healthy test must assert that the journal transition to `BLESSED` happens before `release_boot_complete`. The unhealthy test must assert that `ABORTED` is durable before `mark_bad` and `reboot`.

- [x] **Step 2: Run tests to verify failure**

Run: `nix develop -c uv run pytest tests/test_boot_guard.py -q`

Expected: FAIL because `boot_guard` does not exist.

- [x] **Step 3: Implement a dependency-injected reconciler**

Use this public shape:

```python
@dataclass(frozen=True)
class BootGuardDeps:
    store: TransactionStore
    observe_boot: Callable[[], BootObservation]
    capture_health: Callable[[], HealthSnapshot]
    verify_artifact: Callable[[BootArtifact], None]
    mark_bad: Callable[[], None]
    select_recovery: Callable[[str], None]
    reboot: Callable[[], None]


class BootGuardResult(StrEnum):
    HEALTHY = "healthy"
    RECOVERED = "recovered"
    REBOOTING = "rebooting"
```

Implement `reconcile_boot(deps: BootGuardDeps) -> BootGuardResult` as an explicit branch table matching Step 1. Each branch must validate the observed closure and canonical entry ID together before any transition, accept only valid systemd boot-count renames of that entry path, and verify the UKI bytes at the observed path. The healthy branch appends `BLESSED`; the candidate-failure branch appends `ABORTED`, verifies and selects the authenticated prior blessed entry, calls `mark_bad`, then reboots. Its outcome remains quarantined but not recovered because the abort is already durable before the reboot. The prior-blessed and recovery branches append recovered `ABORTED`; the no-pending branch requires the observed closure and entry to match `blessed.boot_artifact`; the unknown branch selects the authenticated recovery entry and reboots without blessing.

The process entrypoint loads only the journal credential, store, machine profile, and boot primitives. It does not import resolver code, invoke the model, read network state, or accept free-form commands. Register it as:

```toml
[project.scripts]
intent = "intentd.cli:main"
intentd-boot-guard = "intentd.boot_guard:main"
```

Return zero after a healthy boot, a recovered boot, or a successfully requested recovery reboot. During real shutdown, systemd may terminate the oneshot before it returns and apply `FailureAction=reboot-force`; that reinforces the already requested reboot rather than authorizing a second state transition. Invalid authenticated state and failed reboot requests remain nonzero.

- [x] **Step 4: Run focused tests and import check**

Run:

```fish
nix develop -c uv run pytest tests/test_boot_guard.py -q
nix develop -c uv run python -c 'import intentd.boot_guard'
```

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/boot_guard.py tests/test_boot_guard.py pyproject.toml
git commit -m "feat: reconcile authenticated boot state"
```

### Task 9: Wire the boot guard, watchdog, and fixed recovery artifact

**Files:**
- Create: `nix/reliability/module.nix`
- Create: `nix/reliability/recovery.nix`
- Create: `tests/test_reliability_module.py`
- Modify: `flake.nix`

- [x] **Step 1: Write failing Nix evaluation tests**

Add a `nix_eval` test that evaluates a system importing the module and asserts:

```python
assert config["systemd"]["services"]["intentd-boot-guard"]["before"] == [
    "boot-complete.target"
]
assert config["systemd"]["services"]["intentd-boot-guard"]["requiredBy"] == [
    "boot-complete.target"
]
assert service_config["Type"] == "oneshot"
assert service_config["TimeoutStartSec"] == "60s"
assert service_config["FailureAction"] == "reboot-force"
assert service_config["LoadCredential"].startswith("intentd-journal-key:")
```

Also assert `boot.lanzaboote.bootCounting.initialTries == 1`, bootloader editor disabled, recovery closure and entry options required, `systemd.settings.Manager.RuntimeWatchdogSec == "30s"`, and no network-online dependency.

- [x] **Step 2: Run the focused eval to verify failure**

Run: `nix develop -c uv run pytest -q -o addopts='' tests/test_reliability_module.py -m nix_eval`

Expected: FAIL because the module does not exist.

- [x] **Step 3: Implement the NixOS module and recovery configuration**

Expose `nixosModules.reliability` from `flake.nix`. `nix/reliability/module.nix` must define closed options under `services.intentd.reliability` for `enable`, `stateDir`, `machineProfile`, `journalCredential`, `recoveryClosure`, and `recoveryEntryId`.

Wire the guard as:

```nix
systemd.services.intentd-boot-guard = {
  description = "Authenticate, assess, and reconcile the current intentd boot";
  requiredBy = [ "boot-complete.target" ];
  before = [ "boot-complete.target" ];
  after = [ "local-fs.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${intentdPackage}/bin/intentd-boot-guard";
    TimeoutStartSec = "60s";
    FailureAction = "reboot-force";
    LoadCredential = "intentd-journal-key:${cfg.journalCredential}";
  };
  environment = {
    INTENTD_STATE_DIR = cfg.stateDir;
    INTENTD_MACHINE_PROFILE = cfg.machineProfile;
    INTENTD_RECOVERY_CLOSURE = cfg.recoveryClosure;
    INTENTD_RECOVERY_ENTRY_ID = cfg.recoveryEntryId;
  };
};
```

`recovery.nix` builds a separate minimal closure with storage support, systemd-boot tools, intentd journal inspection, and a marker unit. It must not include the resolver, network-online dependencies, a general command runner, or a login-enabled shell account. The VM installs its signed UKI with boot counting disabled and a stable `intentd-recovery` sort key.

- [x] **Step 4: Run focused eval and formatting**

Run:

```fish
nix develop -c uv run pytest -q -o addopts='' tests/test_reliability_module.py -m nix_eval
nixfmt --check nix/reliability/module.nix nix/reliability/recovery.nix flake.nix
```

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add nix/reliability/module.nix nix/reliability/recovery.nix tests/test_reliability_module.py flake.nix
git commit -m "feat: wire boot reliability services"
```

### Task 10: Build the end-to-end persistent boot VM

**Files:**
- Create: `nix/reliability/vm-boot.nix`
- Create: `nix/reliability/vm-driver.py`
- Modify: `flake.nix`

- [x] **Step 1: Register the missing full VM check**

Add:

```nix
checks.x86_64-linux.vm-boot =
  (import ./nix/reliability/vm-boot.nix {
    inherit self nixpkgs lanzaboote;
  }).test;
```

- [x] **Step 2: Verify the missing file fails evaluation**

Run: `nix flake check --no-build`

Expected: FAIL because `nix/reliability/vm-boot.nix` does not exist.

- [x] **Step 3: Create the persistent image and driver**

Reuse the pinned Lanzaboote image construction, with these differences:

- persistent ext4 root containing `/var/lib/intentd` and Nix profiles;
- fixed journal test credential installed mode `0600`;
- fixed certified VM machine profile JSON;
- separately built and signed recovery UKI with zero tries;
- one-attempt candidate UKIs with transaction-unique candidate GC roots;
- `mountHostNixStore = false`, empty substituters, and no model credential;
- `intentd-display-ready.service` as the simulated display evidence;
- candidate generation markers under `/etc/intentd-generation`.

The VM machine profile fixes `root_reserve_bytes = 268435456` and
`esp_reserve_bytes = 134217728`. Candidate inspection records the exact UKI
byte size in `BootArtifact.uki_size_bytes`. Before staging, the driver asserts
that root capacity meets its reserve and ESP free capacity is at least the ESP
reserve plus the candidate UKI size.

`nix/reliability/vm-driver.py` constructs the real transaction and boot plan through production store/orchestrator APIs, while accepting only enumerated scenario verbs: `seed-blessed`, `stage-integrated`, `stage-hybrid`, `stage-unhealthy`, `stage-powerloss`, `status`, and `journal`. `seed-blessed` creates the initial ordinary blessed transaction, observes the current closure, loader entry, and UKI, then calls `anchor_blessed_boot` before returning. `stage-unhealthy` selects a prebuilt candidate whose display evidence is deterministically inactive. `stage-powerloss` selects a prebuilt candidate whose test-only barrier is encoded in its NixOS configuration. The driver must not expose an arbitrary command argument.

For deterministic test-driver control, inject a VM-only reboot callback that atomically creates `/run/intentd-reboot-requested` instead of rebooting QEMU. Unit tests prove that production wiring calls `systemctl reboot --no-block` and invokes the absolute `systemd-bless-boot` helper path available in the service environment. Each VM stage assertion must verify the marker, remove it, call the test driver's `machine.reboot()`, and then wait for the boot ID to change. This avoids treating an expected backdoor disconnect as a command failure.

The VM imports the recovery configuration as a specialisation to avoid recursive NixOS evaluation. Its module option uses a syntactically valid placeholder closure, while the driver authenticates and stages the actual prebuilt recovery closure and signed entry. Production hosts must configure the real recovery closure directly.

- [x] **Step 4: Prove healthy reboot and blessing**

The first subtest must:

```python
machine.start(allow_reboot=True)
machine.wait_for_unit("multi-user.target")
seed = run_driver("seed-blessed")
candidate = run_driver("stage-integrated")
machine.succeed("test -e /run/intentd-reboot-requested")
machine.succeed("rm /run/intentd-reboot-requested")
old_boot_id = machine.succeed("cat /proc/sys/kernel/random/boot_id").strip()
machine.reboot()
machine.wait_until_succeeds(
    f'test "$(cat /proc/sys/kernel/random/boot_id)" != "{old_boot_id}"'
)
machine.wait_for_unit("boot-complete.target")
status = run_driver("status")
assert status["blessed_txn"] == candidate["txn"]
assert status["active_txn"] == candidate["txn"]
assert status["boot_outcome"]["healthy"] is True
assert machine.succeed("bootctl list --json=short")
assert status["boot_outcome"]["health"]["root_free_bytes"] >= 268_435_456
assert status["boot_outcome"]["health"]["esp_free_bytes"] >= 134_217_728
```

Repeat with `stage-hybrid` and assert the candidate entry loses its counter after `systemd-bless-boot.service` succeeds.

- [x] **Step 5: Prove failed health falls back by attempt two**

Stage a candidate whose simulated display unit fails. On candidate boot, wait for the guard failure and automatic reboot. After reconnection, assert:

```python
assert boot_attempts == 2
assert booted_closure == prior_blessed_closure
assert status["active_txn"] == status["blessed_txn"]
assert failed["status"] == "aborted"
assert failed["boot_outcome"]["quarantined"] is True
assert failed["boot_outcome"]["recovered"] is False
```

- [x] **Step 6: Run the focused VM check**

Run: `nix build -L .#checks.x86_64-linux.vm-boot`

Expected: PASS for integrated blessing, hybrid blessing, and health-failure fallback.

The fallback boot can be an uncounted prior entry, so the guard is also wanted by `multi-user.target`. `boot-complete.target` remains required behind the same guard for counted candidate boots.

- [x] **Step 7: Commit**

```fish
git add nix/reliability/vm-boot.nix nix/reliability/vm-driver.py flake.nix
git commit -m "test: prove authenticated boot recovery"
```

### Task 11: Add sudden-power-loss replay proof

**Files:**
- Modify: `nix/reliability/vm-boot.nix`
- Modify: `nix/reliability/vm-driver.py`
- Modify: `src/intentd/executor.py`
- Modify: `src/intentd/orchestrator.py`
- Modify: `src/intentd/wiring.py`
- Modify: `tests/test_boot_executor.py`
- Modify: `tests/test_boot_guard.py`
- Modify: `tests/test_orchestrator.py`

- [x] **Step 1: Add the failing power-loss subtest**

Stage the prebuilt `stage-powerloss` one-attempt candidate. Candidate installation must set the authenticated prior blessed entry as the persistent default before setting the counted candidate as oneshot. In that candidate's VM-only NixOS configuration, `intentd-test-boot-barrier.service` is required before the boot guard and runs `sleep 300`. Reboot into the candidate, wait until the barrier reports `ActiveState=activating`, and call the NixOS test driver's `machine.crash()` before `boot-complete.target` can be reached. Restart the same image; systemd-boot must skip the exhausted candidate and select the exact authenticated prior entry, whose configuration has no barrier. The production module and Python package must contain no barrier or fault-file branch.

Assert all of these facts:

```python
assert first_entry_id == pending["boot_plan"]["candidate"]["entry_id"]
assert recovered_entry_id == pending["boot_plan"]["prior_blessed"]["entry_id"]
assert recovered_closure == pending["boot_plan"]["prior_blessed"]["closure_path"]
assert status["active_txn"] == status["blessed_txn"]
assert status["pending_txn"] is None
assert status["failed_txn"]["boot_outcome"]["recovered"] is True
assert status["failed_txn"]["boot_outcome"]["quarantined"] is True
```

- [x] **Step 2: Run the VM check and observe failure**

Run: `nix build -L .#checks.x86_64-linux.vm-boot`

Expected: FAIL until boot guard reconciliation recognizes the prior blessed boot after an interrupted pending candidate.

- [x] **Step 3: Implement the minimal recovery reconciliation fix**

Adjust `reconcile_boot` only if the unit test and VM evidence show a missing case. The accepted rule is exact: when an authenticated pending plan exists and the observed closure plus entry match `plan.prior_blessed`, capture the current observation and health snapshot, then append an `ABORTED` transition with `healthy=False`, `recovered=True`, `quarantined=True`, and `failures=("candidate interrupted before blessing",)`. This restores the active pointer to blessed. Do not bless or retry the interrupted candidate. If VM evidence instead shows a closure match under a different entry ID, preserve the strict identity check and correct staging so `bootctl set-default` names the authenticated prior entry before `bootctl set-oneshot` names the candidate.

- [x] **Step 4: Run focused and VM tests**

Run:

```fish
nix develop -c uv run pytest tests/test_boot_guard.py -q
nix build -L .#checks.x86_64-linux.vm-boot
```

Expected: PASS.

- [x] **Step 5: Commit**

```fish
git add src/intentd/boot_guard.py tests/test_boot_guard.py nix/reliability/vm-boot.nix nix/reliability/vm-driver.py
git commit -m "test: prove power-loss boot fallback"
```

### Task 12: Close the milestone with documentation and full verification

**Files:**
- Modify: `docs/host-setup.md`
- Modify: `handoff.md`

- [x] **Step 1: Document the exact deployment contract**

Update `docs/host-setup.md` with:

- the `services.intentd.reliability` module options;
- journal and machine-profile credential ownership;
- Secure Boot and Lanzaboote 1.1.0 prerequisites;
- the fixed recovery closure and entry requirements;
- required ESP and root reserve checks;
- boot guard ordering and 60-second health deadline;
- the explicit statement that TPM2 monotonic rollback protection and physical-machine activation are not milestone 2 claims.

- [x] **Step 2: Update the handoff**

Record every milestone commit, exact test result, VM closure and entry evidence, and these next limits:

- remaining Stage 2 injected-failure matrix;
- constrained recovery console actions;
- TPM2-bound checkpoint;
- UX3404VC bill of materials, firmware baseline, and physical recovery run;
- real-host privileged service and credential provisioning.

- [x] **Step 3: Run the complete fast gate**

Run:

```fish
nix develop -c uv run pytest -q
nix develop -c uv run ruff check .
nix develop -c uv run ruff format --check .
nix develop -c pyright
nix develop -c uv run python -m py_compile nix/reliability/vm-driver.py
git ls-files '*.nix' ':!tests/golden/**' | xargs nixfmt --check
```

Expected: all commands exit 0.

- [x] **Step 4: Run opt-in and flake gates with captured exit codes**

Run:

```fish
nix develop -c uv run pytest -q -o addopts='' -m nix_eval
nix develop -c uv run pytest -q -o addopts='' -m claude_live
nix flake check -L > /tmp/intentd-stage2-boot-flake-check.log 2>&1
set rc $status
tail -120 /tmp/intentd-stage2-boot-flake-check.log
echo EXIT_CODE=$rc
test $rc -eq 0
```

Expected: all commands exit 0 and the flake log ends with `all checks passed!`.

- [x] **Step 5: Commit**

```fish
git add docs/host-setup.md handoff.md
git commit -m "docs: close boot reliability milestone"
```

## Acceptance checklist

- [x] A boot-affecting transaction cannot enter pending without authenticated candidate, prior blessed, recovery, health-baseline, machine-profile, render, and lock bindings.
- [x] The pre-existing blessed transaction receives exactly one authenticated closure, entry, and UKI anchor before boot staging is enabled.
- [x] A non-boot transaction cannot smuggle boot metadata into its journal transition.
- [x] The boot guard contains no resolver, model, network, arbitrary shell, or free-form command dependency.
- [x] `boot-complete.target` is unreachable until the authenticated guard succeeds.
- [x] A healthy candidate is blessed only after closure, boot entry, UKI hash, transaction, and health checks all match.
- [x] A health failure or sudden power loss returns to the prior blessed generation by boot attempt two.
- [x] The failed candidate is aborted, quarantined, and cannot become active through startup reconciliation.
- [x] Prior blessed and recovery closures have explicit GC roots and verified selectable UKIs.
- [x] Both graphics profiles pass real UEFI VM reboots with simulated display evidence.
- [x] The fixed recovery UKI is independently built, signed, selectable, and not boot-counted.
- [x] Full fast, opt-in, and root flake gates pass with explicit exit codes.
