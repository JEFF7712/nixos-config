# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A NixOS flake-based system configuration managing multiple hosts (laptop, workmachine, iso) with home-manager integration. The repo lives at `~/nixos` and is the single source of truth for system and user configuration.

## Build & Deploy Commands

```bash
# Build and switch to new configuration (laptop)
sudo nixos-rebuild switch --flake .#laptop

# Build and switch (workmachine)
sudo nixos-rebuild switch --flake .#workmachine

# Build without switching (dry run)
nixos-rebuild build --flake .#<host>

# Build the live ISO
nix build .#nixosConfigurations.iso.config.system.build.isoImage

# Enter a dev shell (python is default)
nix develop ./shells
nix develop ./shells#ml
nix develop ./shells#homelab
```

The fish alias `bnix` does: `git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push`

## Architecture

### Flake Entry Point (`flake.nix`)

Defines three NixOS configurations using a `mkSystem` helper:
- **laptop** — Primary machine with NVIDIA, gaming, heavy apps, VPN
- **workmachine** — Slimmer setup without heavy-apps, cli-toys, gaming, waydroid
- **iso** — Live installation image that auto-clones this repo on boot

Each host pulls from `hosts/<name>/configuration.nix` + `hardware-configuration.nix` and a corresponding home config from `home/rupan/<name>.nix`.

### Module System

All modules use the `lib.mkEnableOption` / `lib.mkIf config.<name>.enable` pattern and are toggled per-host.

**NixOS modules** (`modules/nixos/`): System-level — nvidia, niri, audio, bluetooth, docker, podman, distrobox, waydroid, game, vpn, netbird, etc. `bundle.nix` imports them all.

**Home-manager modules** (`modules/home-manager/`): User-level — niri (DE config), terminal (nixvim, fish, starship), common-apps, heavy-apps, dev, noctalia (theming), cli-tools, cli-toys. `bundle.nix` imports them all.

### Configuration Files (`modules/home-manager/configs/`)

Real config files (KDL, CSS, TOML, conf) that get symlinked into the home directory via `mkOutOfStoreSymlink`. This means they are **mutable at runtime** — edits to these files take effect without a rebuild. Includes configs for: niri, kitty, GTK 2/3/4, Qt 5/6, VS Code, fish, starship, Firefox.

### Theming (Noctalia)

The `noctalia` input provides a Material Design 3 theming system that generates color schemes from wallpapers. Theme files exist across GTK CSS, Qt color configs, niri KDL, and kitty configs.

### Key Inputs

- `nixpkgs` (unstable) + `nixpkgs-stable` (25.11)
- `home-manager`, `nixvim`, `spicetify-nix`, `nix-vscode-extensions`
- `noctalia` (dynamic theming), `claude-desktop`, `globalprotect-openconnect`

## Important Patterns

- Config files in `modules/home-manager/configs/` are symlinked out-of-store — they are editable without rebuild
- The `scripts/focus-mode.sh` toggles a minimal distraction-free theme across kitty, fish, starship, and niri
- Dev shells are defined in `shells/flake.nix`, not the main flake
- The ISO build workflow (`.github/workflows/build-iso.yml`) triggers on git tags matching `v*`
- GPU setup uses Intel iGPU + NVIDIA Prime offload with optional performance mode
