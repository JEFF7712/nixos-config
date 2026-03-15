# Screenshot Cleanup Design

## Goal

Automatically remove screenshots older than 30 days from the laptop's screenshot directory.

## Chosen approach

Use a small NixOS module that adds a `systemd.tmpfiles.rules` entry for `/home/rupan/media/images/screenshots`.

## Why this location

Keeping the behavior in `modules/nixos/` matches the repository's existing pattern of small opt-in system modules. Enabling it only in `hosts/laptop/configuration.nix` keeps the cleanup scoped to the laptop without assuming other hosts use the same path.

## Behavior

The rule uses the existing screenshot directory discovered in `modules/home-manager/configs/niri/config.kdl`. `systemd-tmpfiles` deletes contents older than `30d` while leaving the directory itself intact.

## Error handling

If the directory does not exist, cleanup is skipped. No custom timer or script is needed.

## Verification

Run a flake evaluation or host build to confirm the new module loads correctly for `laptop`.
