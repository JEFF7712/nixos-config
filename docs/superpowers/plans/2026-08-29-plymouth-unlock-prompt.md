# Plymouth Unlock Prompt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the encrypted-disk unlock prompt and entry bullets beneath the existing NixOS Plymouth logo.

**Architecture:** Extend the existing Plymouth script theme with password, normal, message, and hide-message callbacks. Add a shell regression check that inspects the generated theme source contract, then validate the complete laptop system closure and activate it.

**Tech Stack:** Nix, Plymouth script plugin, Bash, just

---

### Task 1: Add a failing callback contract check

**Files:**
- Create: `checks/plymouth-theme.bash`
- Modify: `justfile`

- [x] **Step 1: Write the failing check**

Create a strict Bash check that requires `SetDisplayPasswordFunction`,
`SetDisplayNormalFunction`, `SetDisplayMessageFunction`, and
`SetHideMessageFunction` in `pkgs/plymouth-nixos-logo/default.nix`.

- [x] **Step 2: Verify the check fails**

Run: `bash checks/plymouth-theme.bash`

Expected: failure naming `SetDisplayPasswordFunction` because the current theme
does not implement graphical authentication.

### Task 2: Implement the graphical unlock view

**Files:**
- Modify: `pkgs/plymouth-nixos-logo/default.nix`

- [x] **Step 1: Register the authentication callbacks**

Add prompt, bullet, and message sprites below the centered logo. The password
callback shows and updates them, while the normal callback hides them.

- [x] **Step 2: Verify the regression check passes**

Run: `bash checks/plymouth-theme.bash`

Expected: `Plymouth theme checks passed.`

### Task 3: Integrate and validate

**Files:**
- Modify: `justfile`
- Modify: `checks/run-changed-checks.bash`

- [x] **Step 1: Wire the check into repository validation**

Add `plymouth-theme-check` to `just check` and select it when the theme package
or its check changes.

- [x] **Step 2: Run scoped validation**

Run: `just check-changed`

Expected: all selected checks pass.

- [x] **Step 3: Build the laptop closure**

Run: `just build laptop`

Expected: the laptop system closure builds successfully.

- [x] **Step 4: Activate the configuration**

Run: `just switch`

Expected: activation succeeds without newly failed systemd units.

- [ ] **Step 5: Commit the implementation**

Stage only the plan, check, theme package, changed-check routing, and justfile,
then commit using the repository's existing imperative message style.

### Task 4: Physical acceptance test

- [ ] **Step 1: Reboot**

Reboot the laptop after activation.

- [ ] **Step 2: Confirm graphical unlock**

Verify that the PIN prompt and entry bullets are visible beneath the NixOS logo
without pressing Escape, and that unlocking continues into the desktop.
