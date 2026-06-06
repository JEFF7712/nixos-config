# NixOS Configuration

https://github.com/user-attachments/assets/7353f7df-9e9b-4f9d-a3ef-53f3f6bb75a5

This repo is the source of truth for my NixOS system, home-manager setup, desktop theming, and install ISO.

## Repo Map

- `flake.nix` - flake entrypoint and host outputs
- `hosts/` - machine-specific NixOS configs
- `home/rupan/` - user home-manager entrypoints
- `modules/nixos/` - reusable system modules
- `modules/home-manager/` - reusable user modules (auto-imported via import-tree)
- `lib/` - shared Nix helpers, including desktop profile file generation and theme builders
- `overlays/` - package overlays wired into the flake
- `pkgs/` - local packages
- `home/configs/` - live config defaults copied or linked into `$HOME` where mutability is intentional
- `home/scripts/` - user scripts symlinked into `~/.local/bin`
- `home/assets/` - wallpapers, previews, and other assets
- `shells/` - dev shells, including ML and homelab environments
- `justfile` - common maintenance, eval, dry-activate, and switch commands

## Maintenance

- `just` - list available recipes
- `just fmt` - format Nix files
- `just flake-check` - run `nix flake check`
- `just check` - run script syntax checks, flake checks, both system evals, and diff whitespace checks
- `just eval [target]` - evaluate one NixOS target, defaulting to `laptop`
- `just eval-all` - evaluate `laptop` and `iso`
- `just update` - update flake inputs
- `just build-iso` - build the ISO image
- `just dry` - dry-activate the laptop system
- `just switch` - switch the laptop system

## Try The ISO

1. Download the ISO from https://nix.rupan.dev
2. Flash it to a USB drive
3. Boot from the USB drive
4. Connect to Wi-Fi with `nmtui`
5. Run `get-config`
