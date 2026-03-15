# Rebuild Stability Design

## Goal

Reduce laptop freezes during NixOS rebuilds by lowering build parallelism and adding swap space.

## Chosen approach

Keep Nix daemon tuning in `hosts/laptop/configuration.nix` and add a `16 GiB` swapfile in `hosts/laptop/hardware-configuration.nix`.

## Why this location

`nix.settings` already lives in the laptop host config, so adding `max-jobs` and `cores` there keeps performance tuning with the rest of the host-level Nix settings. `swapDevices` is already defined in the laptop hardware config, so adding the swapfile there keeps storage-backed hardware configuration in the expected file.

## Behavior

Set `max-jobs = 1` and `cores = 2` to reduce rebuild CPU and RAM spikes. Add `/swapfile` sized to `16 GiB` so memory pressure spills to disk instead of freezing the system.

## Verification

Evaluate the laptop configuration to confirm the Nix settings and swap device are present. A full rebuild or switch can be done afterward when convenient.
