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
cat > "$bin_dir/tmux" <<'EOF'
#!/usr/bin/env bash
printf 'tmux %s\n' "$*" >> "$COMMAND_LOG"
EOF
cat > "$bin_dir/niri" <<'EOF'
#!/usr/bin/env bash
printf 'niri %s\n' "$*" >> "$COMMAND_LOG"
EOF
chmod +x "$bin_dir/pkill" "$bin_dir/systemctl" "$bin_dir/tmux" "$bin_dir/niri"

cat > "$config_dir/waypaper/config.ini" <<'EOF'
[Settings]
backend = awww
EOF

mkdir -p "$tmpdir/home"
COMMAND_LOG="$log_file" HOME="$tmpdir/home" XDG_CONFIG_HOME="$config_dir" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/waypaper-backend-sync" "$tmpdir/still.png"

assert_eq $'pkill -f /[m]pvpaper( |$)\nsystemctl --user start awww' \
  "$(cat "$log_file")" \
  "waypaper awww backend stops mpvpaper and starts awww"

profiles_dir="$tmpdir/profiles"
mkdir -p "$profiles_dir/tinted"
printf 'tinted\n' > "$profiles_dir/active"
printf 'light\n' > "$profiles_dir/active-variant"
printf '{"schemaVersion":1,"name":"tinted","capabilities":{"wallpaperTheming":true,"colorEngine":"iris"},"variants":{"light":{"adapters":{}}}}\n' \
  > "$profiles_dir/tinted/manifest.json"

PROFILES_DIR="$profiles_dir"
ACTIVE_FILE="$profiles_dir/active"
VARIANT_FILE="$profiles_dir/active-variant"
ACTIVE_LINK="$profiles_dir/active-niri-overrides.kdl"
FOCUS_FILE="$profiles_dir/focus"
CONFIG_HOME="$config_dir"

cat > "$bin_dir/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    printf '{"fg":"#ffffff","bg":"#000000","surface":"#111111","dim":"#999999","accent":"#d8915f","red":"#ff0000","green":"#00ff00","yellow":"#ffff00"}'
    ;;
  */iris-render.py)
    cat >/dev/null
    ;;
esac
EOF
chmod +x "$bin_dir/iris-python"

matugen_frame() { printf '%s\n' "$1"; }
profile_bar() { printf 'none\n'; }
nudge_gtk_reload() { :; }
apply_spicetify_theme() {
  printf 'spicetify %s %s\n' "$1" "$2" >> "$COMMAND_LOG"
}

: > "$log_file"
COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" apply_wallpaper_theme "$tmpdir/still.png"

assert_eq tinted "$(cat "$profiles_dir/runtime-theme-profile")" \
  "wallpaper tint tags the runtime theme profile"
assert_eq light "$(cat "$profiles_dir/runtime-theme-variant")" \
  "wallpaper tint tags the runtime theme variant"
assert_eq "spicetify $profiles_dir/tinted/manifest.json light" \
  "$(grep '^spicetify ' "$log_file")" \
  "wallpaper tint reapplies the active profile spicetify scheme"

# nudge_gtk_reload must restore settings.ini's theme, not a stuck Adwaita sentinel.
nudge_home="$tmpdir/nudge-home"
mkdir -p "$nudge_home/.config/gtk-3.0" "$nudge_home/bin"
printf '[Settings]\ngtk-theme-name=adw-gtk3-dark\n' > "$nudge_home/.config/gtk-3.0/settings.ini"
cat > "$nudge_home/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
state_file="${NUDGE_GS_STATE:?}"
case "$1" in
  get)
    if [ -f "$state_file" ]; then
      printf "'%s'\n" "$(cat "$state_file")"
    else
      printf "'Adwaita'\n"
    fi
    ;;
  set)
    # gsettings set SCHEMA KEY VALUE
    printf '%s\n' "$4" > "$state_file"
    printf 'set %s\n' "$4" >> "${NUDGE_GS_LOG:?}"
    ;;
esac
EOF
chmod +x "$nudge_home/bin/gsettings"
# Stuck mid-nudge: live gsettings is Adwaita while settings.ini wants adw-gtk3-dark.
printf 'Adwaita\n' > "$tmpdir/nudge-gs-state"
: > "$tmpdir/nudge-gs-log"
# Re-bind the real helper (wallpaper fixture stubs it above).
unset -f nudge_gtk_reload
# shellcheck disable=SC1091
. "$REPO_ROOT/home/scripts/profile-common"
HOME="$nudge_home" XDG_CONFIG_HOME="$nudge_home/.config" \
  PATH="$nudge_home/bin:$PATH" \
  NUDGE_GS_STATE="$tmpdir/nudge-gs-state" \
  NUDGE_GS_LOG="$tmpdir/nudge-gs-log" \
  nudge_gtk_reload
assert_eq "adw-gtk3-dark" "$(cat "$tmpdir/nudge-gs-state")" \
  "nudge_gtk_reload restores gtk-theme from settings.ini after a stuck Adwaita sentinel"
assert_eq $'set Adwaita\nset adw-gtk3-dark' "$(cat "$tmpdir/nudge-gs-log")" \
  "nudge_gtk_reload flips through Adwaita then back to the settings.ini theme"
