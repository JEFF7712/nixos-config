# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_unit_tests() {
  local qmltestrunner_bin qt_qml_dir
  printf 'quickshell-services: run_unit_tests\n'
  qmltestrunner_bin=$(command -v qmltestrunner || true)
  [ -n "$qmltestrunner_bin" ] || fail 'qmltestrunner is absent from the test environment'
  qt_qml_dir="$(dirname "$(dirname "$qmltestrunner_bin")")/lib/qt-6/qml"
  QT_QPA_PLATFORM=offscreen qmltestrunner \
    -import "$qt_qml_dir" \
    -input "${repo_root}/tests/quickshell/unit"
}

run_normal_fixture() {
  local state_dir qs_pid rc=0
  new_fixture_state
  state_dir=$fixture_state
  QS_TEST_STATE_DIR="$state_dir" QS_TEST_MODE=normal QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$fixture_qml" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 10; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'normal fixture did not become ready within ten seconds'
  fi

  if ! approve_normal_teardowns "$state_dir"; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'normal fixture teardown lacked one complete live direct and descendant generation identity'
  fi

  wait_for_process "$qs_pid" 20 || rc=$?
  if ((rc != 0)); then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "normal fixture exited unsuccessfully or timed out (rc=${rc})"
  fi

  [ -s "$state_dir/result.json" ] || fail 'normal fixture did not write result.json'
  command -v jq >/dev/null || fail 'jq is required to validate fixture result.json'
  jq -e '.passed == true and (.diagnostics.completedSoftReload == true) and (.diagnostics.completedHardReload == true)' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'normal fixture reported failure or invalid diagnostics'
  }
  assert_all_normal_records_complete "$state_dir" || fail 'normal fixture published an incomplete or missing generation record'
  if rg -q ' overlap-(direct|child) ' "$state_dir/lifecycle.log"; then
    sed -n '1,240p' "$state_dir/lifecycle.log" >&2
    fail 'normal fixture observed overlapping owned processes'
  fi
  assert_loader_destruction_cleanup "$state_dir" || fail 'Loader destruction did not observably clean its live direct and descendant process identities'
  assert_no_fixture_survivors "$state_dir"
}

run_term_fixture() {
  local state_dir qs_pid record rc=0
  new_fixture_state
  state_dir=$fixture_state
  QS_TEST_STATE_DIR="$state_dir" QS_TEST_MODE=term QS_TEST_RECORD_DELAY=0.5 QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$fixture_qml" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 10; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'TERM fixture did not become ready within ten seconds'
  fi

  wait_for_single_complete_record "$state_dir" 5 || fail 'TERM fixture did not produce one complete process record after ready'
  record=$(printf '%s\n' "$state_dir"/processes/*.record)
  recorded_pid_matches "$record" '' || fail 'TERM fixture direct process was not live before TERM'
  recorded_pid_matches "$record" child_ || fail 'TERM fixture descendant process was not live before TERM'

  kill -TERM "$qs_pid"
  wait_for_process "$qs_pid" 10 || rc=$?
  if ((rc != 0 && rc != 143)); then
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "TERM fixture exited unexpectedly (rc=${rc})"
  fi
  assert_no_fixture_survivors "$state_dir"
}

run_process_cleanup_fixture() {
  printf 'quickshell-services: run_process_cleanup_fixture\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'
  if [ "${QS_TEST_SKIP_FAILURE_CLEANUP_PROBE:-0}" != 1 ]; then
    run_failure_cleanup_probe
    run_overlap_timeout_rejection_probe
    run_stubborn_prior_cleanup_probe
    run_transient_timeout_cleanup_probe
  fi
  run_overlap_descendant_probe
  run_transient_descendant_probe
  run_normal_fixture
  run_term_fixture
}

run_native_construction_probes() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_native_construction_probes\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-audio-native.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal"
  ln -s "$audio_fixture_bin/pavucontrol" "$state_dir/fixture-bin/pavucontrol"
  cp "$audio_native_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/AudioService.qml" "$state_dir/config/services/AudioService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/AudioReducer.js" "$state_dir/config/services/internal/AudioReducer.js"
  cp "$repo_root/home/configs/quickshell/services/internal/AudioModel.qml" "$state_dir/config/services/internal/AudioModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PipewireAudioBackend.qml" "$state_dir/config/services/internal/PipewireAudioBackend.qml"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"

  if ! wait_for_path "$state_dir/ready" 10; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'native audio fixture did not become ready within ten seconds'
  fi
  wait_for_process "$qs_pid" 10 || rc=$?
  if ((rc != 0)); then
    kill -TERM "$qs_pid" 2>/dev/null || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "native audio fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and
    (.diagnostics.available | type == "boolean") and
    (.diagnostics.skipped | type == "boolean") and
    (.diagnostics.volumePercent | type == "number") and
    (.diagnostics.volumePercent | floor) == .diagnostics.volumePercent and
    (.diagnostics.volumePercent >= 0) and
    (.diagnostics.volumePercent <= 100) and
    (.diagnostics.muted | type == "boolean") and
    if .diagnostics.skipped == true then
      .diagnostics.available == false
    else
      .diagnostics.skipped == false and
      .diagnostics.available == true
    end' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'native audio fixture reported invalid construction diagnostics'
  }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'native audio fixture logged a binding or construction error'
  }
  [ "$(cat "$state_dir/pavucontrol-actions.log")" = launch ] \
    || fail 'native audio fixture did not record exactly one detached mixer launch'
  jq -c '.diagnostics' "$state_dir/result.json"
}
