# shellcheck shell=bash
# Sourced by checks/profile-transition.bash; shares its globals.
mkdir -p "$profiles" "$bin_dir" "$persistent_pid_dir"

for utility in awk bash basename cat chmod cp cut date dirname env find flock grep head install ln mkdir \
  mktemp mv paste readlink realpath rm rmdir sed seq sha256sum shuf sleep sort stat tail tar touch tr xargs; do
  utility_path=$(command -v "$utility")
  ln -s "$utility_path" "$bin_dir/$utility"
done

for profile in old new; do
  profile_dir="$profiles/$profile"
  wallpaper_dir="$profile_dir/wallpapers"
  mkdir -p "$wallpaper_dir"
  printf '{"bar":"quickshell","selfThemed":false,"hasLightVariant":true,"cursor":"default","cursorSize":24}\n' \
    > "$profile_dir/meta.json"
  printf '{}\n' > "$profile_dir/runtime.json"
  printf 'old-or-new-dark\n' > "$profile_dir/kitty-colors.conf"
  printf 'old-or-new-light\n' > "$profile_dir/kitty-colors-light.conf"
  printf 'gtk-%s-dark\n' "$profile" > "$profile_dir/gtk-3.0.css"
  printf 'gtk-%s-light\n' "$profile" > "$profile_dir/gtk-3.0-light.css"
  printf 'gtk4-%s-dark\n' "$profile" > "$profile_dir/gtk-4.0.css"
  printf 'gtk4-%s-light\n' "$profile" > "$profile_dir/gtk-4.0-light.css"
  printf 'qt-%s-dark\n' "$profile" > "$profile_dir/qt6ct.conf"
  printf 'qt-%s-light\n' "$profile" > "$profile_dir/qt6ct-light.conf"
  printf 'rofi-%s-dark\n' "$profile" > "$profile_dir/rofi-theme.rasi"
  printf 'rofi-%s-light\n' "$profile" > "$profile_dir/rofi-theme-light.rasi"
  printf 'fish-%s-dark\n' "$profile" > "$profile_dir/fish-theme.fish"
  printf 'fish-%s-light\n' "$profile" > "$profile_dir/fish-theme-light.fish"
  printf 'starship-%s-dark\n' "$profile" > "$profile_dir/starship.toml"
  printf 'starship-%s-light\n' "$profile" > "$profile_dir/starship-light.toml"
  printf 'layout { gaps 8; }\n' > "$profile_dir/niri-overrides.kdl"
  printf '{"payload":"%s-dark"}\n' "$profile" > "$profile_dir/quickshell-theme.json"
  printf '{"payload":"%s-light"}\n' "$profile" > "$profile_dir/quickshell-theme-light.json"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir-light"
  touch "$wallpaper_dir/wallpaper.png"
done

for profile in old new; do
  "$real_jq" '.fonts = {ui: {family: "Fixture UI", size: 12}, mono: {family: "Fixture Mono", size: 15}}
    | .appearance = {gtkTheme: "fixture-dark", gtkThemeLight: "fixture-light", iconTheme: "fixture-icons-dark", iconThemeLight: "fixture-icons-light", kittyOpacity: 0.8}
    | .cursor = "fixture-cursor" | .cursorSize = 28' \
    "$profiles/$profile/meta.json" > "$profiles/$profile/meta.json.tmp"
  mv "$profiles/$profile/meta.json.tmp" "$profiles/$profile/meta.json"
  wallpaper_dir="$profiles/$profile/wallpapers"
  "$real_jq" -n --arg name "$profile" --arg wallpaper "$wallpaper_dir" '
    {
      schemaVersion: 1,
      name: $name,
      capabilities: {
        selfThemed: false, wallpaperTheming: false, colorEngine: "matugen",
        matugenScheme: "scheme-tonal-spot", wallpaperAccentVivid: false,
        obsidianWallpaperTheme: false
      },
      transition: {
        defaultBar: "quickshell",
        cursor: {theme: "fixture-cursor", size: 28},
        fonts: {ui: {family: "Fixture UI", size: 12}, mono: {family: "Fixture Mono", size: 15}},
        appearance: {gtkTheme: "fixture-dark", gtkThemeLight: "fixture-light", iconTheme: "fixture-icons-dark", iconThemeLight: "fixture-icons-light", kittyOpacity: 0.8}
      },
      variants: {
        dark: {wallpaperDirectory: $wallpaper, adapters: {}, artifacts: {kitty: "kitty-colors.conf", gtk3: "gtk-3.0.css", gtk4: "gtk-4.0.css", qt6: "qt6ct.conf", rofi: "rofi-theme.rasi", fish: "fish-theme.fish", starship: "starship.toml"}},
        light: {wallpaperDirectory: $wallpaper, adapters: {}, artifacts: {kitty: "kitty-colors-light.conf", gtk3: "gtk-3.0-light.css", gtk4: "gtk-4.0-light.css", qt6: "qt6ct-light.conf", rofi: "rofi-theme-light.rasi", fish: "fish-theme-light.fish", starship: "starship-light.toml"}}
      },
      artifacts: {
        niri: {default: "niri-overrides.kdl", focus: "niri-overrides-focus.kdl"},
        quickshell: {dark: "quickshell-theme.json", light: "quickshell-theme-light.json"}
      }
    }' > "$profiles/$profile/manifest.json"
  rm "$profiles/$profile/meta.json" "$profiles/$profile/runtime.json" \
    "$profiles/$profile/wallpaper-dir" "$profiles/$profile/wallpaper-dir-light"
done

cp -a "$profiles/old" "$profiles/qs"
"$real_jq" '.name = "qs" | .transition.defaultBar = "quickshell"
  | .artifacts.quickshell = {dark: "quickshell-theme.json", light: "quickshell-theme-light.json"}' \
  "$profiles/qs/manifest.json" > "$profiles/qs/manifest.json.tmp"
mv "$profiles/qs/manifest.json.tmp" "$profiles/qs/manifest.json"
printf '{"payload":"qs-dark"}\n' > "$profiles/qs/quickshell-theme.json"
printf '{"payload":"qs-light"}\n' > "$profiles/qs/quickshell-theme-light.json"
cp -a "$profiles/old" "$profiles/noc"
"$real_jq" '.name = "noc" | .transition.defaultBar = "noctalia"
  | .capabilities.selfThemed = true | del(.variants.light)' \
  "$profiles/noc/manifest.json" > "$profiles/noc/manifest.json.tmp"
mv "$profiles/noc/manifest.json.tmp" "$profiles/noc/manifest.json"
cp -a "$profiles/noc" "$profiles/noctalia"
"$real_jq" '.name = "noctalia"' "$profiles/noctalia/manifest.json" \
  > "$profiles/noctalia/manifest.json.tmp"
mv "$profiles/noctalia/manifest.json.tmp" "$profiles/noctalia/manifest.json"
printf 'layout { gaps 4; }\n' > "$profiles/noctalia/niri-overrides-focus.kdl"
for profile in old new qs noc; do
  printf 'layout { gaps 4; }\n' > "$profiles/$profile/niri-overrides-focus.kdl"
done

mkdir -p "$home/.config/gtk-3.0" "$home/.config/gtk-4.0" \
  "$home/.config/qt5ct/colors" "$home/.config/qt6ct/colors" "$home/.config/kitty"
printf '[Settings]\ngtk-font-name=Old 9\ngtk-theme-name=old-theme\ngtk-cursor-theme-name=old-cursor\n' \
  > "$home/.config/gtk-3.0/settings.ini"
cp "$home/.config/gtk-3.0/settings.ini" "$home/.config/gtk-4.0/settings.ini"
printf 'font_family family="Old Mono"\nfont_size 9\nbackground_opacity 1.0\n' \
  > "$home/.config/kitty/kitty.conf"
cp "$profiles/old/gtk-3.0.css" "$home/.config/gtk-3.0/noctalia.css"
cp "$profiles/old/gtk-4.0.css" "$home/.config/gtk-4.0/noctalia.css"
chmod 640 "$home/.config/gtk-3.0/noctalia.css"

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-old"
printf 'light\n' > "$profiles/variant-new"
ln -s "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell\n' > "$notification_state"

for command in systemctl niri quickshell gsettings notify-send busctl awww mpvpaper tmux kitty magick matugen noctalia-shell noctalia; do
  cat > "$bin_dir/$command" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$COMMAND_LOG"
if [ "$(basename "$0")" = gsettings ] && [ -n "${PROFILE_TRANSITION_GSETTINGS_ERROR:-}" ]; then
  printf 'gsettings: schema unavailable\nfull diagnostic line\n' >&2
  exit 1
fi
case "$(basename "$0") $*" in
  "systemctl --user is-active"*) printf 'active\n' ;;
esac
EOF
done

cat > "$bin_dir/niri" <<'EOF'
#!/usr/bin/env bash
printf 'niri %s\n' "$*" >> "$COMMAND_LOG"
if [ "$*" = 'msg outputs' ]; then
  printf 'Output "eDP-1" (eDP-1)\n'
fi
if [ -n "${NIRI_COUNT_FILE:-}" ]; then
  count=$(cat "$NIRI_COUNT_FILE" 2>/dev/null || echo 0)
  count=$((count + 1))
  printf '%s\n' "$count" > "$NIRI_COUNT_FILE"
  if [ -n "${FAIL_FIRST_NIRI:-}" ] && [ "$count" -eq 1 ]; then
    exit 17
  fi
  if [ -n "${FAIL_SECOND_NIRI:-}" ] && [ "$count" -eq 2 ]; then
    exit 1
  fi
fi
EOF

cat > "$bin_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$COMMAND_LOG"
case " $* " in
  *" stop noctalia-shell "*)
    if [ -n "${SYSTEMCTL_COUNT_FILE:-}" ]; then
      count=$(cat "$SYSTEMCTL_COUNT_FILE" 2>/dev/null || echo 0)
      count=$((count + 1))
      printf '%s\n' "$count" > "$SYSTEMCTL_COUNT_FILE"
    fi
    if ! { [ -n "${IGNORE_FIRST_NOCTALIA_STOP:-}" ] && [ "${count:-0}" -eq 1 ]; }; then
      printf 'stopped\n' > "$BAR_STATE"
      [ "$(cat "$NOTIFICATION_STATE")" != noctalia ] || printf 'none\n' > "$NOTIFICATION_STATE"
    fi
    ;;
  *" start noctalia-shell "*)
    printf 'noctalia-started\n' > "$BAR_STATE"
    [ -n "${FAIL_NOTIFICATION_OWNER:-}" ] || printf 'noctalia\n' > "$NOTIFICATION_STATE"
    ;;
  *" is-active --quiet noctalia-shell "*)
    if [ "$(cat "$BAR_STATE")" = "noctalia-started" ]; then
      active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
      printf 'verify-noctalia active=%s\n' "$active" >> "$COMMAND_LOG"
      exit 0
    fi
    exit 3
    ;;
  *" stop quickshell-bar.service "*)
    if [ -n "${PKILL_COUNT_FILE:-}" ]; then
      count=$(cat "$PKILL_COUNT_FILE" 2>/dev/null || echo 0)
      count=$((count + 1))
      printf '%s\n' "$count" > "$PKILL_COUNT_FILE"
    fi
    if ! { [ -n "${IGNORE_FIRST_BAR_STOP:-}" ] && [ "${count:-0}" -eq 1 ]; }; then
      printf 'stopped\n' > "$BAR_STATE"
      [ "$(cat "$NOTIFICATION_STATE")" != quickshell ] || printf 'none\n' > "$NOTIFICATION_STATE"
    fi
    ;;
  *" start quickshell-bar.service "*)
    if [ -n "${START_COUNT_FILE:-}" ]; then
      count=$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)
      count=$((count + 1))
      printf '%s\n' "$count" > "$START_COUNT_FILE"
    fi
    if ! { [ -n "${FAIL_FIRST_BAR_START:-}" ] && [ "${count:-0}" -eq 1 ]; }; then
      active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
      active_variant=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active-variant" 2>/dev/null || echo dark)
      theme_profile=$(cat "$XDG_CONFIG_HOME/desktop-profiles/transition-target" 2>/dev/null || true)
      [ -n "$theme_profile" ] || theme_profile=$active
      theme_variant=$(cat "$XDG_CONFIG_HOME/desktop-profiles/transition-variant" 2>/dev/null || true)
      [ -n "$theme_variant" ] || theme_variant=$active_variant
      selected=$("$PROFILE_THEME_SELECTOR")
      printf 'start-quickshell active=%s active_variant=%s theme=%s theme_variant=%s selected=%s\n' \
        "$active" "$active_variant" "$theme_profile" "$theme_variant" "$selected" >> "$COMMAND_LOG"
      printf 'quickshell-started\n' > "$BAR_STATE"
      [ -n "${FAIL_NOTIFICATION_OWNER:-}" ] || printf 'quickshell\n' > "$NOTIFICATION_STATE"
    fi
    ;;
  *" is-active --quiet quickshell-bar.service "*)
    if [ "$(cat "$BAR_STATE")" = quickshell-started ]; then
      active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
      printf 'verify-quickshell active=%s\n' "$active" >> "$COMMAND_LOG"
      exit 0
    fi
    exit 3
    ;;
esac
EOF

cat > "$bin_dir/pkill" <<'EOF'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >> "$COMMAND_LOG"
if [ -n "${PKILL_COUNT_FILE:-}" ]; then
  count=$(cat "$PKILL_COUNT_FILE" 2>/dev/null || echo 0)
  count=$((count + 1))
  printf '%s\n' "$count" > "$PKILL_COUNT_FILE"
fi
case " $* " in
  *" quickshell"*"quickshell/shell.qml"*)
    if ! { [ -n "${IGNORE_FIRST_BAR_STOP:-}" ] && [ "${count:-0}" -eq 1 ]; }; then
      printf 'stopped\n' > "$BAR_STATE"
      [ "$(cat "$NOTIFICATION_STATE")" != quickshell ] || printf 'none\n' > "$NOTIFICATION_STATE"
    fi
    ;;
esac
EOF

cat > "$bin_dir/quickshell" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
active_variant=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active-variant" 2>/dev/null || echo dark)
theme_profile=$(cat "$XDG_CONFIG_HOME/desktop-profiles/transition-target" 2>/dev/null || true)
[ -n "$theme_profile" ] || theme_profile=$active
theme_variant=$(cat "$XDG_CONFIG_HOME/desktop-profiles/transition-variant" 2>/dev/null || true)
[ -n "$theme_variant" ] || theme_variant=$active_variant
selected=$("$PROFILE_THEME_SELECTOR")
printf 'quickshell %s active=%s active_variant=%s theme=%s theme_variant=%s selected=%s env_target=%s env_variant=%s\n' \
  "$*" "$active" "$active_variant" "$theme_profile" "$theme_variant" "$selected" \
  "${DESKTOP_PROFILE_TRANSITION_TARGET-}" "${DESKTOP_PROFILE_TRANSITION_VARIANT-}" >> "$COMMAND_LOG"
if [ -n "${START_COUNT_FILE:-}" ]; then
  count=$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)
  printf '%s\n' "$((count + 1))" > "$START_COUNT_FILE"
fi
child_file=""
if [ -n "${PROFILE_TRANSITION_TEST_POST_COMMIT:-}" ] \
  && [ -n "${FIXTURE_ADAPTER_CHILD_DIR:-}" ]; then
  mkdir -p "$FIXTURE_ADAPTER_CHILD_DIR"
  child_file="$FIXTURE_ADAPTER_CHILD_DIR/$$"
  printf '%s\n' "$*" > "$child_file"
  trap 'rm -f "$child_file"' EXIT
  sleep 0.1
fi
case "$*" in
  *quickshell-switcher/shell.qml*) exit 0 ;;
esac
if [ -z "${FAIL_NOTIFICATION_OWNER:-}" ]; then
  printf 'quickshell-started\n' > "$BAR_STATE"
  printf 'quickshell\n' > "$NOTIFICATION_STATE"
fi
if [ -n "${PERSISTENT_CHILDREN:-}" ]; then
  mkdir -p "$PERSISTENT_PID_DIR"
  pid_file="$PERSISTENT_PID_DIR/quickshell"
  printf '%s\n' "$$" > "$pid_file"
  trap 'rm -f "$pid_file"' EXIT
  sleep 5
fi
EOF

cat > "$bin_dir/awww" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf 'awww %s active=%s\n' "$*" "$active" >> "$COMMAND_LOG"
EOF

for command in matugen noctalia-shell noctalia; do
  cat > "$bin_dir/$command" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf '%s %s active=%s\n' "$(basename "$0")" "$*" "$active" >> "$COMMAND_LOG"
EOF
done

cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
state=$(cat "$BAR_STATE")
if [ -n "${FAIL_FIRST_BAR_START:-}" ] && [ "$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)" = 1 ]; then
  printf 'pgrep %s active=%s state=%s\n' "$*" "$active" "$state" >> "$COMMAND_LOG"
  exit 1
fi
case " $* :$state" in
  *" quickshell"*"quickshell/shell.qml"*:quickshell-started)
    printf 'pgrep %s\n' "$*" >> "$COMMAND_LOG"
    printf 'verify-quickshell active=%s\n' "$active" >> "$COMMAND_LOG"
    exit 0
    ;;
  *)
    printf 'pgrep %s active=%s state=%s\n' "$*" "$active" "$state" >> "$COMMAND_LOG"
    exit 1
    ;;
esac
EOF

cat > "$bin_dir/busctl" <<'EOF'
#!/usr/bin/env bash
printf 'busctl %s\n' "$*" >> "$COMMAND_LOG"
[ "$*" = '--user status org.freedesktop.Notifications' ] || exit 1
case "$(cat "$NOTIFICATION_STATE")" in
  quickshell) printf 'quickshell notification server\n' ;;
  noctalia) printf 'noctalia-shell notification server\n' ;;
  *) exit 1 ;;
esac
EOF

cat > "$bin_dir/jq" <<'EOF'
#!/usr/bin/env bash
printf 'jq %s\n' "$*" >> "$COMMAND_LOG"
exec "$REAL_JQ" "$@"
EOF

find "$bin_dir" -maxdepth 1 -type f -exec chmod +x {} +
