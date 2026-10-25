# shellcheck shell=bash
# Sourced by checks/profile-transition.bash; shares its globals.
# Every previous/target bar pairing follows one bar policy. Target readiness is
# checked before preferences commit, and notification/wallpaper ownership tracks
# the target rather than the previous bar.
printf 'on\n' > "$profiles/focus"
qs_wallpaper_backups=()
for previous in qs noc; do
  case "$previous" in
    qs) previous_state=quickshell-started ;;
    noc) previous_state=noctalia-started ;;
  esac
  for target in qs noc; do
    printf '%s\n' "$previous" > "$profiles/active"
    printf 'dark\n' > "$profiles/active-variant"
    printf 'dark\n' > "$profiles/variant-$target"
    ln -sfn "$profiles/$previous/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
    printf '%s\n' "$previous_state" > "$bar_state"
    case "$previous" in
      qs) printf 'quickshell\n' > "$notification_state" ;;
      noc) printf 'noctalia\n' > "$notification_state" ;;
    esac
    if [ "$previous" = qs ] && [ "$target" = qs ]; then
      for wp_dir in "$profiles/qs/wallpapers" "$profiles/old/wallpapers"; do
        if [ -d "$wp_dir" ]; then
          wp_bak="$tmpdir/$(echo "$wp_dir" | tr '/' '-').bak"
          mv "$wp_dir" "$wp_bak"
          qs_wallpaper_backups+=("$wp_dir:$wp_bak")
        fi
      done
    fi
    : > "$log"
    HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
      BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
      "$REPO_ROOT/home/scripts/profile-transition" switch "$target"
    if [ "$previous" = qs ] && [ "$target" = qs ]; then
      for entry in "${qs_wallpaper_backups[@]}"; do
        wp_dir=${entry%%:*}
        wp_bak=${entry#*:}
        mv "$wp_bak" "$wp_dir"
      done
      qs_wallpaper_backups=()
    fi

    case "$previous" in
      qs)
        if [ "$target" = qs ]; then
          assert_log_not_contains "systemctl --user stop quickshell-bar.service" \
            "same-bar Quickshell switch leaves the topbar process running"
        else
          assert_log_contains "systemctl --user stop quickshell-bar.service" \
            "Quickshell exact topbar is stopped from $previous to $target"
        fi
        ;;
      noc) assert_log_contains 'systemctl --user stop noctalia-shell' \
        "Noctalia is stopped from $previous to $target" ;;
    esac
    case "$target" in
      qs)
        assert_log_contains "systemctl --user is-active --quiet quickshell-bar.service" \
          "Quickshell readiness uses the exact topbar from $previous"
        if [ "$previous" = qs ]; then
          assert_log_not_contains 'systemctl --user start awww' \
            "same-bar Quickshell does not re-run start_bar awww from $previous"
        else
          assert_log_contains 'systemctl --user start awww' "Quickshell starts awww from $previous"
          assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
            "Quickshell verifies notification ownership from $previous"
        fi
        ;;
      noc)
        assert_log_contains 'systemctl --user is-active --quiet noctalia-shell' \
          "Noctalia readiness uses systemctl from $previous"
        assert_log_contains 'systemctl --user stop awww' "Noctalia stops awww from $previous"
        assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
          "Noctalia verifies notification ownership from $previous"
        ;;
    esac
  done
done

cp -a "$profiles/qs" "$profiles/qs2"
"$real_jq" '.name = "qs2"' "$profiles/qs2/manifest.json" \
  > "$profiles/qs2/manifest.json.tmp"
mv "$profiles/qs2/manifest.json.tmp" "$profiles/qs2/manifest.json"
printf '{"payload":"qs2-dark"}\n' > "$profiles/qs2/quickshell-theme.json"
printf '{"payload":"qs2-light"}\n' > "$profiles/qs2/quickshell-theme-light.json"
printf 'qs\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs2"
ln -sfn "$profiles/qs/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell-started\n' > "$bar_state"
printf 'quickshell\n' > "$notification_state"
: > "$log"
rm -f "$profiles/quickshell-theme-reload"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" NOTIFICATION_STATE="$notification_state" \
  REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs2
assert_eq "qs2" "$(cat "$profiles/active")" "same-bar switch commits qs2"
assert_log_not_contains "systemctl --user stop quickshell-bar.service" \
  "qs→qs2 does not kill Quickshell"
[ -s "$profiles/quickshell-theme-reload" ] \
  || { printf 'FAIL: same-bar switch did not nudge quickshell-theme-reload\n' >&2; exit 1; }
assert_pending_cleared "same-bar switch"
assert_selector_ignores_frozen_env '{"payload":"qs2-dark"}' qs dark \
  "same-bar switch selector follows committed qs2, not the launch-time identity"

assert_eq 'gtk-old-dark' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "core GTK color file is installed"
assert_mode 644 "$home/.config/gtk-3.0/noctalia.css" "GTK color file remains writable"
assert_log_not_contains 'apply_vicinae' "core staging excludes best-effort application adapters"

# Pending Quickshell identity is read from transition files, not process env.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-qs"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'stopped\n' > "$bar_state"
printf 'none\n' > "$notification_state"
printf '{"payload":"qs-runtime-dark"}\n' > "$profiles/runtime-quickshell-theme.json"
printf 'qs\n' > "$profiles/runtime-theme-profile"
rm -f "$profiles/runtime-theme-variant"
printf 'qs\n' > "$profiles/transition-target"
printf 'dark\n' > "$profiles/transition-variant"
assert_eq '{"payload":"qs-dark"}' \
  "$(HOME="$home" XDG_CONFIG_HOME="$home/.config" "$PROFILE_THEME_SELECTOR")" \
  "an untagged legacy runtime override falls back to the baked dark theme"
rm -f "$profiles/transition-target" "$profiles/transition-variant"
# Task 12 presentation-split contract: pending/runtime Quickshell theme selection
# and InfoPopup lifecycle semantics stay the source of truth (do not edit InfoPopup).
rg -q 'runtime-quickshell-theme.json' "$REPO_ROOT/home/scripts/select-quickshell-theme" \
  || { printf 'FAIL: select-quickshell-theme lost runtime theme preference\n' >&2; exit 1; }
rg -q 'transition-target' "$REPO_ROOT/home/scripts/select-quickshell-theme" \
  || { printf 'FAIL: select-quickshell-theme lost pending transition target preference\n' >&2; exit 1; }
if rg -q 'DESKTOP_PROFILE_TRANSITION_TARGET' \
  "$REPO_ROOT/home/scripts/select-quickshell-theme" \
  "$REPO_ROOT/home/scripts/profile-transition"; then
  printf 'FAIL: pending Quickshell identity is still pinned in the process environment\n' >&2
  exit 1
fi
for lifecycle in 'property bool shown: false' 'readonly property bool active:' 'readonly property bool mapped:' 'property bool warming: false' 'property bool ready: false'; do
  rg -F -q "$lifecycle" "$REPO_ROOT/home/configs/quickshell/InfoPopup.qml" \
    || { printf 'FAIL: InfoPopup.qml missing lifecycle contract: %s\n' "$lifecycle" >&2; exit 1; }
done
printf 'dark\n' > "$profiles/runtime-theme-variant"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs
assert_eq quickshell "$(cat "$notification_state")" \
  "Quickshell claims notification ownership after start"
assert_log_contains \
  "start-quickshell active=old active_variant=dark theme=qs theme_variant=light selected={\"payload\":\"qs-light\"}" \
  "Quickshell selects the pending light payload instead of the stale dark runtime override"
assert_pending_cleared "Quickshell pending-identity switch"

printf 'qs\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs"
ln -sfn "$profiles/qs/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell-started\n' > "$bar_state"
printf 'quickshell\n' > "$notification_state"
: > "$log"
rm -f "$profiles/quickshell-theme-reload"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" NOTIFICATION_STATE="$notification_state" \
  REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
  "$REPO_ROOT/home/scripts/profile-transition" variant light
assert_eq light "$(cat "$profiles/active-variant")" \
  "Quickshell variant toggle commits light"
assert_log_not_contains "systemctl --user stop quickshell-bar.service" \
  "Quickshell variant toggle does not kill the topbar"
assert_log_not_contains \
  "systemctl --user start quickshell-bar.service" \
  "Quickshell variant toggle does not relaunch via start_bar"
[ -s "$profiles/quickshell-theme-reload" ] \
  || { printf 'FAIL: variant toggle did not nudge quickshell-theme-reload\n' >&2; exit 1; }
assert_pending_cleared "variant toggle"
assert_selector_ignores_frozen_env '{"payload":"qs-light"}' qs dark \
  "variant toggle selector follows committed light, not the launch-time variant"

printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs"
printf 'stopped\n' > "$bar_state"
printf 'none\n' > "$notification_state"
printf '0\n' > "$tmpdir/start-count"
rm -f "$profiles/quickshell-theme-reload"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" NOTIFICATION_STATE="$notification_state" \
  REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_VERIFY_ATTEMPTS=5 \
  START_COUNT_FILE="$tmpdir/start-count" FAIL_FIRST_BAR_START=1 \
  "$REPO_ROOT/home/scripts/profile-transition" variant light >/dev/null 2>&1; then
  printf 'FAIL: Quickshell variant transition committed despite readiness failure\n' >&2
  exit 1
fi
assert_eq qs "$(cat "$profiles/active")" \
  "Quickshell rollback preserves the old active profile"
assert_eq dark "$(cat "$profiles/active-variant")" \
  "Quickshell rollback preserves the old active variant"
assert_log_contains "systemctl --user stop quickshell-bar.service" \
  "unhealthy same-bar Quickshell is stopped before restart fallback"
assert_log_contains \
  "start-quickshell active=qs active_variant=dark theme=qs theme_variant=dark selected={\"payload\":\"qs-runtime-dark\"}" \
  "Quickshell rollback restarts the old dark runtime theme"
assert_pending_cleared "Quickshell variant rollback"

# A ready bar process is insufficient when its notification owner is absent.
printf 'noc\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'noctalia-started\n' > "$bar_state"
printf 'noctalia\n' > "$notification_state"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_VERIFY_ATTEMPTS=5 FAIL_NOTIFICATION_OWNER=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs >/dev/null 2>&1; then
  printf 'FAIL: transition committed Quickshell without its notification owner\n' >&2
  exit 1
fi
assert_eq noc "$(cat "$profiles/active")" \
  "notification ownership failure rolls back active profile"
