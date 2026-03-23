# Flake-Parts + Import-Tree Migration Design

## Summary

Migrate the main `flake.nix` from manual outputs to flake-parts, add import-tree for automatic module discovery, and restructure `modules/home-manager/` to separate config files from Nix modules.

## Goals

- Replace manual `outputs` boilerplate with flake-parts module system
- Eliminate manual `bundle.nix` import lists using import-tree auto-discovery
- Clean separation between Nix modules and runtime config files

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

Remove `flake-utils` from the main flake (only used implicitly, shells has its own).

### Flake Structure

Replace current outputs with flake-parts:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "x86_64-linux" ];

  flake = {
    nixosConfigurations = let
      mkSystem = host: userModule: inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          config.permittedInsecurePackages = [ "electron-37.10.3" ];
          overlays = [
            inputs.nix-vscode-extensions.overlays.default
            inputs.niri-blur.overlays.default
          ];
        };
        specialArgs = {
          inherit inputs;
          pkgs-stable = import inputs.nixpkgs-stable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
        modules = [
          ./hosts/${host}/configuration.nix
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              pkgs-stable = import inputs.nixpkgs-stable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            };
            home-manager.backupFileExtension = "backup";
            home-manager.users.rupan = import userModule;
          }
        ];
      };
    in {
      laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
      iso = mkSystem "iso" ./home/rupan/laptop.nix;
    };
  };
};
```

`nixosConfigurations` goes under `flake = { }` since it is not a per-system output. The `mkSystem` helper is preserved largely as-is.

### Directory Restructure

Move non-module files out of `modules/home-manager/` so import-tree can cleanly auto-import the entire directory:

**Before:**
```
modules/home-manager/
  configs/       # non-module config files (KDL, CSS, TOML, etc.)
  scripts/       # non-module shell scripts
  assets/        # images, wallpapers
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

This moves to `home/rupan/laptop.nix` with paths updated to point to `home/scripts/` and `home/configs/rofi`.

The NixOS `bundle.nix` only has `git.enable = lib.mkDefault true;` beyond imports — this moves to `hosts/laptop/configuration.nix`.

### Disabled Module Handling

`quickshell-bar.nix` (currently commented out in bundle.nix) will be auto-imported by import-tree. It uses `mkEnableOption`/`mkIf`, so it does nothing unless explicitly enabled. No special handling needed.

### Path Updates

Modules referencing config files via relative paths or `mkOutOfStoreSymlink` need path updates:

- `mkOutOfStoreSymlink` paths use absolute repo path (`~/nixos/modules/home-manager/configs/...`) — update to `~/nixos/home/configs/...`
- Any `source = ./configs/...` relative references — update to `../../home/configs/...` or use absolute paths

These need to be audited across all home-manager modules during implementation.

## Out of Scope

- `shells/flake.nix` migration (stays as-is with flake-utils)
- Dendritic sub-flake pattern
- nix-wrapper-modules
- Any functional changes to module behavior

## Risks

- **Path breakage**: The main risk is missing a config file reference during the restructure. Mitigated by grepping for all `configs/`, `scripts/`, and `assets/` references.
- **Import-tree picking up unexpected files**: If non-module `.nix` files exist in the module directories. Mitigated by the restructure moving all non-module content out.
- **Flake lock changes**: Adding new inputs will update `flake.lock`. Normal and expected.
