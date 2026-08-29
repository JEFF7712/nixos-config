# ASUS NumberPad Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the ASUS NumberPad driver's mutable configuration to persistent writable state.

**Architecture:** Keep the upstream module and package, but override its service command to use `/var/lib/asus-numberpad-driver`. Seed that state once from the declarative `/etc` file and preserve the directory through `/persist`.

**Tech Stack:** NixOS modules, systemd, preservation, Nix evaluation assertions

---

### Task 1: Define the failing persistence contract

**Files:**
- Modify: `checks/laptop-safety.nix`

- [x] **Step 1: Add assertions**

Assert that `/var/lib/asus-numberpad-driver` is preserved, that the service has
`StateDirectory=asus-numberpad-driver`, and that `ExecStart` passes the
persistent directory to `numberpad.py`.

- [x] **Step 2: Run the check and confirm RED**

Run: `just check-laptop-safety`

Expected: evaluation fails at the new persistence assertion because the
current service uses `/etc/asus-numberpad-driver/`.

### Task 2: Implement persistent mutable state

**Files:**
- Modify: `modules/nixos/asus-numpad.nix`
- Modify: `modules/nixos/impermanence.nix`

- [x] **Step 1: Override the service**

Resolve the existing upstream package from the flake input, set
`StateDirectory=asus-numberpad-driver`, seed `numberpad_dev` from `/etc` only
when absent, and force `ExecStart` to pass `/var/lib/asus-numberpad-driver/`.

- [x] **Step 2: Preserve the directory**

Add `/var/lib/asus-numberpad-driver` to the `/persist` directory list.

- [x] **Step 3: Run the check and confirm GREEN**

Run: `just check-laptop-safety`

Expected: `true`.

### Task 3: Build, activate, and verify runtime behavior

**Files:**
- Modify: `docs/superpowers/plans/2026-08-29-asus-numberpad-persistence.md`

- [x] **Step 1: Run scoped repository validation**

Run: `just check-changed`

Expected: all selected checks pass.

- [x] **Step 2: Build the laptop closure**

Run: `just build laptop`

Expected: exit 0.

- [x] **Step 3: Activate the configuration**

Run: `just switch`

Expected: activation succeeds and restarts `asus-numberpad-driver.service`.

- [x] **Step 4: Verify the live service**

Confirm the service is active, its command uses the persistent directory, the
file is a writable regular file on `/persist`, and the current activation log
contains no `Error during writting to config file` message.

- [x] **Step 5: Commit**

Stage only the plan, assertions, numberpad module, and impermanence module.
Commit using the repository's existing imperative message style.

### Task 4: Start only when the Wayland session is ready

**Files:**
- Modify: `checks/laptop-safety.nix`
- Modify: `modules/nixos/asus-numpad.nix`

- [x] **Step 1: Reproduce the physical reboot failure**

The persistent file survived with the same checksum, but the service exhausted
its restart limit before the Wayland socket appeared.

- [x] **Step 2: Add failing boot-order assertions**

Require path activation on `/run/user/1000/wayland-1`, remove direct boot
activation, and guard the service against a missing socket.

- [x] **Step 3: Activate through a systemd path unit**

Start the driver when the Wayland socket exists and skip restart attempts while
the session is unavailable.

- [ ] **Step 4: Validate, activate, and reboot**

Run the repository checks, activate the configuration, and confirm after a
second reboot that the path unit activates a healthy driver.
