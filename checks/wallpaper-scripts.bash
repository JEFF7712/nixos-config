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

cat > "$tmpdir/waypaper.ini" <<'EOF'
[Settings]
post_command =
EOF
ensure_waypaper_post_command "$tmpdir/waypaper.ini"
assert_eq 'post_command = $HOME/.local/bin/waypaper-backend-sync $wallpaper' \
  "$(awk -F' = ' '$1 == "post_command" { print }' "$tmpdir/waypaper.ini")" \
  "waypaper post command uses an absolute home-relative script path"

bin_dir="$tmpdir/bin"
config_dir="$tmpdir/config"
log_file="$tmpdir/commands.log"
mkdir -p "$bin_dir" "$config_dir/waypaper"

cat > "$bin_dir/pkill" <<'EOF'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >> "$COMMAND_LOG"
EOF
cat > "$bin_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$COMMAND_LOG"
EOF
chmod +x "$bin_dir/pkill" "$bin_dir/systemctl"

cat > "$config_dir/waypaper/config.ini" <<'EOF'
[Settings]
backend = awww
EOF

COMMAND_LOG="$log_file" XDG_CONFIG_HOME="$config_dir" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/waypaper-backend-sync" "$tmpdir/still.png"

assert_eq $'pkill -f /[m]pvpaper( |$)\nsystemctl --user start awww' \
  "$(cat "$log_file")" \
  "waypaper awww backend stops mpvpaper and starts awww"
