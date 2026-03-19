# AI Tools Module Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dedicated Home Manager AI tools module, move existing AI packages into it, and package `deepagents` from a new flake input.

**Architecture:** Keep flake-level source and overlay wiring in `flake.nix`, because package set construction happens there. Add a new `ai-tools` Home Manager module that owns AI package selection, split those packages out of `dev.nix`, and enable the new module in the user configs that currently enable `dev`.

**Tech Stack:** Nix flakes, Home Manager modules, Nixpkgs Python packaging, GitHub flake inputs

---

### Task 1: Add flake input and package source plumbing

**Files:**
- Modify: `flake.nix`

**Step 1: Write the failing check**

Confirm `flake.nix` does not yet declare a `deepagents` input.

**Step 2: Run check to verify the gap**

Run: `grep -n "deepagents" flake.nix`
Expected: no matches

**Step 3: Write minimal implementation**

Add a new flake input:

```nix
deepagents.url = "github:langchain-ai/deepagents";
```

Keep the `claude-desktop` input and overlay wiring in `flake.nix`, since that overlay must be available when `pkgs` is constructed.

**Step 4: Run check to verify it passes**

Run: `grep -n "deepagents" flake.nix`
Expected: one match for the new input

### Task 2: Create the AI tools module

**Files:**
- Create: `modules/home-manager/ai-tools.nix`

**Step 1: Write the failing check**

Confirm the module file does not exist yet.

**Step 2: Run check to verify the gap**

Run: `test -f modules/home-manager/ai-tools.nix`
Expected: non-zero exit status

**Step 3: Write minimal implementation**

Create a Home Manager module with:

```nix
{ pkgs, lib, config, inputs, ... }:

let
  deepagents = pkgs.python3Packages.buildPythonApplication {
    pname = "deepagents";
    version = "0.4.11";
    src = inputs.deepagents;
  };
in
{
  options.ai-tools.enable = lib.mkEnableOption "ai-tools";

  config = lib.mkIf config.ai-tools.enable {
    home.packages = with pkgs; [
      claude-code
      claude-desktop-fhs
      opencode
      codex
      deepagents
    ];
  };
}
```

Fill in the Python package fields needed by the chosen build helper after inspecting the upstream project metadata.

**Step 4: Run check to verify it passes**

Run: `grep -n "ai-tools\|deepagents\|claude-code\|codex" modules/home-manager/ai-tools.nix`
Expected: matches for the option and package list

### Task 3: Import the new module and remove AI packages from dev

**Files:**
- Modify: `modules/home-manager/bundle.nix`
- Modify: `modules/home-manager/dev.nix`

**Step 1: Write the failing check**

Confirm the bundle does not yet import `ai-tools.nix` and `dev.nix` still contains the AI package entries.

**Step 2: Run check to verify the gap**

Run: `grep -n "ai-tools" modules/home-manager/bundle.nix && grep -n "claude-code\|claude-desktop-fhs\|opencode\|codex" modules/home-manager/dev.nix`
Expected: no bundle match, plus matches in `dev.nix`

**Step 3: Write minimal implementation**

Import `./ai-tools.nix` from `modules/home-manager/bundle.nix` and remove these from `modules/home-manager/dev.nix`:

```nix
claude-code
claude-desktop-fhs
opencode
codex
```

Leave non-AI dev utilities in place.

**Step 4: Run check to verify it passes**

Run: `grep -n "ai-tools" modules/home-manager/bundle.nix ; grep -n "claude-code\|claude-desktop-fhs\|opencode\|codex" modules/home-manager/dev.nix`
Expected: bundle shows the new import; `dev.nix` has no matches for the moved packages

### Task 4: Enable the module for user configs

**Files:**
- Modify: `home/rupan/laptop.nix`
- Modify: `home/rupan/workmachine.nix`

**Step 1: Write the failing check**

Confirm neither host enables `ai-tools` yet.

**Step 2: Run check to verify the gap**

Run: `grep -n "ai-tools" home/rupan/laptop.nix home/rupan/workmachine.nix`
Expected: no matches

**Step 3: Write minimal implementation**

Add:

```nix
ai-tools.enable = true;
```

to both user configs near the other module toggles.

**Step 4: Run check to verify it passes**

Run: `grep -n "ai-tools.enable = true;" home/rupan/laptop.nix home/rupan/workmachine.nix`
Expected: one match in each file

### Task 5: Evaluate the resulting package set

**Files:**
- Verify: `flake.nix`
- Verify: `modules/home-manager/ai-tools.nix`
- Verify: `modules/home-manager/dev.nix`
- Verify: `modules/home-manager/bundle.nix`
- Verify: `home/rupan/laptop.nix`
- Verify: `home/rupan/workmachine.nix`

**Step 1: Evaluate the laptop Home Manager package names**

Run: `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in builtins.map (p: p.name or p.pname or "unknown") flake.nixosConfigurations.laptop.config.home-manager.users.rupan.home.packages'`
Expected: output includes `claude-code`, `claude-desktop`, `opencode`, `codex`, and `deepagents`

**Step 2: Evaluate the workmachine Home Manager package names**

Run: `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in builtins.map (p: p.name or p.pname or "unknown") flake.nixosConfigurations.workmachine.config.home-manager.users.rupan.home.packages'`
Expected: output includes `claude-code`, `claude-desktop`, `opencode`, `codex`, and `deepagents`

**Step 3: Commit**

```bash
git add flake.nix modules/home-manager/ai-tools.nix modules/home-manager/bundle.nix modules/home-manager/dev.nix home/rupan/laptop.nix home/rupan/workmachine.nix docs/plans/2026-03-18-ai-tools-design.md docs/plans/2026-03-18-ai-tools-module.md
git commit -m "feat: split AI tools into dedicated module"
```

Only do this if a commit is explicitly requested.
