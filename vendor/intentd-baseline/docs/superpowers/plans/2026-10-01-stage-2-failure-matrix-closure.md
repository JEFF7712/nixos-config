# Stage 2 Failure-Matrix Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Stage 2 injected-failure matrix from `docs/superpowers/specs/2026-08-23-stage-2-reliability-prototype-design.md`: every row gets a deterministic proof (unit or persistent-disk VM), the constrained recovery console exposes exactly its four typed actions on the recovery image, and the complete matrix passes with network and model access disabled.

**Architecture:** No new authority is created. Catalog identity and invocation identity become authenticated transaction bindings recorded in the journal: a catalog hash floor rejects stale catalogs before pending, and a plan-recorded invocation hash lets the model-free boot guard refuse a wrong-intent blessing. The recovery console is a typed, model-free action dispatcher over the authenticated journal (inspect, select blessed, reboot, power off) with no shell, no network, and no model client. VM proof reuses the persistent-disk UEFI harness in `nix/reliability/vm-boot.nix`.

**Tech Stack:** Python 3.12, Pydantic 2, SQLite projection replay, HMAC-SHA256 journal, NixOS modules, Lanzaboote 1.1.0, systemd 260 Automatic Boot Assessment, pytest, Ruff, Pyright.

---

## Coverage baseline (2026-10-01, `main` at `77d6fac`)

| Injection | Required outcome | Status |
| --- | --- | --- |
| Failed build | Reject before pending; boot state unchanged. | Covered at unit level (`test_build_failure_rejects`). Keep. |
| Failed activation / UKI install | Abort or reject before reboot; prior blessed stays selected. | Covered at unit level (`test_activation_error_aborts_with_exception_text_and_restores`, boot preflight/staging tests). Keep. |
| Hard power loss during activation | Prior blessed selected by boot attempt two. | Proven in VM (`vm-boot.nix`, power-loss subtest). Keep. |
| Disk pressure | Reject before install unless reserves remain. | Staging check exists (`orchestrator.py:124-129`); unit proof to be verified/extended in Task 4. |
| Broken display | Candidate not blessed; fallback selected. | Proven in VM (unhealthy subtest). Keep. |
| Critical-service failure | Candidate not blessed; prior blessed by attempt two. | NOT proven: no VM specialisation breaks a critical unit. Task 5. |
| Network and model unavailable | Blessing/recovery completes unchanged. | NOT proven deterministically: harness is implicitly offline. Task 6. |
| Wrong intent but healthy | Authorization binding fails; never blessed. | NOT enforced in guard: `BootPlan` carries no invocation binding. Task 2. |
| Audit persistence failure | Stop before authoritative transition. | Partially covered (`test_pending_journal_failure_prevents_reboot`); abort-path coverage in Task 4. |
| Stale / rolled-back catalog | Policy rejects before pending. | NOT implemented: catalog has no identity. Task 1. |
| Stale-state reapplication | Quarantined txn stays inactive; new txn required. | Partially covered (`test_abort_restores_active_pointer_to_blessed`); reactivation refusal in Task 3. |
| Constrained recovery console | Inspect, select blessed, reboot, power off; no shell/model/network. | NOT implemented: recovery image has inspect-only tooling plus a marker. Task 7. |

## Scope boundary

This plan implements Stage 2 delivery milestone 3 from the reliability spec: every remaining injection, the constrained recovery console, deterministic offline proof, and stale-state quarantine coverage.

Out of scope (milestone 4): TPM2 monotonic checkpoint binding, UX3404VC bill of materials and firmware baseline, physical recovery run, real-host privilege and credential provisioning.

## File map

- Modify `src/intentd/txn.py`: `catalog_hash` on `TransactionRecord`, `invocation_hash` on `BootPlan`.
- Modify `src/intentd/catalog.py`: canonical catalog digest helper.
- Modify `src/intentd/store.py`, `src/intentd/orchestrator.py`: record hashes, enforce catalog floor.
- Modify `src/intentd/boot.py`, `src/intentd/boot_guard.py`: invocation binding check before blessing.
- Create `src/intentd/recovery_console.py`: the four typed recovery actions.
- Modify `src/intentd/cli.py`, `pyproject.toml`: console entry points if needed.
- Create `tests/test_catalog_binding.py`, `tests/test_recovery_console.py`: unit proofs.
- Modify `tests/test_boot_guard.py`, `tests/test_store.py`, `tests/test_orchestrator.py`: binding and quarantine proofs.
- Modify `nix/reliability/recovery.nix`, `nix/reliability/module.nix`: console service wiring.
- Modify `nix/reliability/vm-boot.nix`, `nix/reliability/vm-driver.py`: critical-service and offline subtests, recovery console proof.
- Modify `handoff.md`: milestone 3 closeout.

### Task 1: Authenticate the catalog binding (done)

Implemented: `digest_catalog` in `catalog.py`; required `catalog_hash` on proposal payloads, `TransactionRecord`, and the projection table; floor enforced at `propose` and on replay; graphics capabilities resolve against the real catalog. Proofs in `tests/test_catalog_binding.py` (6 tests).

**Files:**
- Modify: `src/intentd/catalog.py`
- Modify: `src/intentd/txn.py`
- Modify: `src/intentd/store.py`, `src/intentd/orchestrator.py`
- Create: `tests/test_catalog_binding.py`

The app catalog is a compiled first-party registry with no identity, so a stale or rolled-back catalog cannot be detected. Bind it:

- [ ] **Step 1: Add a canonical catalog digest helper to `catalog.py`.**

Digest the canonical JSON of the validated catalog mapping (sorted entry ids, each entry canonical JSON). Return lowercase hex SHA-256. The empty mapping used for non-app capabilities must digest deterministically.

- [ ] **Step 2: Record `catalog_hash` on `TransactionRecord` at propose time.**

Add `catalog_hash: str` (SHA-256 pattern) to `TransactionRecord`. `store.propose` computes it from the catalog mapping passed for resolution and stores it in the journaled proposal. Update `tests/helpers.py` constructors.

- [ ] **Step 3: Enforce the catalog floor at proposal.**

`store.propose` rejects with `StoreError` when a blessed transaction exists and carries a different `catalog_hash`, and the projection rejects the same payload on replay. Enforcement lives at proposal because the floor cannot change mid-flight (a new blessing requires no in-flight transaction), which makes later transition-time checks unreachable. The first blessed transaction establishes the floor.

- [ ] **Step 4: Prove stale and rolled-back catalogs reject.**

Unit tests: bless with catalog A, then propose with catalog B (one entry changed) and assert rejection before pending with no boot-preference change. Reverse the order (bless B, propose A) for the rollback direction. Assert the journal contains no pending record for the rejected invocation.

### Task 2: Bind the invocation into the boot plan (done)

Implemented: `digest_invocation` in `registry.py`; required `invocation_hash` on `BootPlan`; orchestrator records it at staging; guard refuses blessing on mismatch before any transition, selection, or reboot. Proofs: parametrized wrong-intent test in `tests/test_boot_guard.py` (both profile directions).

**Files:**
- Modify: `src/intentd/boot.py`, `src/intentd/boot_guard.py`
- Modify: `src/intentd/orchestrator.py` (record the hash at staging)
- Modify: `tests/test_boot_guard.py`

A healthy system with the wrong intent must never bless. The guard currently matches boot identity only.

- [ ] **Step 1: Add `invocation_hash` to `BootPlan`.**

SHA-256 over the canonical JSON of the staged `CapabilityInvocation`. The orchestrator records it when building the plan. Update helpers and existing plan constructors.

- [ ] **Step 2: Refuse blessing on binding mismatch.**

`reconcile_boot` recomputes the hash from `pending.invocation` before the healthy path and raises `BootGuardError` on mismatch. The mismatch path transitions nothing, selects nothing, and releases no target.

- [ ] **Step 3: Prove wrong-intent candidates never bless.**

Unit tests: pending plan whose `invocation_hash` was recorded for `hardware.graphics.profile {integrated}` but whose transaction invocation reads `{hybrid-nvidia}` (and vice versa) raises before any store transition; assert blessed/active pointers unchanged and no reboot selected.

### Task 3: Prove quarantined transactions stay inactive (done)

Implemented: `test_aborted_quarantined_transaction_cannot_reactivate` in `tests/test_store.py`: every forward transition on the aborted transaction raises, blessed/active untouched, terminal state survives replay, and a fresh transaction for the same intent validates normally.

**Files:**
- Modify: `tests/test_store.py`

- [ ] **Step 1: Prove an aborted/quarantined transaction cannot become active.**

Unit tests: after an abort with a failed quarantined outcome, every forward transition attempt on that transaction id raises; `store.blessed()` still returns the prior blessed transaction; a new transaction for the same desired state validates and proceeds normally.

### Task 4: Harden pre-reboot failure proofs (done)

Implemented: disk-pressure preflight test now asserts no install/set-profile calls and no in-flight transaction; new `test_boot_abort_journal_failure_surfaces_without_partial_abort` proves abort-path journal failure surfaces with pointers untouched and no failure evidence recorded.

**Files:**
- Modify: `tests/test_orchestrator.py`

- [ ] **Step 1: Prove disk pressure rejects before installation.**

Unit tests: baseline with `root_free_bytes` below `root_reserve_bytes`, and ESP free below `esp_reserve_bytes + uki_size_bytes`, each raise `BootStagingError` before any install callback fires; assert the install/set-default/set-oneshot spies were never called and no pending record exists.

- [ ] **Step 2: Prove abort-path audit failure stops before transition.**

Unit tests: journal failure injected at the abort transition leaves pointers untouched and records no unjournaled activation; the failure surfaces instead of a silent partial abort.

### Task 5: Prove critical-service failure in the VM (done, VM-verified)

Implemented: second profile critical unit `intentd-critical-ready.service` (display stays healthy); `critfail` specialisation failing only that unit; `stage-critfail` driver verb; fallback subtest asserting return to the exact prior blessed closure, abort with quarantined outcome naming the unit.

**Files:**
- Modify: `nix/reliability/vm-boot.nix`, `nix/reliability/vm-driver.py`

- [ ] **Step 1: Add a `critfail` specialisation.**

Like `unhealthy`, but keeps display evidence succeeding and fails the profile critical unit instead (override `intentd-display-ready.service` is the display AND critical unit today, so introduce a second critical unit, e.g. `intentd-critical-ready.service`, succeeding in all other specialisations and failing only in `critfail`). Add the closure export and a `stage-critfail` driver verb.

- [ ] **Step 2: Add the fallback subtest.**

Stage `critfail`, reboot through it, and assert return to the exact prior blessed closure by attempt two, active equals blessed, failed transaction aborted with a quarantined outcome naming the inactive critical unit.

### Task 6: Prove deterministic offline blessing (done, VM-verified)

Implemented: integrated staging now runs inside `unshare -n` (no network interfaces at all); pre-staging asserts no `claude` binary and no `ANTHROPIC` environment; unit-level AST test pins that the console module imports no model/network/shell stack.

**Files:**
- Modify: `nix/reliability/vm-boot.nix`

- [ ] **Step 1: Assert the harness has no network or model path during blessing.**

In the integrated blessing subtest, before staging, assert no default route, no host store mount, and empty substituters from inside the guest; assert no model credential exists in the guest environment. The existing bless assertions then prove the deterministic path completes unchanged.

### Task 7: Build the constrained recovery console (done, VM-verified)

Implemented: `src/intentd/recovery_console.py` with exactly `inspect`, `select-blessed`, `reboot`, `poweroff` over injectable deps (6 unit tests in `tests/test_recovery_console.py`, including the no-network-import AST pin); `executor.poweroff` primitive; `recovery.nix` packages a 14-module wrapper (no full `intentd` package, image stays minimal) plus a read-only `inspect` service; `oneshot-recovery` driver verb; the VM subtest drives the console from the harness shell inside recovery (marker, console service success, model/credential absence, inspect content, select-blessed) and asserts the round trip back to the exact blessed closure with pointers unchanged. The harness base enables DHCP for its own plumbing, so the VM asserts console function and credential absence rather than route absence; the image-level network-free claim stays with the `nix_eval` option test. The console return uses persistent default selection after the VM runs proved oneshot selection silently stalls the loader for uncounted entries.

**Files:**
- Create: `src/intentd/recovery_console.py`
- Create: `tests/test_recovery_console.py`
- Modify: `nix/reliability/recovery.nix`, `nix/reliability/vm-boot.nix`, `nix/reliability/vm-driver.py`

The recovery application exposes exactly four typed actions and nothing else: inspect journal/boot status, select a verified blessed generation, reboot, power off. No shell, no network, no model client.

- [ ] **Step 1: Implement the console dispatcher.**

`recovery_console.py` exposes `run_console(argv, deps)` with verbs `inspect`, `select-blessed`, `reboot`, `poweroff`. `inspect` prints verified journal status and pointer state. `select-blessed` verifies the blessed artifact, sets it as the persistent boot default (oneshot is unreliable for uncounted entries on this loader), and records nothing (selection is a boot-loader preference, not a journal transition). `reboot`/`poweroff` call only the constrained executor primitives. Unknown verbs exit non-zero without acting. The module imports no resolver, no network, no subprocess shell.

- [ ] **Step 2: Wire the console into the recovery image.**

`recovery.nix` packages the console alongside the journal inspector and adds a local-console service presenting it. The image stays network-free with locked-down root as today.

- [ ] **Step 3: Prove the console path in the VM.**

New subtest after the power-loss proof: oneshot-select the recovery entry from a healthy state, reboot, assert the recovery marker and console `inspect` reporting the blessed anchor, run `select-blessed`, reboot, assert return to the exact blessed closure with pointers unchanged. Assert the recovery environment has no network route and no model credential.

### Task 8: Close out milestone 3

**Files:**
- Modify: `handoff.md`

- [ ] **Step 1: Refresh every gate and record the verdict.**

```fish
nix develop -c uv run pytest -q
nix develop -c uv run ruff check .
nix develop -c uv run ruff format --check .
nix develop -c pyright
nix develop -c uv run pytest -q -o addopts='' -m nix_eval
nix flake check -L
```

Rewrite `handoff.md` as the milestone 3 handoff: per-row evidence pointers, VM gate results, deliberate boundaries (TPM2, physical cert), and milestone 4 scope.
