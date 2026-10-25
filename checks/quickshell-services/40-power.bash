# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_power_service_probe() {
  local state_dir qs_pid real_tee rc=0
  printf 'quickshell-services: run_power_service_probe\n'
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-power-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  for command in stasis tee; do
    ln -s "$audio_fixture_bin/$command" "$state_dir/fixture-bin/$command"
  done
  cp "$power_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/PowerService.qml" "$state_dir/config/services/PowerService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PowerModel.qml" "$state_dir/config/services/internal/PowerModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PowerParser.js" "$state_dir/config/services/internal/PowerParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/power-probe" "$state_dir/config/services/internal/power-probe"
  cp "$repo_root/home/configs/quickshell/services/internal/UPowerBackend.qml" "$state_dir/config/services/internal/UPowerBackend.qml"
  printf 'no\n' >"$state_dir/stasis"
  printf '80\n' >"$state_dir/threshold"
  chmod 600 "$state_dir/threshold"
  : >"$state_dir/actions.log"
  : >"$state_dir/calls.log"
  : >"$state_dir/overlap.log"

  real_tee=$(command -v tee)

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" \
    QS_TEST_REAL_TEE="$real_tee" \
    QS_POWER_THRESHOLD_PATH="$state_dir/threshold" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'power fixture did not become ready'
  wait_for_process "$qs_pid" 30 || rc=$?
  if ((rc != 0)); then
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "power fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and .sharedIdentity == true and .busyObserved == true and
    .diagnostics.chargeLimit == 100 and .diagnostics.idleInhibited == true' \
    "$state_dir/result.json" >/dev/null \
    || {
      jq . "$state_dir/result.json" >&2 || true
      fail 'power fixture reported invalid state or action behavior'
    }
  [ "$(cat "$state_dir/threshold")" = 100 ] \
    || fail 'power fixture charge-limit actions did not reach the fixture-only threshold'
  [ "$(cat "$state_dir/actions.log")" = $'threshold 75\nthreshold 100\nstasis toggle\nstasis toggle\nstasis toggle' ] \
    || {
      cat "$state_dir/actions.log" >&2
      fail 'power fixture did not record exactly one command per action'
    }
  [ ! -s "$state_dir/overlap.log" ] \
    || fail 'power fixture observed overlapping owned adapters'
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'power fixture logged a binding or construction error'
    }
}

run_power_destruction_probe() {
  local mode=$1 state_dir qs_pid owned_pid owned_record rc=0
  printf 'quickshell-services: run_power_destruction_probe %s\n' "$mode"
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-power-destruction.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  for command in stasis tee; do
    ln -s "$audio_fixture_bin/$command" "$state_dir/fixture-bin/$command"
  done
  cp "$power_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/PowerService.qml" "$state_dir/config/services/PowerService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PowerModel.qml" "$state_dir/config/services/internal/PowerModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PowerParser.js" "$state_dir/config/services/internal/PowerParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/power-probe" "$state_dir/config/services/internal/power-probe"
  cp "$repo_root/home/configs/quickshell/services/internal/UPowerBackend.qml" "$state_dir/config/services/internal/UPowerBackend.qml"
  printf 'no\n' >"$state_dir/stasis"
  printf '80\n' >"$state_dir/threshold"
  : >"$state_dir/actions.log"
  : >"$state_dir/calls.log"
  : >"$state_dir/overlap.log"
  if [ "$mode" = probe ]; then
    printf '1\n' >"$state_dir/slow-probe"
  else
    printf '1\n' >"$state_dir/slow-destruction-action"
  fi

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" \
    QS_POWER_THRESHOLD_PATH="$state_dir/threshold" QS_POWER_DESTRUCTION_MODE="$mode" \
    QT_QPA_PLATFORM=offscreen "$quickshell_bin" --no-color -p "$state_dir/config" \
    >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail "power $mode destruction fixture did not become ready"
  if [ "$mode" = probe ]; then
    wait_for_path "$state_dir/slow-probe.pid" 10 || fail 'slow power probe did not start'
    owned_pid=$(cat "$state_dir/slow-probe.pid")
  else
    wait_for_path "$state_dir/slow-action.pid" 10 || fail 'slow power action did not start'
    owned_pid=$(cat "$state_dir/slow-action.pid")
  fi
  sleep 0.1
  owned_record="$state_dir/owned.record"
  write_process_identity_record "$owned_pid" "$owned_record"
  kill -TERM "$qs_pid"
  wait_for_process "$qs_pid" 10 || rc=$?
  ((rc == 0 || rc == 143)) || fail "power $mode destruction fixture exited unexpectedly (rc=${rc})"
  if wait_for_recorded_process "$owned_record" '' 3; then
    :
  else
    rc=$?
    ((rc != 124)) || fail "power $mode descendant survived shell destruction"
  fi
  ! recorded_pid_matches "$owned_record" '' \
    || fail "power $mode descendant remained live after shell destruction"
  [ ! -s "$state_dir/overlap.log" ] \
    || fail "power $mode destruction fixture observed overlap"
}

run_power_native_construction_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_power_native_construction_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-power-native.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/config/services/internal"
  cp "$power_native_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/PowerService.qml" "$state_dir/config/services/PowerService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PowerModel.qml" "$state_dir/config/services/internal/PowerModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PowerParser.js" "$state_dir/config/services/internal/PowerParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/power-probe" "$state_dir/config/services/internal/power-probe"
  cp "$repo_root/home/configs/quickshell/services/internal/UPowerBackend.qml" "$state_dir/config/services/internal/UPowerBackend.qml"

  QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 10; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'native power fixture did not become ready within ten seconds'
  fi
  wait_for_process "$qs_pid" 10 || rc=$?
  if ((rc != 0)); then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "native power fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and
    (.diagnostics.available | type == "boolean") and
    (.diagnostics.skipped | type == "boolean") and
    (.diagnostics.state | type == "string") and
    (.diagnostics.profile | type == "string") and
    (.diagnostics.chargePercent | type == "number") and
    (.diagnostics.chargeLimit | type == "number") and
    (.diagnostics.thresholdWritable | type == "boolean") and
    (.diagnostics.idleInhibited | type == "boolean") and
    (.diagnostics.busy | type == "boolean") and
    if .diagnostics.skipped == true then
      .diagnostics.available == false
    else
      .diagnostics.available == true
    end' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'native power fixture reported invalid construction diagnostics'
  }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'native power fixture logged a binding or construction error'
    }
  jq -c '.diagnostics' "$state_dir/result.json"
}
