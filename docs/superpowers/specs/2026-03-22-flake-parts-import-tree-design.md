# Flake-Parts + Import-Tree Migration Design

## Summary

Migrate the main `flake.nix` from manual outputs to flake-parts, add import-tree for automatic module discovery, and restructure `modules/home-manager/` to separate config files from Nix modules.

## Goals

- Replace manual `outputs` boilerplate with flake-parts module system
- Eliminate manual `bundle.nix` import lists using import-tree auto-discovery
- Clean separation between Nix modules and runtime config files
- Foundation for future per-system outputs (packages, checks, devShells) via flake-parts

## Scope

- Main `flake.nix` only (shells/flake.nix stays unchanged)
- Both NixOS and home-manager module directories get import-tree
- Non-module files (configs, scripts, assets) relocated to `home/`

## Design

### New Inputs

Add to `flake.nix`:

```nix
flake-parts.url = "github:hercules-ci/flake-parts";
import-tree.url = "github:vic/import-tree";
```

Remove `flake-utils` from the main flake (unused in outputs, shells has its own).

### Flake Structure

Replace current outputs with flake-parts:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "x86_64-linux" ];

  flake = let
    system = "x86_64-linux";

    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.permittedInsecurePackages = [ "electron-37.10.3" ];
      overlays = [
        inputs.nix-vscode-extensions.overlays.default
        inputs.niri-blur.overlays.default
      ];
    };

    pkgs-stable = import inputs.nixpkgs-stable {
      inherit system;
      config.allowUnfree = true;
    };

    mkSystem = host: userModule: inputs.nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      specialArgs = { inherit inputs pkgs-stable; };
      modules = [
        ./hosts/${host}/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs pkgs-stable; };
          home-manager.backupFileExtension = "backup";
          home-manager.users.rupan = import userModule;
        }
      ];
    };
  in {
    nixosConfigurations = {
      laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
      iso = mkSystem "iso" ./home/rupan/laptop.nix;
    };
  };
};
```

Key points:
- `nixosConfigurations` goes under `flake` since it is not a per-system output
- `pkgs` and `pkgs-stable` are defined once in the outer `let` and reused (preserving current pattern, no duplicate evaluation)
- `mkSystem` helper preserved as-is

### Directory Restructure

Move non-module files out of `modules/home-manager/` so import-tree can cleanly auto-import the entire directory:

**Before:**
```
modules/home-manager/
  configs/       # non-module config files (KDL, CSS, TOML, etc.)
  scripts/       # non-module shell scripts (rofi-profile, rupan, switch-profile, toggle-variant, writeUSB)
  assets/        # images, wallpapers, previews
  cli/           # .nix modules
  profiles/      # .nix modules
  bundle.nix     # manual import list + defaults
  *.nix          # modules
```

**After:**
```
modules/home-manager/   # ONLY .nix modules — import-tree auto-imports all
  cli/
  profiles/
  *.nix
  (no bundle.nix)

home/
  configs/              # moved from modules/home-manager/configs/
  scripts/              # moved from modules/home-manager/scripts/
  assets/               # moved from modules/home-manager/assets/
  rupan/                # existing
    laptop.nix
    home.nix
```

### Import-Tree Integration

**NixOS modules** — in `hosts/*/configuration.nix`, replace:
```nix
imports = [ ../../modules/nixos/bundle.nix ];
```
with:
```nix
imports = [ (inputs.import-tree ../../modules/nixos) ];
```

**Home-manager modules** — in `home/rupan/laptop.nix`, replace:
```nix
imports = [ ../../modules/home-manager/bundle.nix ];
```
with:
```nix
imports = [ (inputs.import-tree ../../modules/home-manager) ];
```

**Important:** `hosts/iso/configuration.nix` must add `inputs` to its function arguments (currently takes `{ config, lib, pkgs, modulesPath, self, ... }` — `inputs` is available via `specialArgs` but must be destructured explicitly to use with import-tree).

Delete both `bundle.nix` files after migration.

### Bundle.nix Content Migration

The current home-manager `bundle.nix` contains non-import config:

```nix
desktopProfiles.enable = lib.mkDefault true;
niri.enable = lib.mkDefault true;
noctalia.enable = lib.mkDefault true;
terminal.enable = lib.mkDefault true;

home.file.".local/bin" = {
  source = ./scripts;
  recursive = true;
  executable = true;
};

xdg.configFile."rofi".source = ...;
home.sessionPath = [ "$HOME/.local/bin" ];
```

This moves to `home/rupan/laptop.nix` with paths updated:
- `source = ./scripts` becomes `source = ../scripts` (relative from `home/rupan/` to `home/scripts/`)
- rofi symlink path updates from `modules/home-manager/configs/rofi` to `home/configs/rofi`

The NixOS `bundle.nix` only has `git.enable = lib.mkDefault true;` beyond imports — this moves to `hosts/laptop/configuration.nix`.

### Disabled Module Handling

`quickshell-bar.nix` (currently commented out in bundle.nix) will be auto-imported by import-tree. It uses `mkEnableOption`/`mkIf`, so it does nothing unless explicitly enabled. No special handling needed.

### Path Updates — Complete Inventory

All files containing references to `modules/home-manager/configs/`, `modules/home-manager/scripts/`, or `modules/home-manager/assets/` that must be updated:

**Nix modules (change `modules/home-manager/configs/` → `home/configs/`, etc.):**

| File | What to update |
|------|---------------|
| `modules/home-manager/niri.nix:40-46` | 7 `mkOutOfStoreSymlink` paths for niri, kitty, gtk-2.0, gtk-3.0, gtk-4.0, qt5ct, qt6ct |
| `modules/home-manager/common-apps.nix:49` | Firefox chrome `mkOutOfStoreSymlink` |
| `modules/home-manager/common-apps.nix:95` | VS Code settings `mkOutOfStoreSymlink` |
| `modules/home-manager/noctalia.nix:166` | Wallpaper directory path |
| `modules/home-manager/noctalia.nix:258` | Avatar image path (Sponge.jpg) |
| `modules/home-manager/quickshell-bar.nix:12` | Quickshell config `mkOutOfStoreSymlink` |
| `modules/home-manager/terminal.nix:59` | `builtins.readFile ./configs/bashrc/.bashrc` — **Nix eval-time relative path**, must change to `../../home/configs/bashrc/.bashrc` |
| `modules/home-manager/terminal.nix:65` | `cniri` alias hardcoded path |
| `modules/home-manager/profiles/noctalia.nix:15` | Wallpaper dir |
| `modules/home-manager/profiles/everforest.nix:104-105` | Wallpaper dirs (regular + light) |
| `modules/home-manager/profiles/rosepine.nix:101-102` | Wallpaper dirs |
| `modules/home-manager/profiles/catppuccin.nix:98-99` | Wallpaper dirs |
| `modules/home-manager/profiles/nord.nix:74` | Wallpaper dir |
| `modules/home-manager/profiles/gruvbox.nix:109-110` | Wallpaper dirs |

**Non-Nix files (runtime paths, also need updating):**

| File | What to update |
|------|---------------|
| `home/configs/bashrc/.bashrc:11` | `cniri` alias path |
| `home/configs/niri/config.kdl:205` | Rofi theme path in app launcher binding |
| `home/configs/niri/config.kdl:217` | toggle-variant script path |
| `home/scripts/rofi-profile:6` | `PREVIEW_DIR` path |
| `home/scripts/rofi-profile:8` | `THEME` path |

**Documentation (update references):**

| File | What to update |
|------|---------------|
| `CLAUDE.md` | Section about config files path |
| `README.md:14` | Config files path reference |

**Pattern for path changes:**
- `modules/home-manager/configs/` → `home/configs/`
- `modules/home-manager/scripts/` → `home/scripts/`
- `modules/home-manager/assets/` → `home/assets/`

## Out of Scope

- `shells/flake.nix` migration (stays as-is with flake-utils)
- Dendritic sub-flake pattern
- nix-wrapper-modules
- Any functional changes to module behavior

## Risks

- **Path breakage**: The main risk — mitigated by the complete inventory above. A final grep sweep should be done after implementation.
- **Import-tree picking up unexpected files**: Mitigated by the restructure moving all non-module content out.
- **Flake lock changes**: Adding new inputs will update `flake.lock`. Normal and expected.
- **`builtins.readFile` relative path**: `terminal.nix` uses a Nix eval-time relative path to read bashrc — this is a different mechanism than `mkOutOfStoreSymlink` and must be updated or it will fail at build time.
