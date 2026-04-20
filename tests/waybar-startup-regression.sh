#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$REPO_ROOT/home/scripts/switch-profile"
TMPDIR=$(mktemp -d)
HOME_DIR="$TMPDIR/home"
BIN_DIR="$TMPDIR/bin"
CALLS_LOG="$TMPDIR/calls.log"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

write_stub() {
  local name="$1"
  local exit_code="${2:-0}"

  cat > "$BIN_DIR/$name" <<EOF
#!/usr/bin/env bash
exit $exit_code
EOF
  chmod +x "$BIN_DIR/$name"
}

write_logging_stub() {
  local name="$1"

  cat > "$BIN_DIR/$name" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$name" >> "$CALLS_LOG"
exit 0
EOF
  chmod +x "$BIN_DIR/$name"
}

mkdir -p \
  "$BIN_DIR" \
  "$HOME_DIR/.config/desktop-profiles/gruvbox"

write_stub systemctl
write_stub pkill
write_stub pgrep 1
write_stub niri
write_stub gsettings
write_stub swww
write_stub notify-send
write_logging_stub waybar
write_logging_stub mako

printf 'gruvbox\n' > "$HOME_DIR/.config/desktop-profiles/active"
printf 'light\n' > "$HOME_DIR/.config/desktop-profiles/active-variant"
printf '{"bar":"waybar","cursor":"Bibata Modern Ice","cursorSize":24}\n' \
  > "$HOME_DIR/.config/desktop-profiles/gruvbox/meta.json"
printf '/wallpapers/dark\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/wallpaper-dir"
printf '/wallpapers/light\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/wallpaper-dir-light"
printf 'layout {}\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/niri-overrides.kdl"
printf '{"layer":"top"}\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-config.jsonc"
printf '* { color: #ebdbb2; }\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-style.css"
printf '* { color: #3c3836; }\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-style-light.css"
printf 'anchor=top-right\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/mako-config"

PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" "$SCRIPT" --startup > "$TMPDIR/startup.log" 2>&1 || {
  cat "$TMPDIR/startup.log" >&2
  exit 1
}

if ! grep -qx 'waybar' "$CALLS_LOG"; then
  printf 'expected waybar to be launched during startup\n' >&2
  cat "$TMPDIR/startup.log" >&2
  exit 1
fi

if ! grep -qx 'mako' "$CALLS_LOG"; then
  printf 'expected mako to be launched during startup\n' >&2
  cat "$TMPDIR/startup.log" >&2
  exit 1
fi

if [ "$(cat "$HOME_DIR/.config/waybar/style.css")" != '* { color: #3c3836; }' ]; then
  printf 'expected startup to install the saved light waybar style\n' >&2
  exit 1
fi

if [ "$(cat "$HOME_DIR/.config/desktop-profiles/active")" != 'gruvbox' ]; then
  printf 'expected startup to preserve the active profile\n' >&2
  exit 1
fi

if [ "$(cat "$HOME_DIR/.config/desktop-profiles/active-variant")" != 'light' ]; then
  printf 'expected startup to preserve the active variant\n' >&2
  exit 1
fi
