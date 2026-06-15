default:
  @just --list

fmt:
  nix fmt

fmt-check:
  nix fmt -- --fail-on-change --no-cache

shell-check:
  shellcheck -S error home/scripts/*

wallpaper-script-check:
  bash checks/wallpaper-scripts.bash

qml-lint:
  nix shell nixpkgs#qt6.qtdeclarative -c qmllint \
    --import disable \
    --unqualified disable \
    --unresolved-type disable \
    --missing-property disable \
    --missing-type disable \
    --unresolved-alias disable \
    --max-warnings 0 \
    $(git ls-files '*.qml')

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
  just fmt-check
  just shell-check
  just wallpaper-script-check
  just flake-check
  just eval-all
  just check-profiles
  git diff --check

quick:
  just eval laptop
  git diff --check

update:
  nix flake update

build target="laptop":
  nix build --no-write-lock-file ".#nixosConfigurations.{{target}}.config.system.build.toplevel"

build-iso:
  nix build .#nixosConfigurations.iso.config.system.build.isoImage

dry:
  sudo nixos-rebuild dry-activate --flake .#laptop

switch:
  nh os switch . -H laptop
