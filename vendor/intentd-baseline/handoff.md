# Stage 2 physical deployment handoff

Date: 2026-10-07

## Physical deployment work

The laptop integration is in `/home/rupan/nixos`: a pinned local intentd Git
input, `modules/nixos/intentd-host.nix`, and
`hosts/laptop/intentd-recovery.nix`. It adds persistent root-owned state,
first-boot journal-key provisioning, machine/display evidence, recovery
closure retention, the boot guard, and a narrow future `nixos-rebuild boot`
sudo rule. The running session has not been switched or rebooted.

Fast intentd checks pass: 505 default tests, Ruff, and Pyright. The laptop and
standalone recovery evaluate, and laptop safety assertions pass. The full
NixOS check currently stops on the pre-existing hardcoded Syncthing backup
path in `modules/nixos/syncthing.nix:105`; the same line exists at HEAD.

Physical acceptance is still open. The first deployment intentionally has
no journal until an authenticated baseline is established. The default
production workspace targets the VM-oriented flake; host transaction wiring
must preserve the actual host configuration and bind the installed candidate
UKI. Do not use the VM seed helper's synthetic invocation and lock evidence
for physical history. Building the recovery closure does not install its
signed fixed UKI or provide the interactive physical console.

See `docs/host-setup.md`, section 6, for the integration boundary. Build and
staging receipts are recorded below.

### Deployment receipts

- Built laptop closure: `/nix/store/ns4x08jb6aqxn52p9w5la1irmg5rngwc-nixos-system-laptop-nixos-26.11.20260916.b1b8759`.
- Built recovery closure: `/nix/store/g8s6bgpaad16ki14pmp9ciwgsx82cmqw-nixos-system-intentd-recovery-26.11.20260916.b1b8759`.
- Build log: `/tmp/intentd-host-deploy.42yFW1/build.log`; both closures and the performance specialisation built successfully, using local builders only.
- Focused Nix reliability option tests: 4 passed.
- Full NixOS formatting check: passed, 147 files unchanged.
- The compiled display probe succeeds on the live machine; greetd and udev are active.
- `systemd-analyze verify` succeeds for the three new units. It reports existing numberpad output-specifier and CUPS legacy-path warnings.
- Privileged staging script: `/nix/store/hnlm87g0brd3lixzkbdhvqv3a2w8yz01-stage-host` (ShellCheck passed). It reads the physical NV counter, checks Secure Boot, retains the prior closure, and uses `nixos-rebuild boot --store-path ... --no-reexec` against the exact built closure. Without `--no-reexec`, this rebuild wrapper attempts a legacy `nixos-config` evaluation before acting; the first attempt failed there with the profile unchanged.
- Hardware preflight: Secure Boot enabled; NV counter `0x01800001` exists with 8-byte width and value 1. The read used `TPM2TOOLS_TCTI=device:/dev/tpmrm0`.
- Staging succeeded: generation 69, counted UKI `nixos-generation-69-ubbsh3gasl4wgmxxx5f7wp7pesllrmt56rawnv2fowoiouwkoicq+1.efi`, one attempt left, now the boot default. Lanzaboote installed it and refreshed the PCR 0/4/7 LUKS policy at NV index `0x193e015`.
- `sbctl verify` confirms that exact installed generation-69 UKI is signed.
- Running closure remains `/nix/store/fpiz3wmvgiak71lcbfpj3w57k2gm2xv6-nixos-system-laptop-nixos-26.11.20260916.b1b8759` (generation 68). It is retained by `/nix/var/nix/gcroots/intentd-host-before-deployment`.
- No reboot has been requested or performed. Key provisioning, service runtime verification, initial journal anchoring, the physical transaction, and the recovery round trip remain open.

## Repository state

- Repository: `/home/rupan/projects/intentd`
- Branch: `main` at `9ccae84` (`feat: bind boot blessing to TPM2 monotonic rollback counter`). Milestone 3 and the TPM binding are committed. The physical-certification plan contains pre-existing October 6 Secure Boot verification edits.
- No Git remote is configured.
- Stage 1 is closed in `/home/rupan/obsidian/vaults/main/Projects/OS/stage1_wedge_implementation_plan.md`.
- The Stage 2 contract is in `/home/rupan/obsidian/vaults/main/Projects/OS/intent_native_os_project_overview.md`.
- The completed milestone plan is `docs/superpowers/plans/2026-10-01-stage-2-failure-matrix-closure.md`.
- Milestone 2 (boot reliability core) stays merged on `main`; its verdict and evidence below are unchanged.

## Milestone 3 verdict

The Stage 2 injected-failure matrix is closed within its VM-certified boundary, and the constrained recovery console is implemented and VM-proven. Every proposal binds the SHA-256 digest of the catalog that authorized it, and a stale or rolled-back catalog is rejected once a blessed transaction establishes the floor. Every boot plan binds the SHA-256 digest of its staged invocation, and the model-free boot guard refuses to bless a candidate whose plan does not match its transaction. Aborted and quarantined transactions can never reactivate; a fresh transaction is required. Disk-pressure and abort-path audit failures are proven before any authoritative transition.

In the persistent-disk VM, a failed critical service quarantines and returns to the exact prior blessed boot; the integrated bless completes with staging inside a network namespace and no model binary or credential present; and the recovery image boots, reports authenticated journal status through the console, reselects the verified blessed generation, and returns to the exact blessed closure with pointers unchanged.

## Failure-matrix evidence

Unit level (`nix develop -c uv run pytest -q`: 480 passed, 6 deselected):

- Failed build: `test_build_failure_rejects` — rejected before pending; exact call sequence shows only the build ran.
- Failed activation/UKI install: `test_activation_error_aborts_with_exception_text_and_restores` and the boot-preflight/staging suite — aborted or rejected before reboot; prior blessed entry restored.
- Disk pressure: the root/ESP preflight parametrize rejects below reserve, asserts no `set_profile`/`install_boot_candidate` call, no reboot, and no in-flight transaction.
- Stale catalog: `tests/test_catalog_binding.py` (6 tests) — mutated-catalog proposal rejected with `StoreError("stale catalog...")` before pending with no pending record; the reverse order proves rollback rejection; a directly appended stale proposal fails closed on projection replay; malformed hashes refused.
- Rolled-back invocation (wrong intent, healthy system): parametrized guard test in both profile directions — `BootGuardError` before any transition, selection, or reboot; blessed/active pointers unchanged; only `observe_boot` ran.
- Stale-state reapplication: `test_aborted_quarantined_transaction_cannot_reactivate` — every forward transition on the aborted transaction raises, blessed/active untouched, terminal state survives journal replay, and a fresh transaction for the same intent validates normally.
- Abort-path audit failure: `test_boot_abort_journal_failure_surfaces_without_partial_abort` — a journal failure at the abort transition surfaces with the record still pending, no failure evidence recorded, and pointers untouched.
- Console: `tests/test_recovery_console.py` (6 tests) — unknown verbs exit without acting; inspect and select-blessed record no journal transitions; select without an anchor fails closed; an AST pin proves the console module imports no model, network, or shell stack.

Persistent VM (`nix build .#checks.x86_64-linux.vm-boot`, all 7 subtests finished):

- Seed, integrated blessing (staging executed inside `unshare -n`; no `claude` binary and no `ANTHROPIC` environment in the guest), hybrid blessing with counter loss, display-failure fallback, critical-service fallback, power-loss fallback, recovery round trip.
- Critical-service subtest: the `critfail` specialisation fails only the second profile critical unit while display evidence succeeds; the candidate is aborted with a quarantined failed outcome naming `intentd-critical-ready.service`, and the exact prior blessed closure returns with blessed/active pointers unchanged.
- Recovery subtest: oneshot into the fixed recovery entry, marker plus console-service success, model/credential absence, console `inspect` reporting the blessed anchor with no pending transaction, console `select-blessed` returning a verified entry, and return to the exact blessed closure with blessed/active pointers unchanged and no pending transaction.

Fallback boots reach `multi-user.target` with a successful guard run; `boot-complete.target` is not waited on there, following the milestone 2 precedent.

## Design corrections found by the VM runs

- The harness reconnects with `start(allow_reboot=True)` after the simulated power-loss crash. The driver's auto-restart uses `allow_reboot=False`, so the next guest reset killed QEMU instead of resetting it.
- Shell commands must never race a guest-initiated reboot; every reboot crossing now sequences through serial-console text before any shell use.
- The console return path uses persistent default selection. Oneshot selection of the uncounted blessed entry stalls this loader silently; oneshot to counted entries and persistent-default selection are the proven mechanisms here.
- The harness base enables DHCP for its own plumbing, so the VM asserts console function and credential absence rather than route absence. The image-level network-free claim stays with the `nix_eval` option test.

## Deployment contract deltas

- `docs/host-setup.md` now records the catalog-hash floor, the invocation binding, and the four recovery console verbs.
- The recovery image packages a 14-module console wrapper (no full `intentd` package; the existing `"intentd" not in packages` eval pin still holds) plus a read-only `inspect` service.
- New binaries: `intentd-recovery-console`; new executor primitive: `poweroff`.
- Flake `self` excludes untracked sources, so new files must at least be staged before any Nix build.

## Verified milestone gate

Fresh results on 2026-10-01:

- Default pytest suite: 480 passed, 6 deselected.
- Opt-in `nix_eval`: 5 passed, 481 deselected.
- Opt-in `claude_live`: 1 failed — reproduced on the clean base commit, so pre-existing and unrelated (the live model returned `abstain` for the install utterance; model drift, not a code regression).
- Ruff lint: clean.
- Ruff format: 68 files already formatted.
- Pyright: 0 errors, 0 warnings, 0 informations.
- `nix/reliability/vm-driver.py` byte compilation: clean.
- Production Nix formatting: clean, excluding intentional `tests/golden` fixtures.
- Focused persistent boot VM: all 7 subtests finished (seed, integrated, hybrid, display-failure, critical-service, power-loss, recovery).
- Root `nix flake check -L`: all checks passed.

Refresh from the repo root:

```fish
nix develop -c uv run pytest -q
nix develop -c uv run ruff check .
nix develop -c uv run ruff format --check .
nix develop -c pyright
nix develop -c uv run python -m py_compile nix/reliability/vm-driver.py
git ls-files '*.nix' ':!tests/golden/**' | xargs nix shell nixpkgs#nixfmt-rfc-style -c nixfmt --check
nix develop -c uv run pytest -q -o addopts='' -m nix_eval
nix develop -c uv run pytest -q -o addopts='' -m claude_live
nix flake check -L
```

## Deliberate milestone boundaries

- The authenticated checkpoint is file-backed, not bound to TPM2 monotonic state. Coordinated rollback of journal and checkpoint remains outside the claim.
- The ASUS Zenbook UX3404VC bill of materials, firmware baseline, signed physical recovery media, and real power-loss recovery run are not certified.
- Real-host privileged service deployment and secret provisioning are not exercised.
- Graphics evidence is deterministic VM service evidence, not physical GPU/display certification.
- Milestone 3 was committed as `a67b203`; the TPM binding followed as `9ccae84`.

## Next milestone

Stage 2 milestone 4 has implemented the TPM binding and recorded Secure Boot
enrollment. Finish host deployment, authenticate the initial boot anchor,
prove a real boot-affecting transaction, and execute the physical recovery
round trip before declaring the machine certified.
