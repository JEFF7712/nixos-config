# treefmt-nix, Hardcoded Paths Cleanup, CI Checks Design

## Summary

Three independent enhancements: add treefmt-nix for `nix fmt`, replace hardcoded repo paths with a centralized option, and add a GitHub Actions CI workflow.

## Feature 1: treefmt-nix

### Goal

Enable `nix fmt` to auto-format all Nix files using the official `nixfmt` formatter.

### Design

Add `treefmt-nix` as a flake input and flake-parts module.

**Input:**
```nix
treefmt-nix.url = "github:numtide/treefmt-nix";
```

**flake.nix changes:** Add an `imports` list to the flake-parts config and a `perSystem` block:

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
    # ... existing mkSystem code ...
  in { ... };
};
```

**Usage:**
- `nix fmt` — format all Nix files
- `nix fmt -- --check` — check formatting without modifying (for CI)

### Files

- Modify: `flake.nix` (add input, imports, perSystem)

---

## Feature 2: Hardcoded Paths Cleanup

### Goal

Replace all hardcoded `/home/rupan/nixos/...` and `${config.home.homeDirectory}/nixos/...` references with a centralized `repoPath` option, so the repo location is defined once.

### Design

Create `modules/home-manager/repo-path.nix`:

```nix
{ lib, config, ... }: {
  options.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos";
    description = "Absolute path to the nixos config repo";
  };
}
```

This module will be auto-imported by import-tree. All Nix modules then use `config.repoPath` instead of hardcoded paths.

### Path Replacement Pattern

**mkOutOfStoreSymlink paths** (the majority):
```nix
# Before:
"${config.home.homeDirectory}/nixos/home/configs/niri"
# After:
"${config.repoPath}/home/configs/niri"
```

**Hardcoded absolute paths:**
```nix
# Before:
"/home/rupan/nixos/home/assets/wallpapers/noctalia"
# After:
"${config.repoPath}/home/assets/wallpapers/noctalia"
```

### Complete Inventory of Files to Update

**Nix modules with mkOutOfStoreSymlink:**

| File | Lines | What changes |
|------|-------|-------------|
| `modules/home-manager/niri.nix` | 40-46 | 7 symlink paths (niri, kitty, gtk-2.0, gtk-3.0, gtk-4.0, qt5ct, qt6ct) |
| `modules/home-manager/common-apps.nix` | 49, 95 | Firefox chrome, VS Code settings |
| `modules/home-manager/quickshell-bar.nix` | ~14 | quickshell config |
| `home/rupan/laptop.nix` | 35 | rofi config |

**Nix modules with hardcoded absolute paths:**

| File | Lines | What changes |
|------|-------|-------------|
| `modules/home-manager/noctalia.nix` | 166, 258 | wallpaper dir, avatar image |
| `modules/home-manager/terminal.nix` | 65 | cniri alias |
| `modules/home-manager/profiles/noctalia.nix` | 15 | wallpaperDir |
| `modules/home-manager/profiles/everforest.nix` | 104-105 | wallpaperDir, wallpaperDirLight |
| `modules/home-manager/profiles/rosepine.nix` | 101-102 | wallpaperDir, wallpaperDirLight |
| `modules/home-manager/profiles/catppuccin.nix` | 98-99 | wallpaperDir, wallpaperDirLight |
| `modules/home-manager/profiles/nord.nix` | 74 | wallpaperDir |
| `modules/home-manager/profiles/gruvbox.nix` | 109-110 | wallpaperDir, wallpaperDirLight |

**Non-Nix files (NOT updated — they use `$HOME` which is equivalent):**

| File | Lines | Why unchanged |
|------|-------|--------------|
| `home/configs/bashrc/.bashrc` | 11 | Uses `$HOME/nixos/...` — shell variable, can't use Nix options |
| `home/configs/niri/config.kdl` | 205, 217 | Uses `$HOME/nixos/...` — KDL config, runtime |
| `home/scripts/rofi-profile` | 6, 8 | Uses `$HOME/nixos/...` — shell script, runtime |

**Note on `terminal.nix:59`:** The `builtins.readFile ../../home/configs/bashrc/.bashrc` is a Nix eval-time relative path — it does not reference the repo by name, so no change needed.

### Files

- Create: `modules/home-manager/repo-path.nix`
- Modify: 13 files listed in inventory above

---

## Feature 3: CI Checks

### Goal

Add a GitHub Actions workflow that validates the flake on every push and PR: flake structure, config evaluation, and formatting.

### Design

Create `.github/workflows/check.yml`:

```yaml
name: Check
on: [push, pull_request]

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
      - name: Evaluate laptop config
        run: nix eval .#nixosConfigurations.laptop.config.system.build.toplevel --impure
```

**What each step catches:**
- `nix flake check` — flake structure issues, broken inputs
- `nix fmt -- --check` — unformatted Nix files (requires treefmt feature)
- `nix eval --impure` — config evaluation errors (missing modules, type errors, broken references) without building derivations

The `--impure` flag is needed because NixOS system evaluation may reference system-level paths. The existing `.github/workflows/build-iso.yml` is unaffected.

### Files

- Create: `.github/workflows/check.yml`

---

## Implementation Order

1. **treefmt-nix** — must come first since CI depends on `nix fmt`
2. **Hardcoded paths cleanup** — independent, can come in any order
3. **CI checks** — depends on treefmt being available for `nix fmt -- --check`

## Out of Scope

- Formatting existing files (run `nix fmt` once after setup — separate commit)
- Moving shells into the main flake
- ISO-specific home config
