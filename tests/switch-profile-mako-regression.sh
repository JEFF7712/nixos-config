#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$REPO_ROOT/home/scripts/switch-profile"
TMPDIR=$(mktemp -d)
HOME_DIR="$TMPDIR/home"
BIN_DIR="$TMPDIR/bin"

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

mkdir -p \
  "$BIN_DIR" \
  "$HOME_DIR/.config/desktop-profiles/gruvbox" \
  "$HOME_DIR/nixos/home/configs/firefox/chrome/DownToneUI"

write_stub systemctl
write_stub pkill
write_stub pgrep 1
write_stub niri
write_stub gsettings
write_stub waybar
write_stub mako
write_stub notify-send

printf '{"bar":"waybar","cursor":"Bibata Modern Ice","cursorSize":24}\n' \
  > "$HOME_DIR/.config/desktop-profiles/gruvbox/meta.json"
printf '\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/wallpaper-dir"
printf 'layout {}\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/niri-overrides.kdl"
printf '{"layer":"top"}\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-config.jsonc"
printf '* { color: #ebdbb2; }\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-style.css"
printf 'anchor=top-right\n' > "$HOME_DIR/.config/desktop-profiles/gruvbox/mako-config"
chmod 444 \
  "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-config.jsonc" \
  "$HOME_DIR/.config/desktop-profiles/gruvbox/waybar-style.css" \
  "$HOME_DIR/.config/desktop-profiles/gruvbox/mako-config"

PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" "$SCRIPT" gruvbox > "$TMPDIR/first-run.log" 2>&1 || {
  cat "$TMPDIR/first-run.log" >&2
  exit 1
}

PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" "$SCRIPT" gruvbox > "$TMPDIR/second-run.log" 2>&1 || {
  cat "$TMPDIR/second-run.log" >&2
  exit 1
}

if [ "$(stat -c '%a' "$HOME_DIR/.config/waybar/config.jsonc")" != "644" ]; then
  printf 'expected writable waybar config, got mode %s\n' "$(stat -c '%a' "$HOME_DIR/.config/waybar/config.jsonc")" >&2
  exit 1
fi

if [ "$(stat -c '%a' "$HOME_DIR/.config/waybar/style.css")" != "644" ]; then
  printf 'expected writable waybar style, got mode %s\n' "$(stat -c '%a' "$HOME_DIR/.config/waybar/style.css")" >&2
  exit 1
fi

if [ "$(stat -c '%a' "$HOME_DIR/.config/mako/config")" != "644" ]; then
  printf 'expected writable mako config, got mode %s\n' "$(stat -c '%a' "$HOME_DIR/.config/mako/config")" >&2
  exit 1
fi
