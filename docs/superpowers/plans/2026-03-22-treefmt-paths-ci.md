# treefmt, Paths Cleanup, CI Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `nix fmt` via treefmt-nix, centralize hardcoded repo paths into a `repoPath` option, and add a GitHub Actions CI workflow.

**Architecture:** treefmt-nix integrates as a flake-parts module with `perSystem`. A new `repo-path.nix` home-manager module defines `config.repoPath` (defaulting to `~/nixos`), and all hardcoded paths reference it. CI runs `nix flake check` + `nix fmt -- --check` on push to main and PRs.

**Tech Stack:** NixOS, flake-parts, treefmt-nix, nixfmt, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-03-22-treefmt-paths-ci-design.md`

---

### Task 1: Add treefmt-nix

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add treefmt-nix input**

In `flake.nix` inputs section, add after the `import-tree` line:

```nix
treefmt-nix.url = "github:numtide/treefmt-nix";
```

- [ ] **Step 2: Add imports and perSystem to flake-parts config**

In the `outputs` block, add `imports` and `perSystem` to the flake-parts config object (between `systems` and `flake`):

```nix
inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "x86_64-linux" ];
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = { pkgs, ... }: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true;
    };
  };

  flake = let
    # ... existing code unchanged ...
```

- [ ] **Step 3: Update flake lock**

```bash
nix flake lock --update-input treefmt-nix
```

- [ ] **Step 4: Verify treefmt works**

```bash
nix fmt -- --check 2>&1 | head -20
```

Expected: either success (all formatted) or a list of files that need formatting. No errors.

- [ ] **Step 5: Run formatter on all files**

```bash
nix fmt
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add treefmt-nix with nixfmt formatter"
```

---

### Task 2: Create repo-path module

**Files:**
- Create: `modules/home-manager/repo-path.nix`

- [ ] **Step 1: Create the module**

```nix
{ lib, config, ... }: {
  options.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos";
    description = "Absolute path to the nixos config repo";
  };
}
```

This will be auto-imported by import-tree. No import list changes needed.

- [ ] **Step 2: Commit**

```bash
git add modules/home-manager/repo-path.nix && git commit -m "feat: add repoPath option for centralized repo path"
```

---

### Task 3: Replace hardcoded paths with config.repoPath

**Files:**
- Modify: `modules/home-manager/niri.nix:40-46`
- Modify: `modules/home-manager/common-apps.nix:49,95`
- Modify: `modules/home-manager/noctalia.nix:166,258`
- Modify: `modules/home-manager/quickshell-bar.nix:15`
- Modify: `modules/home-manager/profiles/noctalia.nix:15`
- Modify: `modules/home-manager/profiles/everforest.nix:104-105`
- Modify: `modules/home-manager/profiles/rosepine.nix:101-102`
- Modify: `modules/home-manager/profiles/catppuccin.nix:98-99`
- Modify: `modules/home-manager/profiles/nord.nix:74`
- Modify: `modules/home-manager/profiles/gruvbox.nix:109-110`
- Modify: `home/rupan/laptop.nix:35`

- [ ] **Step 1: Update `niri.nix` lines 40-46**

Replace `${config.home.homeDirectory}/nixos` with `${config.repoPath}` in all 7 symlink paths:

```nix
# Before:
xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/niri";
# After:
xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/niri";
```

Apply to all 7 lines (niri, kitty, gtk-2.0, gtk-3.0, gtk-4.0, qt5ct, qt6ct).

- [ ] **Step 2: Update `common-apps.nix` lines 49 and 95**

Same pattern — replace `${config.home.homeDirectory}/nixos` with `${config.repoPath}`:

Line 49 (Firefox):
```nix
"${config.repoPath}/home/configs/firefox/chrome"
```

Line 95 (VS Code):
```nix
source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/vscode/settings.json";
```

- [ ] **Step 3: Update `noctalia.nix` lines 166 and 258**

Replace `/home/rupan/nixos` with `${config.repoPath}`:

Line 166:
```nix
directory = "${config.repoPath}/home/assets/wallpapers/noctalia";
```

Line 258:
```nix
avatarImage = "${config.repoPath}/home/assets/Sponge.jpg";
```

- [ ] **Step 4: Update `quickshell-bar.nix` line 15**

```nix
"${config.repoPath}/home/configs/quickshell"
```

- [ ] **Step 5: Update all profile wallpaper paths**

For each profile, replace `/home/rupan/nixos` with `${config.repoPath}`:

`profiles/noctalia.nix:15`:
```nix
wallpaperDir = "${config.repoPath}/home/assets/wallpapers/noctalia";
```

`profiles/everforest.nix:104-105`:
```nix
wallpaperDir      = "${config.repoPath}/home/assets/wallpapers/everforest";
wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/everforest-light";
```

`profiles/rosepine.nix:101-102`:
```nix
wallpaperDir      = "${config.repoPath}/home/assets/wallpapers/rosepine";
wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/rosepine-light";
```

`profiles/catppuccin.nix:98-99`:
```nix
wallpaperDir      = "${config.repoPath}/home/assets/wallpapers/catppuccin";
wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/catppuccin-light";
```

`profiles/nord.nix:74`:
```nix
wallpaperDir = "${config.repoPath}/home/assets/wallpapers/nord";
```

`profiles/gruvbox.nix:109-110`:
```nix
wallpaperDir      = "${config.repoPath}/home/assets/wallpapers/gruvbox";
wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/gruvbox-light";
```

**Important:** The profile modules currently take `{ ... }:` as args. Those that use `config.repoPath` need `config` added to their function arguments. Check each file — some already have it, some may not.

- [ ] **Step 6: Update `home/rupan/laptop.nix` line 35**

```nix
# Before:
"${config.home.homeDirectory}/nixos/home/configs/rofi"
# After:
"${config.repoPath}/home/configs/rofi"
```

- [ ] **Step 7: Verify no hardcoded paths remain**

```bash
grep -rn '"/home/rupan/nixos\|homeDirectory}/nixos' modules/home-manager/ home/rupan/laptop.nix
```

Expected: no matches.

- [ ] **Step 8: Build to verify**

```bash
nixos-rebuild build --flake .#laptop
```

Expected: build succeeds.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "refactor: replace hardcoded paths with config.repoPath"
```

---

### Task 4: Add CI workflow

**Files:**
- Create: `.github/workflows/check.yml`

- [ ] **Step 1: Create the workflow file**

```yaml
name: Check
on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v30
        with:
          extra_nix_config: |
            accept-flake-config = true
      - name: Check flake
        run: nix flake check
      - name: Check formatting
        run: nix fmt -- --check
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/check.yml && git commit -m "ci: add flake check and format validation workflow"
```
