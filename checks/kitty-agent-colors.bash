#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO_ROOT/home/scripts/sync-kitty-agent-colors"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_eq() {
  local got="$1" want="$2" label="$3"
  if [ "$got" != "$want" ]; then
    printf 'FAIL: %s\ngot:  %s\nwant: %s\n' "$label" "$got" "$want" >&2
    exit 1
  fi
}

# Dark clean-style background: Agent prompt/user, Codex pill, Claude fills.
got="$(python3 "$HELPER" --background '#131415' --print)"
assert_eq "$got" '#1f2021 #151515 #292a30 #242428 #2f3031 #373737 #262626' \
  "dark #131415 Agent mixes plus Codex pill plus Claude theme fills"

# Light background uses the light tints first, then Codex's black@0.04 blend,
# then Claude's light theme tokens.
got="$(python3 "$HELPER" --background '#eceff4' --print)"
assert_eq "$got" '#e5e7eb #f2f2f2 #d8dadd #e8e8e8 #e2e5ea #f0f0f0 #f5f5f5' \
  "light #eceff4 Agent mixes plus Codex pill plus Claude theme fills"

# No colors.conf / no background line: leave kitty.conf untouched.
mkdir -p "$tmpdir/empty"
printf 'background_opacity 0.4\nfont_size 14\n' > "$tmpdir/empty/kitty.conf"
python3 "$HELPER" "$tmpdir/empty"
if grep -q '^transparent_background_colors' "$tmpdir/empty/kitty.conf"; then
  echo "FAIL: missing colors.conf should not write transparent_background_colors" >&2
  cat "$tmpdir/empty/kitty.conf" >&2
  exit 1
fi

# Rewrite an existing line from colors.conf.
mkdir -p "$tmpdir/live"
printf 'background #2e3440\n' > "$tmpdir/live/colors.conf"
printf 'background_opacity 0.4\ntransparent_background_colors #000000\nenable_audio_bell no\n' \
  > "$tmpdir/live/kitty.conf"
python3 "$HELPER" "$tmpdir/live"
want="$(python3 "$HELPER" --background '#2e3440' --print)"
got="$(sed -n 's/^transparent_background_colors //p' "$tmpdir/live/kitty.conf")"
assert_eq "$got" "$want" "rewrites transparent_background_colors from colors.conf"
if ! grep -q '^enable_audio_bell no$' "$tmpdir/live/kitty.conf"; then
  echo "FAIL: surrounding kitty.conf keys were lost" >&2
  cat "$tmpdir/live/kitty.conf" >&2
  exit 1
fi

# profile-common helper: appearance apply remixes after opacity.
export HOME="$tmpdir/home"
mkdir -p "$HOME/.config/kitty"
printf 'background #131415\n' > "$HOME/.config/kitty/colors.conf"
printf 'background_opacity 1.0\ntransparent_background_colors #deadbe\n' \
  > "$HOME/.config/kitty/kitty.conf"
# shellcheck source=/dev/null
. "$REPO_ROOT/home/scripts/profile-common"
sync_kitty_agent_transparent_colors "$HOME/.config/kitty"
got="$(sed -n 's/^transparent_background_colors //p' "$HOME/.config/kitty/kitty.conf")"
assert_eq "$got" '#1f2021 #151515 #292a30 #242428 #2f3031 #373737 #262626' \
  "profile-common sync_kitty_agent_transparent_colors"

echo "OK: kitty-agent-colors.bash"
