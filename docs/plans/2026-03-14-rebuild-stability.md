# Rebuild Stability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce laptop rebuild freezes by lowering Nix parallelism and adding a 16 GiB swapfile.

**Architecture:** Add Nix daemon resource limits to the laptop host config where existing `nix.settings` already live. Add a laptop-only swapfile in the hardware config so memory-backed stability settings stay scoped to the affected machine.

**Tech Stack:** NixOS modules, flakes, `nix.settings`, `swapDevices`

---

### Task 1: Limit rebuild parallelism on laptop

**Files:**
- Modify: `hosts/laptop/configuration.nix`

**Step 1: Write the failing check**

Confirm the laptop host config does not yet set `max-jobs` or `cores`.

**Step 2: Run check to verify the gap**

Run: `grep -n "max-jobs\|cores" hosts/laptop/configuration.nix`
Expected: no matches for the intended Nix rebuild limits

**Step 3: Write minimal implementation**

Add the following inside `nix.settings`:

```nix
max-jobs = 1;
cores = 2;
```

**Step 4: Run check to verify it passes**

Run: `grep -n "max-jobs\|cores" hosts/laptop/configuration.nix`
Expected: matches for both settings

### Task 2: Add laptop swapfile

**Files:**
- Modify: `hosts/laptop/hardware-configuration.nix`

**Step 1: Write the failing check**

Confirm the laptop hardware config still has an empty `swapDevices` list.

**Step 2: Run check to verify it fails**

Run: `grep -n "swapDevices" hosts/laptop/hardware-configuration.nix`
Expected: `swapDevices = [ ];`

**Step 3: Write minimal implementation**

Replace the empty list with:

```nix
swapDevices = [
  {
    device = "/swapfile";
    size = 16 * 1024;
  }
];
```

**Step 4: Run check to verify it passes**

Run: `grep -n "swapDevices\|/swapfile\|16 \* 1024" hosts/laptop/hardware-configuration.nix`
Expected: matches for the swapfile and size

### Task 3: Verify evaluated laptop settings

**Files:**
- Verify: `hosts/laptop/configuration.nix`
- Verify: `hosts/laptop/hardware-configuration.nix`

**Step 1: Evaluate Nix settings**

Run: `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in flake.nixosConfigurations.laptop.config.nix.settings'`
Expected: output includes `"max-jobs":1` and `"cores":2`

**Step 2: Evaluate swap devices**

Run: `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in flake.nixosConfigurations.laptop.config.swapDevices'`
Expected: output includes `/swapfile` and `16384`

**Step 3: Commit**

```bash
git add hosts/laptop/configuration.nix hosts/laptop/hardware-configuration.nix docs/plans/2026-03-14-rebuild-stability-design.md docs/plans/2026-03-14-rebuild-stability.md
git commit -m "feat: reduce laptop rebuild pressure"
```

Only do this if a commit is explicitly requested.
