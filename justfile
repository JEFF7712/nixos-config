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

check-profiles host="laptop" user="rupan":
  nix eval --no-write-lock-file --impure --json \
    ".#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.file" \
    --apply 'import ./checks/profiles.nix'

check:
  just shell-check
  just flake-check
  just eval-all
  just check-profiles
  git diff --check

update:
  nix flake update

build-iso:
  nix build .#nixosConfigurations.iso.config.system.build.isoImage

dry:
  sudo nixos-rebuild dry-activate --flake .#laptop

switch:
  nh os switch . -H laptop