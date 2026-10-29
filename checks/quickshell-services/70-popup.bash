# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_popup_only_composition_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_popup_only_composition_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'
  [ -n "${WAYLAND_DISPLAY:-}" ] || fail 'popup-only fixture requires WAYLAND_DISPLAY (PanelWindow has no offscreen backend)'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-popup-only.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config"
  cp -a "$repo_root/home/configs/quickshell/." "$state_dir/config/"
  cp "$popup_only_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  ln -s "$audio_fixture_bin/lock-screen" "$state_dir/fixture-bin/lock-screen"
  ln -s "$audio_fixture_bin/blueman-manager" "$state_dir/fixture-bin/blueman-manager"
  ln -s "$audio_fixture_bin/niri" "$state_dir/fixture-bin/niri"
  ln -s "$audio_fixture_bin/playerctl" "$state_dir/fixture-bin/playerctl"
  ln -s "$audio_fixture_bin/cava" "$state_dir/fixture-bin/cava"
  ln -s "$audio_fixture_bin/systemctl" "$state_dir/fixture-bin/systemctl"
  : >"$state_dir/actions.log"
  : >"$state_dir/blueman-calls.log"

  # PanelWindow needs a Wayland backend; offscreen cannot load InfoPopup.
  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=wayland \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 15; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'popup-only fixture did not become ready within fifteen seconds'
  fi
  wait_for_process "$qs_pid" 15 || rc=$?
  if ((rc != 0)); then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "popup-only fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and
    .diagnostics.audioOk == true and
    .diagnostics.networkOk == true and
    .diagnostics.bluetoothOk == true and
    .diagnostics.powerOk == true and
    .diagnostics.systemOk == true and
    .diagnostics.mediaOk == true and
    .diagnostics.brightnessOk == true' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'popup-only fixture reported invalid composition diagnostics'
  }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'popup-only fixture logged a binding or construction error'
    }
  [ "$(wc -l <"$state_dir/actions.log")" -eq 1 ] \
    || fail 'popup-only fixture did not record exactly one lock-screen launch'
  [ "$(wc -l <"$state_dir/blueman-calls.log")" -eq 1 ] \
    || fail 'popup-only fixture did not record exactly one blueman-manager launch'
  ! rg -n 'Topbar|NotifService|NotificationServer|NotificationsPopup|NotificationToasts' \
    "$popup_only_fixture_qml/shell.qml" \
    || fail 'popup-only fixture must not reference Topbar or the notification server'
  jq -c '.diagnostics' "$state_dir/result.json"
}
