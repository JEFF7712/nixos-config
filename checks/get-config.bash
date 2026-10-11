#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT
git init -q -b main "$tmpdir/upstream"
git -C "$tmpdir/upstream" config user.name Fixture
git -C "$tmpdir/upstream" config user.email fixture@example.invalid
printf 'baseline\n' > "$tmpdir/upstream/flake.nix"
git -C "$tmpdir/upstream" add flake.nix
git -C "$tmpdir/upstream" commit -qm baseline
export GET_CONFIG_URL="$tmpdir/upstream"
export GET_CONFIG_ASSETS_URL="$tmpdir/upstream"
export GET_CONFIG_TARGET_DIR="$tmpdir/config"
export GET_CONFIG_ASSETS_DIR="$tmpdir/assets"
mkdir "$GET_CONFIG_TARGET_DIR"
printf 'bundled fallback\n' > "$GET_CONFIG_TARGET_DIR/flake.nix"

if GET_CONFIG_URL="$tmpdir/missing" bash home/scripts/get-config > "$tmpdir/output" 2>&1; then
  printf 'failed clone was accepted\n' >&2
  exit 1
fi
[ "$(cat "$GET_CONFIG_TARGET_DIR/flake.nix")" = 'bundled fallback' ]
downloads=("$GET_CONFIG_TARGET_DIR".download.*)
[ ${#downloads[@]} -eq 0 ]

bash home/scripts/get-config > "$tmpdir/output" 2>&1
[ "$(cat "$GET_CONFIG_TARGET_DIR/flake.nix")" = baseline ]
backups=("$GET_CONFIG_TARGET_DIR".backup.*)
[ ${#backups[@]} -eq 1 ]
[ "$(cat "${backups[0]}/flake.nix")" = 'bundled fallback' ]

printf 'local edit\n' > "$GET_CONFIG_TARGET_DIR/flake.nix"
if bash home/scripts/get-config > "$tmpdir/output" 2>&1; then
  printf 'dirty checkout was accepted\n' >&2
  exit 1
fi
[ "$(cat "$GET_CONFIG_TARGET_DIR/flake.nix")" = 'local edit' ]
git -C "$GET_CONFIG_TARGET_DIR" checkout -- flake.nix
printf 'updated\n' > "$tmpdir/upstream/flake.nix"
git -C "$tmpdir/upstream" commit -qam updated
bash home/scripts/get-config > "$tmpdir/output" 2>&1
[ "$(cat "$GET_CONFIG_TARGET_DIR/flake.nix")" = updated ]

git -C "$GET_CONFIG_TARGET_DIR" config user.name Fixture
git -C "$GET_CONFIG_TARGET_DIR" config user.email fixture@example.invalid
printf 'local commit\n' > "$GET_CONFIG_TARGET_DIR/local"
git -C "$GET_CONFIG_TARGET_DIR" add local
git -C "$GET_CONFIG_TARGET_DIR" commit -qm local
printf 'divergent upstream\n' > "$tmpdir/upstream/flake.nix"
git -C "$tmpdir/upstream" commit -qam divergent
before=$(git -C "$GET_CONFIG_TARGET_DIR" rev-parse HEAD)
if bash home/scripts/get-config > "$tmpdir/output" 2>&1; then
  printf 'divergent checkout was accepted\n' >&2
  exit 1
fi
[ "$(git -C "$GET_CONFIG_TARGET_DIR" rev-parse HEAD)" = "$before" ]
printf 'get-config checks passed\n'
