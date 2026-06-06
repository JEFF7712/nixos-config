default:
  @just --list

fmt:
  nix fmt

shell-check:
  bash -n home/scripts/profile-common home/scripts/switch-profile home/scripts/toggle-variant home/scripts/rofi-profile

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
  sudo nixos-rebuild switch --flake .#laptop
