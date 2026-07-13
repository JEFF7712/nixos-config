#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IFS=$'\t' read -r package_path package_drv < <(
  nix eval --json "$repo_root#nixosConfigurations.laptop.config.home-manager.users.rupan.home.packages" \
    --apply 'packages: builtins.map (package: [ (package.name or "") package.outPath package.drvPath ]) packages' \
    | jq -r '.[] | select(.[0] == "desktop-profile-gsettings") | [.[1], .[2]] | @tsv'
)

if [ -z "$package_path" ]; then
  printf 'FAIL: desktop-profile-gsettings is absent from the laptop Home Manager package set\n' >&2
  exit 1
fi

nix-store --realise "$package_drv" >/dev/null

output=$(
  env -u XDG_DATA_DIRS GSETTINGS_BACKEND=memory \
    "$package_path/bin/gsettings" get org.gnome.desktop.interface color-scheme
)

if [ "$output" != "'default'" ]; then
  printf 'FAIL: schema-aware gsettings returned %s\n' "$output" >&2
  exit 1
fi

printf 'profile gsettings check passed\n'
