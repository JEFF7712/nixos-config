# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_brightness_service_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_brightness_service_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-brightness-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  cat >"$state_dir/fixture-bin/monitor-brightness" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="${QS_TEST_STATE_DIR:?QS_TEST_STATE_DIR is required}"
printf '%s\n' "$*" >>"$state/calls.log"
case "${1:-}" in
  list)
    printf '[{"id":"internal","kind":"internal","label":"Laptop panel","percent":35},{"id":"ddc-1","kind":"ddc","display":1,"label":"LS24D300G","percent":50},{"id":"ddc-2","kind":"ddc","display":2,"label":"D3218HN","percent":65}]\n'
    ;;
  set)
    printf '%s %s\n' "${2:?}" "${3:?}" >>"$state/sets.log"
    sleep 0.3
    ;;
  *)
    echo "usage: monitor-brightness [list|set <id> <0-100>]" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$state_dir/fixture-bin/monitor-brightness"
  cp "$brightness_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/BrightnessService.qml" "$state_dir/config/services/BrightnessService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/BrightnessModel.qml" "$state_dir/config/services/internal/BrightnessModel.qml"
  : >"$state_dir/calls.log"
  : >"$state_dir/sets.log"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" \
    QS_BRIGHTNESS_HELPER="$state_dir/fixture-bin/monitor-brightness" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'brightness fixture did not become ready'
  wait_for_process "$qs_pid" 30 || rc=$?
  if ((rc != 0)); then
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "brightness fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and .busyObserved == true and
    .diagnostics.available == true and .diagnostics.displayCount == 3' \
    "$state_dir/result.json" >/dev/null \
    || {
      jq . "$state_dir/result.json" >&2 || true
      fail 'brightness fixture reported invalid state or action behavior'
    }
  [ "$(cat "$state_dir/sets.log")" = $'ddc-1 42\ninternal 40\nddc-1 47\nddc-2 70' ] \
    || {
      cat "$state_dir/sets.log" >&2
      fail 'brightness fixture did not record exactly one set per action (duplicate same-value set leaked)'
    }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'brightness fixture logged a binding or construction error'
    }
}
