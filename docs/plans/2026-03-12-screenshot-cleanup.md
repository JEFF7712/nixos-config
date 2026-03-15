# Screenshot Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically remove files older than 30 days from the laptop screenshot directory.

**Architecture:** Add a dedicated NixOS module that defines a `systemd.tmpfiles.rules` entry for the screenshot directory, then enable that module only on the laptop host. This keeps the behavior modular and host-scoped while relying on built-in systemd cleanup instead of a custom script or timer.

**Tech Stack:** NixOS modules, `systemd-tmpfiles`, flakes

---

### Task 1: Add the reusable cleanup module

**Files:**
- Create: `modules/nixos/screenshot-cleanup.nix`
- Modify: `modules/nixos/bundle.nix`

**Step 1: Write the failing check**

Confirm the repo has no screenshot cleanup module and no tmpfiles rule for the screenshot path.

**Step 2: Run check to verify the gap**

Run: `grep -R "screenshot-cleanup\|/home/rupan/media/images/screenshots" modules hosts`
Expected: no dedicated cleanup module exists yet

**Step 3: Write minimal implementation**

Create a module with:

```nix
{ lib, config, ... }:

{
  options.screenshot-cleanup.enable = lib.mkEnableOption "automatic screenshot cleanup";

  config = lib.mkIf config.screenshot-cleanup.enable {
    systemd.tmpfiles.rules = [
      "e /home/rupan/media/images/screenshots - - - 30d"
    ];
  };
}
```

Import it from `modules/nixos/bundle.nix`.

**Step 4: Run check to verify the module exists**

Run: `grep -R "screenshot-cleanup\|/home/rupan/media/images/screenshots" modules hosts`
Expected: matches in the new module and bundle import

### Task 2: Enable cleanup on laptop only

**Files:**
- Modify: `hosts/laptop/configuration.nix`

**Step 1: Write the failing host check**

Confirm `hosts/laptop/configuration.nix` does not yet enable the new module.

**Step 2: Run check to verify it fails**

Run: `grep -n "screenshot-cleanup.enable" hosts/laptop/configuration.nix`
Expected: no match

**Step 3: Write minimal implementation**

Add:

```nix
screenshot-cleanup.enable = true;
```

near the other module enable flags in `hosts/laptop/configuration.nix`.

**Step 4: Run check to verify it passes**

Run: `grep -n "screenshot-cleanup.enable" hosts/laptop/configuration.nix`
Expected: one match in the laptop host config

### Task 3: Validate the Nix configuration

**Files:**
- Verify: `flake.nix`
- Verify: `hosts/laptop/configuration.nix`
- Verify: `modules/nixos/screenshot-cleanup.nix`

**Step 1: Run evaluation**

Run: `nixos-rebuild build --flake .#laptop`
Expected: evaluation succeeds and the laptop configuration builds

**Step 2: Commit**

```bash
git add modules/nixos/screenshot-cleanup.nix modules/nixos/bundle.nix hosts/laptop/configuration.nix docs/plans/2026-03-12-screenshot-cleanup-design.md docs/plans/2026-03-12-screenshot-cleanup.md
git commit -m "feat: add automatic screenshot cleanup"
```

Only do this if a commit is explicitly requested.
