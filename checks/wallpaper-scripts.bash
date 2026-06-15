#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_ROOT/home/scripts/profile-common"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_eq() {
  local expected="$1" actual="$2" label="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

touch "$tmpdir/clip.mp4"
assert_eq "$tmpdir/clip.mp4" "$(pick_random_wallpaper "$tmpdir")" "video wallpapers are selectable"
assert_eq "video" "$(wallpaper_backend "$tmpdir/clip.mp4")" "mp4 uses video backend"

rm "$tmpdir/clip.mp4"
touch "$tmpdir/still.png"
assert_eq "$tmpdir/still.png" "$(pick_random_wallpaper "$tmpdir")" "image wallpapers stay selectable"
assert_eq "image" "$(wallpaper_backend "$tmpdir/still.png")" "png uses image backend"

rm "$tmpdir/still.png"
touch "$tmpdir/notes.txt"
assert_eq "" "$(pick_random_wallpaper "$tmpdir")" "unsupported files are ignored"
