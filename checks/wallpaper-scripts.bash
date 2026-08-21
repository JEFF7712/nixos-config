#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_ROOT/home/scripts/profile-common"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir" || true' EXIT

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
assert_eq 'post_command = $HOME/.local/bin/waypaper-backend-sync' \
  "$(awk -F' = ' '$1 == "post_command" { print }' "$tmpdir/waypaper.ini")" \
  "waypaper post command does not pass the wallpaper through the shell"

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
cat > "$profiles_dir/tinted/niri-overrides.kdl" <<'EOF'
layout { gaps 8; }
focus-ring {
    active-color "#b1c6ff"
}
border {
    width 2
    active-color "#ffffff"
    inactive-color "#000000"
}
EOF

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
PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" apply_wallpaper_theme "$tmpdir/still.png"

assert_eq tinted "$(cat "$profiles_dir/runtime-theme-profile")" \
  "wallpaper tint tags the runtime theme profile"
assert_eq light "$(cat "$profiles_dir/runtime-theme-variant")" \
  "wallpaper tint tags the runtime theme variant"
assert_eq "spicetify $profiles_dir/tinted/manifest.json light" \
  "$(grep '^spicetify ' "$log_file")" \
  "wallpaper tint reapplies the active profile spicetify scheme"
if ! grep -Fq 'active-color "#d8915f"' "$profiles_dir/runtime-niri-active.kdl"; then
  printf 'FAIL: iris wallpaper tint did not rewrite the niri focus-ring to #d8915f\n' >&2
  cat "$profiles_dir/runtime-niri-active.kdl" >&2
  exit 1
fi
if grep -E '> "\$nout"' "$REPO_ROOT/home/scripts/profile-common"; then
  printf 'FAIL: niri override still truncates runtime-niri-active.kdl in place\n' >&2
  exit 1
fi
if ! grep -Fq '(apply_wallpaper_theme "$wallpaper") 9>&- &' "$REPO_ROOT/home/scripts/profile-common"; then
  printf 'FAIL: async wallpaper theme job does not close the transition lock fd\n' >&2
  exit 1
fi

cat > "$bin_dir/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    printf 'other\n' > "$STALE_ACTIVE"
    printf '{"fg":"#ffffff","bg":"#000000","accent":"#d8915f"}'
    ;;
  */iris-render.py)
    printf 'iris-render\n' >> "$COMMAND_LOG"
    cat >/dev/null
    ;;
esac
EOF
chmod +x "$bin_dir/iris-python"
rm -f "$profiles_dir/runtime-theme-profile" "$profiles_dir/runtime-niri-active.kdl"
: > "$log_file"
COMMAND_LOG="$log_file" STALE_ACTIVE="$profiles_dir/active" PATH="$bin_dir:$PATH" \
  apply_wallpaper_theme "$tmpdir/still.png"
assert_eq other "$(cat "$profiles_dir/active")" \
  "stale-job fixture switches the active profile during iris"
if [ -e "$profiles_dir/runtime-theme-profile" ]; then
  printf 'FAIL: stale theme job still wrote runtime-theme-profile\n' >&2
  exit 1
fi
if grep -Fq 'iris-render' "$log_file"; then
  printf 'FAIL: stale theme job still ran iris-render\n' >&2
  exit 1
fi
printf 'tinted\n' > "$profiles_dir/active"

cat > "$bin_dir/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    printf '999\n' > "$STALE_GEN"
    printf '{"fg":"#ffffff","bg":"#000000","accent":"#d8915f"}'
    ;;
  */iris-render.py)
    printf 'iris-render\n' >> "$COMMAND_LOG"
    cat >/dev/null
    ;;
esac
EOF
chmod +x "$bin_dir/iris-python"
rm -f "$profiles_dir/runtime-theme-profile"
: > "$log_file"
COMMAND_LOG="$log_file" STALE_GEN="$profiles_dir/theme-generation" PATH="$bin_dir:$PATH" \
  apply_wallpaper_theme "$tmpdir/still.png"
if [ -e "$profiles_dir/runtime-theme-profile" ]; then
  printf 'FAIL: superseded generation still wrote runtime-theme-profile\n' >&2
  exit 1
fi
if grep -Fq 'iris-render' "$log_file"; then
  printf 'FAIL: superseded generation still ran iris-render\n' >&2
  exit 1
fi

cat > "$bin_dir/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    printf '{"fg":"#ffffff","bg":"#000000","accent":"#d8915f"}'
    ;;
  */iris-render.py)
    printf 'iris-render\n' >> "$COMMAND_LOG"
    cat >/dev/null
    exit 1
    ;;
esac
EOF
chmod +x "$bin_dir/iris-python"
rm -f "$profiles_dir/runtime-theme-profile"
: > "$log_file"
set +e
COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" apply_wallpaper_theme "$tmpdir/still.png"
iris_status=$?
set -e
assert_eq 1 "$iris_status" "iris-render failure is not converted to success"
if [ -e "$profiles_dir/runtime-theme-profile" ]; then
  printf 'FAIL: failed iris-render still tagged runtime-theme-profile\n' >&2
  exit 1
fi

cat > "$bin_dir/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    printf '{"fg":"#ffffff","bg":"#000000"}'
    ;;
  */iris-render.py)
    cat >/dev/null
    ;;
esac
EOF
chmod +x "$bin_dir/iris-python"
rm -f "$profiles_dir/runtime-niri-active.kdl"
COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" apply_wallpaper_theme "$tmpdir/still.png"
if [ -e "$profiles_dir/runtime-niri-active.kdl" ]; then
  printf 'FAIL: iris JSON without accent still rewrote niri overrides\n' >&2
  exit 1
fi

touch "$tmpdir/seed.png"
ACCENT_CACHE="$tmpdir/accent-cache"
magick() { return 1; }
seed_color=$(matugen_source_color "$tmpdir/seed.png")
unset -f magick
assert_eq "#6c7a89" "$seed_color" \
  "histogram pipeline failure falls back to the documented pin"

themed_flag="$tmpdir/themed.flag"
rm -f "$themed_flag"
awww() {
  case "$*" in
    query) return 0 ;;
    *) return 1 ;;
  esac
}
apply_wallpaper_theme() { printf 'themed\n' > "$themed_flag"; }
set +e
set_wallpaper "$tmpdir/seed.png"
wallpaper_status=$?
set -e
unset -f awww apply_wallpaper_theme
assert_eq 1 "$wallpaper_status" "awww img failure is not converted to success"
if [ -e "$themed_flag" ]; then
  printf 'FAIL: wallpaper apply failure still ran theming\n' >&2
  exit 1
fi

apostrophe_wp="$tmpdir/o'reilly.png"
touch "$apostrophe_wp"
cat > "$config_dir/waypaper/config.ini" <<EOF
[Settings]
backend = awww
wallpaper = $apostrophe_wp
EOF
sync_profiles="$tmpdir/home/.config/desktop-profiles"
mkdir -p "$sync_profiles"
cp -a "$profiles_dir/." "$sync_profiles/"
cat > "$bin_dir/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    printf '{"fg":"#ffffff","bg":"#000000","accent":"#d8915f"}'
    ;;
  */iris-render.py)
    cat >/dev/null
    ;;
esac
EOF
chmod +x "$bin_dir/iris-python"
rm -f "$sync_profiles/runtime-theme-profile"
set +e
sync_err=$(
  COMMAND_LOG="$log_file" HOME="$tmpdir/home" XDG_CONFIG_HOME="$config_dir" \
    PATH="$bin_dir:$PATH" PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
    "$REPO_ROOT/home/scripts/waypaper-backend-sync" 2>&1
)
sync_status=$?
set -e
if [ "$sync_status" -ne 0 ]; then
  printf 'FAIL: waypaper-backend-sync exited %s for apostrophe wallpaper\n%s\n' \
    "$sync_status" "$sync_err" >&2
  exit 1
fi
assert_eq tinted "$(cat "$sync_profiles/runtime-theme-profile")" \
  "waypaper-backend-sync reads wallpaper = from config.ini without a shell argv"

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

# waypaper writes `wallpaper = ~/...` with a literal tilde. bash tilde-expands
# `case` PATTERNS, so an unquoted ~/* pattern silently never matched and iris
# received the literal path, breaking wallpaper theming entirely.
tilde_home="$tmpdir/tilde-home"
tilde_cfg="$tmpdir/tilde-home/.config"
tilde_bin="$tmpdir/tilde-bin"
mkdir -p "$tilde_home/pics" "$tilde_cfg/waypaper" "$tilde_bin"
: > "$tilde_home/pics/wave.png"

cat > "$tilde_bin/iris-python" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  */iris.py)
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--wallpaper" ]; then printf '%s\n' "$2" > "$TILDE_ARG_LOG"; fi
      shift
    done
    printf '{"fg":"#ffffff","bg":"#000000","surface":"#111111","dim":"#999999","accent":"#d8915f","red":"#ff0000","green":"#00ff00","yellow":"#ffff00"}'
    ;;
  */iris-render.py) cat >/dev/null ;;
esac
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$tilde_bin/systemctl"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tilde_bin/pkill"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tilde_bin/niri"
chmod +x "$tilde_bin/iris-python" "$tilde_bin/systemctl" "$tilde_bin/pkill" "$tilde_bin/niri"

mkdir -p "$tilde_cfg/desktop-profiles/tinted"
printf 'tinted\n' > "$tilde_cfg/desktop-profiles/active"
printf 'dark\n' > "$tilde_cfg/desktop-profiles/active-variant"
printf '{"capabilities":{"colorEngine":"iris","wallpaperTheming":true},"artifacts":{}}\n' \
  > "$tilde_cfg/desktop-profiles/tinted/manifest.json"

cat > "$tilde_cfg/waypaper/config.ini" <<'EOF'
[Settings]
backend = awww
wallpaper = ~/pics/wave.png
EOF

TILDE_ARG_LOG="$tmpdir/tilde-arg" \
  HOME="$tilde_home" XDG_CONFIG_HOME="$tilde_cfg" PATH="$tilde_bin:$PATH" \
  "$REPO_ROOT/home/scripts/waypaper-backend-sync" >/dev/null 2>&1 || true

assert_eq "$tilde_home/pics/wave.png" "$(cat "$tmpdir/tilde-arg" 2>/dev/null || true)" \
  "waypaper-backend-sync expands a leading tilde from config.ini"

printf 'OK: wallpaper-scripts.bash\n'
