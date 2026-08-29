# ASUS NumberPad Persistence Design

## Goal

Give the ASUS NumberPad driver a writable, persistent configuration file so it
can save brightness and enabled state without writing through a read-only Nix
store symlink.

## Root Cause

The upstream NixOS module creates
`/etc/asus-numberpad-driver/numberpad_dev` with `environment.etc`. NixOS
therefore exposes the file as a symlink into the read-only Nix store. The
driver calls its configuration save path during startup and whenever runtime
state changes, so writes fail even though the upstream module describes the
directory as writable.

## Design

Keep the upstream package and module, but override the service locally in
`modules/nixos/asus-numpad.nix`. The service will use
`/var/lib/asus-numberpad-driver/numberpad_dev` as its runtime configuration.
An idempotent pre-start step will copy the declarative `/etc` seed into that
location only when the mutable file does not exist. The service command will
pass `/var/lib/asus-numberpad-driver/` to the existing driver.

Add `/var/lib/asus-numberpad-driver` to the impermanence preservation set so
brightness and enabled state survive root rollback and reboot. The immutable
`/etc` file remains the first-boot seed and declarative fallback.

## Failure Handling

If the persistent file is absent, pre-start creates it from the declarative
seed with root ownership and mode `0644`. If seeding fails, systemd will not
start the driver with an invalid or missing configuration path. Existing
persistent state is never overwritten during rebuilds.

## Verification

Add assertions covering the persistent directory and the service command.
Run them before implementation to confirm the current configuration fails the
contract, then after implementation to confirm it passes. Build and activate
the laptop configuration, restart the service, and verify its current-boot log
contains no configuration write error. Reboot once and confirm the persistent
file remains writable and retains its state.

## Scope

This change does not patch the upstream flake, change the numberpad layout, or
alter device permissions. The MathWorks dependency issue is investigation-only
and remains separate.
