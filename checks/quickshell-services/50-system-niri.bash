# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_system_service_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_system_service_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-system-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  for command in lock-screen systemctl; do
    ln -s "$audio_fixture_bin/$command" "$state_dir/fixture-bin/$command"
  done
  cp "$system_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/SystemService.qml" "$state_dir/config/services/SystemService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/SystemParser.js" "$state_dir/config/services/internal/SystemParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/SystemModel.qml" "$state_dir/config/services/internal/SystemModel.qml"
  : >"$state_dir/actions.log"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'system fixture did not become ready'
  wait_for_process "$qs_pid" 20 || rc=$?
  if ((rc != 0)); then
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "system fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and .sharedIdentity == true and
    (.diagnostics.available | type == "boolean") and
    (.diagnostics.cpuPercent | type == "number") and
    (.diagnostics.ramUsedGiB | type == "number") and
    (.diagnostics.ramPercent | type == "number") and
    (.diagnostics.diskPercent | type == "number") and
    (.diagnostics.hostName | type == "string") and
    (.diagnostics.kernel | type == "string") and
    (.diagnostics.uptime | type == "string" and . != "")' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'system fixture reported invalid state or action behavior'
  }
  [ "$(cat "$state_dir/actions.log")" = $'lock\nsystemctl suspend\nsystemctl reboot\nsystemctl poweroff' ] \
    || {
      cat "$state_dir/actions.log" >&2
      fail 'system fixture did not record exactly one command per action'
    }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'system fixture logged a binding or construction error'
    }
  jq -c '.diagnostics' "$state_dir/result.json"
}

run_niri_service_probe() {
  local state_dir qs_pid rc=0 record pid
  printf 'quickshell-services: run_niri_service_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-niri-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal" "$state_dir/processes"
  ln -s "$audio_fixture_bin/niri" "$state_dir/fixture-bin/niri"
  cp "$niri_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/NiriService.qml" "$state_dir/config/services/NiriService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/NiriParser.js" "$state_dir/config/services/internal/NiriParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/NiriModel.qml" "$state_dir/config/services/internal/NiriModel.qml"
  : >"$state_dir/actions.log"
  : >"$state_dir/niri-lifecycle.log"
  mkfifo "$state_dir/niri-event.fifo"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'niri fixture did not become ready'
  wait_for_process "$qs_pid" 25 || rc=$?
  if ((rc != 0)); then
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "niri fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and .sharedIdentity == true and
    .malformedEventIgnored == true and .actionsPassed == true and
    .retryTimingPassed == true and .exhaustionPassed == true and
    (.diagnostics.activeWorkspaceId | type == "number") and
    (.diagnostics.focusedTitle | type == "string") and
    (.diagnostics.focusedAppId | type == "string") and
    (.diagnostics.streamHealthy | type == "boolean") and
    (.diagnostics.lastError | type == "string")' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'niri fixture reported invalid state, action, or retry behavior'
  }
  [ ! -s "$state_dir/niri-overlap.log" ] \
    || fail 'niri fixture observed overlapping event-stream processes'
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'niri fixture logged a binding or construction error'
    }
  for record in "$state_dir"/processes/niri-stream.*.record; do
    [ -e "$record" ] || continue
    pid=$(record_value pid "$record")
    ! kill -0 "$pid" 2>/dev/null || fail 'niri event-stream process survived fixture exit'
  done
  [ ! -d "$state_dir/niri-stream.active" ] \
    || fail 'niri event-stream active marker survived fixture exit'
  jq -c . "$state_dir/result.json"
}
