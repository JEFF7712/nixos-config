default:
  @just --list

fmt:
  nix fmt

shell-check:
  shellcheck -S error home/scripts/*

eval target="laptop":
  nix eval --no-write-lock-file ".#nixosConfigurations.{{target}}.config.system.build.toplevel.drvPath"

eval-all:
  just eval laptop
  just eval iso

flake-check:
  nix flake check

check:
  just shell-check
  just flake-check
  just eval-all
  git diff --check

update:
  nix flake update

build-iso:
  nix build .#nixosConfigurations.iso.config.system.build.isoImage

dry:
  sudo nixos-rebuild dry-activate --flake .#laptop

switch:
  #!/usr/bin/env bash
  # nixos-rebuild fallback bootstraps the first switch that installs nh
  if command -v nh >/dev/null; then
    nh os switch . -H laptop
  else
    sudo nixos-rebuild switch --flake .#laptop
  fi
