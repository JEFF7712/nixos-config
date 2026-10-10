# Stage 2 Physical Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Safety gates:** Tasks 0-2 run without privilege and without touching the host. Tasks 3-6 need one explicit user ask EACH (sudo TPM provisioning, firmware/key changes, `nixos-rebuild` on the daily driver, physical reboot into recovery). Never reboot the host, enroll keys, or rebuild the host configuration on a standing "proceed".

**Goal:** Certify Stage 2 on the physical ASUS Zenbook UX3404VC: bind the authenticated journal checkpoint to TPM2 monotonic state so coordinated journal-plus-checkpoint rollback is detected, record the hardware/firmware bill of materials, deploy the closed reliability service set on the host, and execute the physical recovery run.

**Architecture:** A TPM2 NV monotonic counter is the rollback anchor. Every blessed transaction records the counter value it was blessed under; the store refuses to bless when the live NV counter is behind the journal's latest blessed counter, which a replayed (rolled-back) journal cannot satisfy because the counter only moves forward. The counter increments exactly once per blessing, inside the same journal append that records the blessing. Sealing the journal MAC key to PCRs is explicitly NOT the mechanism: sealing binds authority to boot state, not to monotonicity, and would brick recovery.

**Tech Stack:** Python 3.12, Pydantic 2, TPM2 NV counters (`tpm2-tools` for provisioning; a minimal kernel-sysfs or `tpm2-tss` read path for the guard), swtpm for VM integration tests, Lanzaboote 1.1.0, systemd 261, pytest, Ruff, Pyright.

---

## Task 0: Record the physical baseline (done, read-only)

Measured 2026-10-01 on the target machine itself:

- Product: `Zenbook UX3404VC_UX3404VC`, board `UX3404VC`, BIOS `UX3404VC.303` dated 08/18/2023, UEFI 2.80 (American Megatrends 5.27).
- CPU: 13th Gen Intel i9-13900H; RAM 30G; disk `nvme0n1` 953.9G WD PC SN560; kernel 6.18.52; NixOS 26.11 (`nixos-system-laptop-nixos`).
- TPM 2.0 at `/dev/tpm0` with user-readable SHA-256 PCRs; Secure Boot enabled (user mode); systemd-boot 261.2 with boot counting and one-shot control; measured UKI/OS reported yes.
- No Lanzaboote on the host, no `/var/lib/intentd`, no `/etc/intentd`: intentd is not deployed on the host.
- Host config lives in a `~/nixos` flake (`hosts/`, `modules/`); `/etc/nixos` is empty.
- No `tpm2-tools` in PATH; `systemd-cryptenroll` present.

## Task 1: Prototype the NV binding against swtpm (done)

**Files:**
- Created: `src/intentd/tpm.py`, `tests/test_tpm.py`, `tests/test_rollback_counter.py`, `nix/reliability/swtpm-prestart.nix`
- Modified: `src/intentd/store.py`, `src/intentd/txn.py`, `src/intentd/projection.py`, `src/intentd/wiring.py`, `src/intentd/boot_guard.py`, `src/intentd/recovery_console.py`, `nix/reliability/vm-boot.nix`, `nix/reliability/vm-driver.py`, `nix/reliability/module.nix`, `tests/helpers.py`, `tests/test_store.py`, `tests/test_boot_guard.py`

No host TPM contact. The VM test attaches swtpm to the guest.

- [x] **Step 1: Implement the counter backend.** (done 2026-10-01)

`tpm.py` exposes argv builders plus `define_counter`/`read_counter` and a frozen `NvCounter` (read/increment closures) built by `system_counter()` with an injectable run function; tests use closure/memory fakes, so there is no environment-selected stub in production code. NV index `0x01800001`, 8-byte width, and the counter attribute set live here. CLI syntax and output formats were pinned against a live swtpm (tpm2-tools 5.8): `nt=counter` is accepted symbolically, `nvincrement` is silent on success, `nvread` of a counter prints nothing to stdout so reads go through `-o` as 8-byte big-endian. 14 unit tests.

- [x] **Step 2: Record and enforce the counter at blessing.** (done 2026-10-01)

`TransactionRecord.nv_counter` (journal payload, projection column, `get()`); only boot-affecting `BLESSED` touches the counter, and only when one is configured (app blessings unchanged). Ordering correction vs the original sketch: the journal append records `live+1` FIRST, then the increment runs; increment-first would leave a one-blessing rewind indistinguishable from a crash gap, while record-first detects every journal-only rewind (`live > recorded` always refuses). The single crash window (append durable, increment lost) presents as `live == recorded-1`, which reopens tolerate and the next blessing repairs by converging before recording. Open-time check uses the same predicate, so replay fails closed; counter-bound state opened without a counter refuses. Full suite 505 passed, ruff and pyright clean.

- [x] **Step 3: Prove rollback detection.** (done 2026-10-01)

Unit proofs done (11 tests in `test_rollback_counter.py`: refusal without counter, monotonic records, crash-gap repair, ahead/behind refusal on open and at bless, counter-bound state without counter, single-blessing journal rewind via file snapshot/restore, exhaustion). VM evidence done: `vm-boot` passes all 8 subtests with a guest TPM. Findings from the bring-up, all verified empirically: QEMU's emulator chardev must point at swtpm's `--ctrl` socket (the `--server` socket deadlocks the SET_DATAFD handshake); the handshake is synchronous and fatal without a listener, so swtpm starts from a prestart snippet ahead of the lanzaboote image-helper's own machine start; swtpm drops its control socket when the QEMU client vanishes, so the powerloss subtest restarts it via `ensure_swtpm()` (state dir persists, counter monotonic across); a freshly defined counter reads NV-uninitialized until the first increment, so provisioning consumes value 1 and the healthy blessings assert `nv_counter` 2 then 3. Fast gates: 505 passed, ruff clean, pyright clean.

## Task 2: Audit Secure Boot key ownership (done, read-only)

Measured 2026-10-01, nothing written:

- `PK` (1258 bytes), `KEK` (4333), `db` (8894) enrolled; SetupMode 0 (user mode, active enforcement).
- `dbx` is ABSENT: no revocation list is enrolled, so revoked-image protection is currently off.
- The PK holds a single self-signed X.509 certificate with subject and issuer `CN=Platform Key`. Ownership (ASUS factory vs custom enrollment) is not distinguishable from the subject alone; assume stock firmware keys until proven otherwise.
- Verdict for Task 4: host Lanzaboote deployment must assume custom key enrollment is still required (firmware reboot, physical presence).

## Task 3: Provision the host TPM counter (GATE: explicit ask, sudo — done 2026-10-01)

- [x] **Step 1: NV counter provisioned on hardware.**

Hardware: TPM 2.0 rev 1.59 at `/dev/tpm0` (root-only `0600`; no owner password set). Tools: pinned `tpm2-tools` 5.7 built to `/tmp/host-tpm-tools` (kept for later tasks). Access: narrow NOPASSWD sudoers rule for five `tpm2_*` binaries (define/increment/read/readpublic/getcap); note it lives in `/etc/sudoers` and NixOS will overwrite that file on the next rebuild, so Task 5 must carry it into the `~/nixos` flake.
Provisioning (null owner auth, matching the VM prototype): index `0x01800001` was free (`0x18B`), defined with `ownerread|ownerwrite|authread|authwrite|no_da|orderly|nt=counter`, size 8; incremented once (fresh counters read NV-uninitialized, same as swtpm); verified `counter: 1` via `nvreadpublic` attributes plus `--print-yaml`. EK/SRK untouched, no clear, no owner-password change.
Deliberate deferral: owner-password hardening is NOT done — the store's null-auth counter matches the certified prototype; auth policy belongs to the Task 5 deployment review.
Minor leftover: `/tmp/host-nv-check.bin` is root-owned (from a readback) and outside the sudo rule; remove with `sudo rm` or leave it (next root readback overwrites it).

## Task 4: Settle the host Secure Boot story (GATE: explicit ask, firmware)

- [x] **Phase A audit (done 2026-10-01): config already wants lanzaboote; keys unenrolled.**

`secureboot.enable=true` is live in `~/nixos/hosts/laptop/base.nix` (module at `~/nixos/modules/nixos/secureboot.nix`, lanzaboote v1.1.0 input already present). ESP already carries signed UKIs for gens 57-60 (normal + performance); `/var/lib/sbctl` keys exist (GUID matches) but firmware is still MS-only user mode, so nothing is enrolled. LUKS has slots 0=password + 1=tpm2 (pcrlock policy, silent unlock currently working; passphrase fallback intact, so PCR churn cannot lock out). No auto-reboot exists (auto-update only `switch`es; nh-clean only prunes). Live gen 60 already ships `generate-sb-keys` + the full pcrlock stack.
Caution established: ESP loaders are almost certainly custom-signed already, so any reboot before enrollment lands in the firmware UI (recoverable, but avoid casual reboots). Open question for verify: whether auto-enroll keeps MS CAs (module comment claims so, for NVIDIA ROM); if the dGPU stops loading post-enroll, remedy is enrolling MS keys alongside.
- [x] **Phase B (user physical): firmware Setup Mode + reboot.** (done 2026-10-06) Cleared Secure Boot keys to reach Setup Mode, rebooted; auto-enroll wrote the sbctl keys. Firmware retained the Microsoft CAs alongside the custom chain.
- [x] **Phase C (verify + LUKS re-enroll):** (done 2026-10-06) Custom chain verified: `sbctl status` shows Setup Mode disabled, Secure Boot enabled, custom `Platform Key`/`Key Exchange Key`/`Database Key` in PK/KEK/db with MS certs retained; the gen-67 lanzastub UKI validates under the custom `db`.
  LUKS re-enroll found UNNECESSARY. `systemd-pcrlock-make-policy.service` regenerates the policy each boot from component predictions; this boot's run logged PCR 0/4/7 all matching and rewrote `/var/lib/systemd/pcrlock.json` plus TPM NV index `0x193e015`. Lanzaboote writes per-generation PCR-4 predictions into `635-lanzaboote.pcrlock.d` on every rebuild and `620-secureboot-authority` absorbed the enrollment, so the key change did not invalidate the keyslot. Confirmed on the next boot: LUKS prompted for the TPM2 PIN (not the full passphrase), i.e. the TPM path is active. The `luks-reinstall.md` re-enroll step is obsolete under `measuredBoot`.

## Task 5: Deploy intentd on the host (GATE: explicit ask, live system)

- [x] **Deployment configuration, build, and staging (2026-10-07).** `~/nixos/modules/nixos/intentd-host.nix` wires the guard, persistent state, first-boot key generation, hardware/display evidence, and recovery closure retention. `hosts/laptop/intentd-recovery.nix` uses the real encrypted filesystem layout. Both closures built; laptop safety assertions, formatting, the live display probe, and four focused Nix reliability tests pass. The full NixOS check stops on a pre-existing Syncthing path invariant. Secure Boot and physical NV counter value 1 verified. `nixos-rebuild boot --store-path ... --no-reexec` staged generation 69 and refreshed the LUKS PCR policy. Generation 68 remains running; no reboot occurred. Exact receipts and unresolved host transaction plumbing are in `handoff.md` and `docs/host-setup.md` section 6.

- [ ] **Step 1: Add the closed `services.intentd.reliability` set, certified machine profile, mode-`0600` journal credential, and GC roots to the `~/nixos` flake for the laptop host; `nixos-rebuild boot` (not `switch`, so the running session is untouched); reboot only on a separate explicit ask; then reconcile one real boot-affecting transaction and verify guard blessing on hardware.

## Task 6: Execute the physical recovery run (GATE: explicit ask, physical reboot)

- [ ] **Step 1: Install the signed fixed recovery UKI, reboot into it from the console, run the four console actions, reselect blessed, reboot back, and verify pointers. Record firmware behavior notes for real hardware (loader visibility, Secure Boot prompts) back into `docs/host-setup.md`.
