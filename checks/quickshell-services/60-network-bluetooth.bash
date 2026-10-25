# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_network_native_construction_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_network_native_construction_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-network-native.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  ln -s "$audio_fixture_bin/kitty" "$state_dir/fixture-bin/kitty"
  cp "$network_native_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/NetworkService.qml" "$state_dir/config/services/NetworkService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/NetworkBackend.qml" "$state_dir/config/services/internal/NetworkBackend.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/NetworkModel.qml" "$state_dir/config/services/internal/NetworkModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/NetworkParser.js" "$state_dir/config/services/internal/NetworkParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/NetworkReducer.js" "$state_dir/config/services/internal/NetworkReducer.js"
  : >"$state_dir/kitty-calls.log"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 10; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'native network fixture did not become ready within ten seconds'
  fi
  wait_for_process "$qs_pid" 10 || rc=$?
  if ((rc != 0)); then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "native network fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and
    (.diagnostics.available | type == "boolean") and
    (.diagnostics.skipped | type == "boolean") and
    (.diagnostics.wifiAvailable | type == "boolean") and
    (.diagnostics.wifiEnabled | type == "boolean") and
    (.diagnostics.wiredConnected | type == "boolean") and
    (.diagnostics.connected | type == "boolean") and
    (.diagnostics.activeSsid | type == "string") and
    (.diagnostics.activeSignal | type == "number") and
    (.diagnostics.activeSecurity | type == "string") and
    (.diagnostics.wiredConnectionCount | type == "number") and
    .diagnostics.wiredConnectionCount >= 0 and
    (.diagnostics.networkCount | type == "number") and
    .diagnostics.networkCount >= 0 and .diagnostics.networkCount <= 8 and
    if .diagnostics.skipped == true then
      .diagnostics.available == false
    else
      .diagnostics.available == true
    end' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'native network fixture reported invalid construction diagnostics'
  }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'native network fixture logged a binding or construction error'
    }
  [ "$(wc -l <"$state_dir/kitty-calls.log")" -eq 1 ] \
    || fail 'native network fixture did not record exactly one detached settings launch'
  jq -c '.diagnostics' "$state_dir/result.json"
}

run_bluetooth_native_construction_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_bluetooth_native_construction_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-bluetooth-native.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  ln -s "$audio_fixture_bin/blueman-manager" "$state_dir/fixture-bin/blueman-manager"
  cp "$bluetooth_native_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/BluetoothService.qml" "$state_dir/config/services/BluetoothService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothBackend.qml" "$state_dir/config/services/internal/BluetoothBackend.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothModel.qml" "$state_dir/config/services/internal/BluetoothModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothParser.js" "$state_dir/config/services/internal/BluetoothParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothReducer.js" "$state_dir/config/services/internal/BluetoothReducer.js"
  : >"$state_dir/blueman-calls.log"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 10; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'native bluetooth fixture did not become ready within ten seconds'
  fi
  wait_for_process "$qs_pid" 10 || rc=$?
  if ((rc != 0)); then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "native bluetooth fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and
    (.diagnostics.available | type == "boolean") and
    (.diagnostics.skipped | type == "boolean") and
    (.diagnostics.enabled | type == "boolean") and
    (.diagnostics.connectedCount | type == "number") and
    (.diagnostics.deviceCount | type == "number") and
    .diagnostics.connectedCount >= 0 and
    .diagnostics.deviceCount >= 0 and
    .diagnostics.connectedCount <= .diagnostics.deviceCount and
    if .diagnostics.skipped == true then
      .diagnostics.available == false
    else
      .diagnostics.available == true
    end' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'native bluetooth fixture reported invalid construction diagnostics'
  }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'native bluetooth fixture logged a binding or construction error'
    }
  [ "$(wc -l <"$state_dir/blueman-calls.log")" -eq 1 ] \
    || fail 'native bluetooth fixture did not record exactly one detached manager launch'
  jq -c '.diagnostics' "$state_dir/result.json"
}
