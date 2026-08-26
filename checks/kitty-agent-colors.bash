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

# Dark clean-style: Agent mixes + Codex/OpenCode/Claude. Composer gray is transparent.
got="$(python3 "$HELPER" --background '#131415' --print)"
assert_eq "$got" '#1f2021 #292a30 #2f3031 #222325 #0a0a0a #373737 #262626' \
  "dark #131415 Agent mixes plus Codex pill plus OpenCode plus Claude fills"

# Light: Agent tints, then Codex black@0.04, OpenCode panel, Claude tokens.
got="$(python3 "$HELPER" --background '#eceff4' --print)"
assert_eq "$got" '#e5e7eb #d8dadd #e2e5ea #dcdfe3 #ffffff #f0f0f0 #f5f5f5' \
  "light #eceff4 Agent mixes plus Codex pill plus OpenCode plus Claude fills"

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
assert_eq "$got" '#1f2021 #292a30 #2f3031 #222325 #0a0a0a #373737 #262626' \
  "profile-common sync_kitty_agent_transparent_colors"

# Glass opencode theme: derived from kitty palette, composer transparent so the
# fg-drawn half-block band vanishes. Also flips kv theme system->glass.
export XDG_CONFIG_HOME="$tmpdir/xdg-config"
export XDG_STATE_HOME="$tmpdir/xdg-state"
mkdir -p "$tmpdir/theme-live/.config/kitty"
cat > "$tmpdir/theme-live/.config/kitty/colors.conf" <<'EOF'
background #131415
foreground #f2f2f2
color0  #1e2022
color1  #e3e5e7
color2  #c6c8ca
color3  #c6c8ca
color4  #c6c8ca
color5  #c6c8ca
color6  #c6c8ca
color7  #f2f2f2
color8  #5a5f64
color9  #e3e5e7
color10 #f2f2f2
color11 #f2f2f2
color12 #f2f2f2
color13 #f2f2f2
color14 #f2f2f2
color15 #f4f5f5
EOF
printf 'background_opacity 0.4\n' > "$tmpdir/theme-live/.config/kitty/kitty.conf"
mkdir -p "$XDG_STATE_HOME/opencode"
printf '{"theme":"system","sidebar":"auto"}\n' > "$XDG_STATE_HOME/opencode/kv.json"
XDG_CONFIG_HOME="$tmpdir/theme-live/.config" XDG_STATE_HOME="$XDG_STATE_HOME" python3 "$HELPER" "$tmpdir/theme-live/.config/kitty"
if [ ! -f "$tmpdir/theme-live/.config/opencode/themes/glass.json" ]; then
  echo "FAIL: glass theme not written" >&2; exit 1
fi
got_panel="$(python3 -c "import json;print(json.load(open('$tmpdir/theme-live/.config/opencode/themes/glass.json'))['theme']['backgroundPanel'])")"
assert_eq "$got_panel" '#222325' "glass theme backgroundPanel grays[2]"
got_elem="$(python3 -c "import json;print(json.load(open('$tmpdir/theme-live/.config/opencode/themes/glass.json'))['theme']['backgroundElement'])")"
assert_eq "$got_elem" 'transparent' "glass theme backgroundElement transparent (band gone)"
got_menu="$(python3 -c "import json;print(json.load(open('$tmpdir/theme-live/.config/opencode/themes/glass.json'))['theme']['backgroundMenu'])")"
assert_eq "$got_menu" '#222325' "glass theme backgroundMenu mirrors panel"
got_kv="$(python3 -c "import json;print(json.load(open('$XDG_STATE_HOME/opencode/kv.json'))['theme'])")"
assert_eq "$got_kv" 'glass' "kv theme system->glass"

echo "OK: kitty-agent-colors.bash"
