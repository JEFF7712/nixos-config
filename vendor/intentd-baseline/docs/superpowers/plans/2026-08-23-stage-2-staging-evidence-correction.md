# Stage 2 Staging Evidence Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add authenticated ESP capacity evidence and a truthful pre-reboot staging-failure path so Stage 2 boot orchestration can fail closed without fabricating a boot observation.

**Architecture:** Extend the existing closed boot and machine models with replayable capacity thresholds and UKI size evidence. Add a separate `BootStagingFailure` journal payload for failures after `PENDING` but before reboot, while retaining `BootOutcome` exclusively for actual observed boots.

**Tech Stack:** Python 3.12, Pydantic 2, SQLite projection replay, authenticated JSONL journal, pytest, Ruff, Pyright, Nix development shell

---

### Task 1: Authenticate root and ESP capacity evidence

**Files:**
- Modify: `src/intentd/machine.py`
- Modify: `src/intentd/boot.py`
- Modify: `tests/helpers.py`
- Modify: `tests/test_machine.py`
- Modify: `tests/test_boot.py`
- Modify: `tests/test_store.py`
- Modify: `tests/test_projection.py`

- [ ] **Step 1: Write failing closed-model, capture, and evaluation tests**

Add `esp_reserve_bytes` to every `MachineProfile` fixture and assert that zero
or negative values are rejected:

```python
def test_machine_profile_requires_positive_capacity_reserves() -> None:
    profile = vm_machine_profile()
    with pytest.raises(ValueError, match="ESP reserve"):
        MachineProfile.model_validate(
            profile.model_copy(update={"esp_reserve_bytes": 0}).model_dump()
        )
```

Update boot fixtures with `uki_size_bytes`, `esp_free_bytes`,
`root_reserve_bytes`, and `esp_reserve_bytes`. Add these focused tests:

```python
def test_boot_artifact_requires_positive_uki_size() -> None:
    artifact = boot_plan_fixture().candidate
    with pytest.raises(ValueError):
        BootArtifact.model_validate(
            artifact.model_copy(update={"uki_size_bytes": 0}).model_dump()
        )


def test_capture_health_records_root_and_esp_capacity(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    paths: list[str] = []

    def fake_statvfs(path: str) -> SimpleNamespace:
        paths.append(path)
        available = 1024 if path == "/" else 512
        return SimpleNamespace(f_bavail=available, f_frsize=4096)

    monkeypatch.setattr(boot_module, "failed_units", no_failed_units)
    monkeypatch.setattr(boot_module.subprocess, "run", active_systemctl)
    monkeypatch.setattr(boot_module.os, "statvfs", fake_statvfs)

    snapshot = capture_health(vm_machine_profile())

    assert snapshot.root_free_bytes == 4_194_304
    assert snapshot.esp_free_bytes == 2_097_152
    assert paths == ["/", "/boot"]


def test_health_uses_authenticated_reserves_not_raw_free_space_baseline() -> None:
    plan = boot_plan_fixture().model_copy(
        update={
            "baseline": healthy_snapshot().model_copy(
                update={"root_free_bytes": 1_000_000_000, "esp_free_bytes": 500_000_000}
            ),
            "root_reserve_bytes": 268_435_456,
            "esp_reserve_bytes": 134_217_728,
        }
    )
    current = healthy_snapshot().model_copy(
        update={"root_free_bytes": 300_000_000, "esp_free_bytes": 150_000_000}
    )

    assert evaluate_boot_health(plan, candidate_observation(), current).healthy is True
```

Add exact reserve and artifact-size regressions:

```python
@pytest.mark.parametrize(
    ("field", "value", "expected"),
    [
        ("root_free_bytes", 268_435_455, "root free space"),
        ("esp_free_bytes", 134_217_727, "ESP free space"),
    ],
)
def test_health_rejects_capacity_below_authenticated_reserve(
    field: str, value: int, expected: str
) -> None:
    current = healthy_snapshot().model_copy(update={field: value})
    decision = evaluate_boot_health(
        boot_plan_fixture(), candidate_observation(), current
    )
    assert decision.healthy is False
    assert any(expected in failure for failure in decision.failures)


def test_verify_artifact_rejects_uki_size_mismatch(tmp_path: Path) -> None:
    artifact = materialized_artifact(tmp_path).model_copy(
        update={"uki_size_bytes": 1}
    )
    with pytest.raises(BootError, match="UKI size"):
        verify_artifact(artifact)
```

Define `materialized_artifact` locally in `tests/test_boot.py`; it writes the
UKI bytes, closure directory, and GC-root symlink and returns a fully matching
artifact. Update all existing complete model fixtures rather than adding
defaults to required evidence fields.

- [ ] **Step 2: Run tests to verify failure**

Run:

```fish
nix develop -c uv run pytest tests/test_machine.py tests/test_boot.py tests/test_store.py tests/test_projection.py -q
```

Expected: FAIL because the four new required evidence fields do not exist.

- [ ] **Step 3: Implement the minimal capacity model**

Extend `MachineProfile`:

```python
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

    @model_validator(mode="after")
    def _check_certified_facts(self) -> "MachineProfile":
        if self.root_reserve_bytes <= 0:
            raise ValueError("root reserve must be positive")
        if self.esp_reserve_bytes <= 0:
            raise ValueError("ESP reserve must be positive")
        return self
```

Extend the boot models without optional compatibility fields:

```python
class BootArtifact(ClosedModel):
    closure_path: str
    entry_id: str
    uki_path: str
    uki_sha256: str = Field(pattern=SHA256_PATTERN)
    uki_size_bytes: int = Field(gt=0)
    gc_root: str


class HealthSnapshot(ClosedModel):
    failed_units: tuple[str, ...]
    inactive_critical_units: tuple[str, ...]
    display_ready: bool
    root_free_bytes: int = Field(ge=0)
    esp_free_bytes: int = Field(ge=0)


class BootPlan(ClosedModel):
    candidate: BootArtifact
    prior_blessed: BootArtifact
    recovery: BootArtifact
    baseline: HealthSnapshot
    machine_profile_id: str
    root_reserve_bytes: int = Field(gt=0)
    esp_reserve_bytes: int = Field(gt=0)
    rendered_hash: str = Field(pattern=SHA256_PATTERN)
    flake_lock_hash: str = Field(pattern=SHA256_PATTERN)
```

In `verify_artifact`, reject a size mismatch before hashing:

```python
if uki_path.stat().st_size != artifact.uki_size_bytes:
    raise BootError(f"UKI size does not match artifact: {artifact.uki_path}")
if file_sha256(uki_path) != artifact.uki_sha256:
    raise BootError(f"UKI hash does not match artifact: {artifact.uki_path}")
```

Capture both filesystems:

```python
root_filesystem = os.statvfs("/")
esp_filesystem = os.statvfs("/boot")
return HealthSnapshot(
    failed_units=tuple(sorted(failed_units())),
    inactive_critical_units=tuple(inactive),
    display_ready=machine_profile.display_unit not in inactive,
    root_free_bytes=root_filesystem.f_bavail * root_filesystem.f_frsize,
    esp_free_bytes=esp_filesystem.f_bavail * esp_filesystem.f_frsize,
)
```

Replace the raw-baseline capacity comparison in `evaluate_boot_health`:

```python
if current.root_free_bytes < plan.root_reserve_bytes:
    failures.append("root free space is below the authenticated reserve")
if current.esp_free_bytes < plan.esp_reserve_bytes:
    failures.append("ESP free space is below the authenticated reserve")
```

Use `134_217_728` bytes as the certified ESP reserve in the VM test profile.
Use fixed positive UKI sizes in pure fixtures and exact file sizes in artifact
verification tests.

- [ ] **Step 4: Run focused tests and static checks**

Run:

```fish
nix develop -c uv run pytest tests/test_machine.py tests/test_boot.py tests/test_store.py tests/test_projection.py -q
nix develop -c uv run ruff check src/intentd/machine.py src/intentd/boot.py tests/helpers.py tests/test_machine.py tests/test_boot.py tests/test_store.py tests/test_projection.py
nix develop -c uv run pyright src/intentd/machine.py src/intentd/boot.py tests/helpers.py tests/test_machine.py tests/test_boot.py tests/test_store.py tests/test_projection.py
```

Expected: PASS, Ruff reports no errors, and Pyright reports zero errors.

- [ ] **Step 5: Commit**

```fish
git add src/intentd/machine.py src/intentd/boot.py tests/helpers.py tests/test_machine.py tests/test_boot.py tests/test_store.py tests/test_projection.py
git commit -m "feat: authenticate boot capacity evidence"
```

### Task 2: Authenticate pre-reboot staging failures

**Files:**
- Modify: `src/intentd/boot.py`
- Modify: `src/intentd/txn.py`
- Modify: `src/intentd/projection.py`
- Modify: `src/intentd/store.py`
- Modify: `tests/helpers.py`
- Modify: `tests/test_store.py`
- Modify: `tests/test_projection.py`

- [ ] **Step 1: Write failing transition and replay tests**

Add a complete helper:

```python
def staging_failure_fixture(
    phase: BootStagingPhase = BootStagingPhase.INSTALL_CANDIDATE,
) -> BootStagingFailure:
    return BootStagingFailure(
        candidate=boot_plan_fixture().candidate,
        phase=phase,
        detail="candidate installation failed",
        quarantined=True,
    )
```

Add public-store tests:

```python
def test_boot_abort_accepts_authenticated_staging_failure(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    failure = staging_failure_fixture()

    store.transition(txn, TxnStatus.ABORTED, boot_staging_failure=failure)

    assert store.get(txn).boot_staging_failure == failure
    assert store.get(txn).boot_outcome is None


def test_boot_abort_rejects_both_failure_forms(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    with pytest.raises(TransitionError, match="exactly one"):
        store.transition(
            txn,
            TxnStatus.ABORTED,
            boot_outcome=failed_outcome_fixture(),
            boot_staging_failure=staging_failure_fixture(),
        )


def test_boot_abort_rejects_staging_failure_for_wrong_candidate(tmp_path: Path) -> None:
    store, txn = pending_graphics_transaction(tmp_path)
    failure = staging_failure_fixture().model_copy(
        update={
            "candidate": boot_plan_fixture().candidate.model_copy(
                update={"closure_path": "/nix/store/wrong"}
            )
        }
    )
    with pytest.raises(TransitionError, match="candidate"):
        store.transition(txn, TxnStatus.ABORTED, boot_staging_failure=failure)
```

Add direct authenticated-journal replay tests using a journal built through the
same proposed, validated, built, and pending records as
`pending_graphics_transaction`. Append these exact invalid terminal payloads
and assert `rebuild_projection` raises `ProjectionError`:

```python
@pytest.mark.parametrize(
    "payload_update",
    [
        {
            "boot_outcome": failed_outcome_fixture().model_dump(mode="json"),
            "boot_staging_failure": staging_failure_fixture().model_dump(mode="json"),
        },
        {
            "boot_staging_failure": staging_failure_fixture()
            .model_copy(
                update={
                    "candidate": boot_plan_fixture().candidate.model_copy(
                        update={"closure_path": "/nix/store/wrong"}
                    )
                }
            )
            .model_dump(mode="json"),
        },
    ],
)
def test_projection_rejects_invalid_authenticated_staging_failure(
    boot_journal: AuthenticatedJournal,
    pending_graphics_txn: int,
    tmp_path: Path,
    payload_update: dict[str, JsonValue],
) -> None:
    payload: Payload = {
        "from_status": "pending",
        "to_status": "aborted",
        "boot_plan": None,
        "boot_outcome": None,
        "boot_staging_failure": None,
        "rendered_hash": None,
        "flake_lock_hash": None,
        "closure_path": None,
        "detail": None,
    }
    payload.update(payload_update)
    boot_journal.append(
        "transaction.transition", payload, txn_id=pending_graphics_txn
    )
    with pytest.raises(ProjectionError):
        rebuild_projection(tmp_path / "replayed.db", boot_journal.read_verified())
```

Create `boot_journal` and `pending_graphics_txn` as local fixtures in
`tests/test_projection.py`; they append only authenticated journal events and
never edit journal or SQLite bytes. Add separate tests that put staging evidence
on a non-boot `ABORTED` transition and a boot `BLESSED` transition. Extend
`test_projection_reconstructs_all_rows_exactly` with one staging-aborted boot
transaction so the new JSON column participates in exact row reconstruction.

- [ ] **Step 2: Run tests to verify failure**

Run:

```fish
nix develop -c uv run pytest tests/test_store.py tests/test_projection.py -q
```

Expected: FAIL because `BootStagingFailure` and the transition keyword do not
exist.

- [ ] **Step 3: Implement the staging evidence model**

Add to `src/intentd/boot.py`:

```python
class BootStagingPhase(StrEnum):
    SET_PROFILE = "set-profile"
    INSTALL_CANDIDATE = "install-candidate"


class BootStagingFailure(ClosedModel):
    candidate: BootArtifact
    phase: BootStagingPhase
    detail: str = Field(min_length=1)
    quarantined: Literal[True] = True
```

Import `StrEnum` from `enum` and `Literal` from `typing`. Do not make the
candidate or phase free-form strings.

Add `boot_staging_failure: BootStagingFailure | None = None` to
`TransactionRecord`, `_TransitionEvent`, `TransactionStore.transition`, and the
transition payload. Add `boot_staging_failure TEXT` to the transaction table,
serialize it during replay, and deserialize it in `TransactionStore.get`.

Apply this invariant before append and during replay:

```python
def _valid_staging_failure(
    failure: BootStagingFailure | None,
    plan: BootPlan | None,
) -> bool:
    return bool(
        failure is not None
        and plan is not None
        and failure.quarantined
        and failure.candidate == plan.candidate
    )
```

For a boot-affecting `ABORTED` transition, require exactly one supplied form,
then validate the selected form:

```python
if (boot_outcome is None) == (boot_staging_failure is None):
    raise TransitionError(
        "boot abort requires exactly one failed boot outcome or staging failure"
    )
if boot_outcome is not None and not _is_failed_quarantined_outcome(boot_outcome):
    raise TransitionError("boot abort requires a failed, quarantined boot outcome")
if boot_staging_failure is not None and not _valid_staging_failure(
    boot_staging_failure, stored_plan
):
    raise TransitionError("boot staging failure does not match the authenticated plan")
```

Use `ProjectionError` with the same rule during replay. Reject
`boot_staging_failure` on every status other than boot-affecting `ABORTED`, and
reject it for all non-boot transactions. A `BLESSED` transition continues to
require only a healthy `BootOutcome`.

- [ ] **Step 4: Run focused, reconstruction, and full tests**

Run:

```fish
nix develop -c uv run pytest tests/test_store.py tests/test_projection.py -q
nix develop -c uv run pytest tests/test_store.py -k reconstructs_all_rows -q
nix develop -c uv run pytest -q
nix develop -c uv run ruff check src tests
nix develop -c uv run pyright src tests
```

Expected: all tests pass, Ruff reports no errors, and Pyright reports zero
errors.

- [ ] **Step 5: Commit**

```fish
git add src/intentd/boot.py src/intentd/txn.py src/intentd/projection.py src/intentd/store.py tests/helpers.py tests/test_store.py tests/test_projection.py
git commit -m "feat: authenticate boot staging failures"
```

### Task 3: Reconcile the Stage 2 execution plan

**Files:**
- Modify: `docs/superpowers/plans/2026-08-23-stage-2-boot-reliability-core.md`

- [ ] **Step 1: Update Task 7 capacity and failure requirements**

Change Task 7 so `_stage_boot_candidate`:

```python
if baseline.root_free_bytes < deps.machine_profile.root_reserve_bytes:
    raise BootStagingError("root free space is below the certified reserve")
if baseline.esp_free_bytes < (
    deps.machine_profile.esp_reserve_bytes + candidate.uki_size_bytes
):
    raise BootStagingError("ESP free space cannot retain the reserve after installation")
```

Specify `BootStagingFailure` for failures from `set_profile` and
`install_boot_candidate`. Specify that a reboot-call failure leaves the
transaction pending because the authenticated plan and installed candidate
already agree.

- [ ] **Step 2: Update Task 7 fixtures and Task 10 VM evidence**

Require candidate inspection to record exact UKI size and make the VM proof
assert that ESP free space after installation remains at or above the certified
reserve. Keep root and ESP thresholds fixed in the VM machine profile.

- [ ] **Step 3: Scan the plan for stale model shapes**

Run:

```fish
rg -n "BootArtifact|HealthSnapshot|BootPlan|root_reserve_bytes|esp_reserve_bytes|BootStagingFailure" docs/superpowers/plans/2026-08-23-stage-2-boot-reliability-core.md
rg -n "TODO|TBD|implement later|fill in" docs/superpowers/plans/2026-08-23-stage-2-boot-reliability-core.md
```

Expected: every complete model example contains the new required fields and no
placeholder language exists.

- [ ] **Step 4: Commit**

```fish
git add docs/superpowers/plans/2026-08-23-stage-2-boot-reliability-core.md
git commit -m "docs: reconcile boot staging implementation plan"
```
