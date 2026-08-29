#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

theme=pkgs/plymouth-nixos-logo/default.nix

for callback in \
  SetDisplayPasswordFunction \
  SetDisplayNormalFunction \
  SetDisplayMessageFunction \
  SetHideMessageFunction; do
  if ! rg -q "Plymouth\.${callback}" "$theme"; then
    printf 'plymouth-theme: missing %s\n' "$callback" >&2
    exit 1
  fi
done

printf 'Plymouth theme checks passed.\n'
