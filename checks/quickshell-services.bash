#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_qml="${repo_root}/tests/quickshell/integration/process-cleanup"
fixture_bin="${repo_root}/tests/quickshell/fixtures/bin/qs-test-owned-process"
audio_native_fixture_qml="${repo_root}/tests/quickshell/integration/audio-native"
media_fixture_qml="${repo_root}/tests/quickshell/integration/media-service"
cava_fixture_qml="${repo_root}/tests/quickshell/integration/cava-service"
power_fixture_qml="${repo_root}/tests/quickshell/integration/power-service"
power_native_fixture_qml="${repo_root}/tests/quickshell/integration/power-native"
system_fixture_qml="${repo_root}/tests/quickshell/integration/system-service"
niri_fixture_qml="${repo_root}/tests/quickshell/integration/niri-service"
network_fixture_qml="${repo_root}/tests/quickshell/integration/network-service"
network_native_fixture_qml="${repo_root}/tests/quickshell/integration/network-native"
bluetooth_fixture_qml="${repo_root}/tests/quickshell/integration/bluetooth-service"
audio_fixture_bin="${repo_root}/tests/quickshell/fixtures/bin"
quickshell_bin=$(command -v quickshell || true)
declare -a fixture_state_dirs=()
declare -a fixture_qs_pids=()
declare -A fixture_qs_known=()
declare -A fixture_qs_reaped=()
declare -A fixture_qs_start=()
declare -A fixture_qs_signature=()
fixture_state=

fail() {
  printf 'quickshell-services: %s\n' "$*" >&2
  exit 1
}

record_value() {
  local key=$1 record=$2
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$record"
}

process_signature() {
  sha256sum "/proc/$1/cmdline" | awk '{ print $1 }'
}

process_start_time() {
  awk '{ print $22 }' "/proc/$1/stat"
}

register_fixture_qs() {
  local pid=$1
  fixture_qs_pids+=("$pid")
  fixture_qs_known[$pid]=1
  fixture_qs_start[$pid]=$(process_start_time "$pid")
  fixture_qs_signature[$pid]=$(process_signature "$pid")
}

fixture_qs_matches() {
  local pid=$1 start signature
  [ -n "${fixture_qs_known[$pid]:-}" ] || return 1
  [ -r "/proc/${pid}/stat" ] || return 1
  start=$(process_start_time "$pid" 2>/dev/null) || return 1
  signature=$(process_signature "$pid" 2>/dev/null) || return 1
  [ "$start" = "${fixture_qs_start[$pid]}" ] \
    && [ "$signature" = "${fixture_qs_signature[$pid]}" ]
}

recorded_pid_matches() {
  local record=$1 prefix=$2 pid start signature state current_start current_signature
  pid=$(record_value "${prefix}pid" "$record")
  start=$(record_value "${prefix}start_time" "$record")
  signature=$(record_value "${prefix}command_signature" "$record")
  [ -n "$pid" ] && [ -r "/proc/${pid}/stat" ] || return 1
  state=$(awk '{ print $3 }' "/proc/${pid}/stat" 2>/dev/null) || return 1
  [ "$state" != Z ] || return 1
  current_start=$(process_start_time "$pid" 2>/dev/null) || return 1
  [ "$current_start" = "$start" ] || return 1
  current_signature=$(process_signature "$pid" 2>/dev/null) || return 1
  [ "$current_signature" = "$signature" ]
}

record_is_complete() {
  local record=$1 key
  for key in pid ppid start_time command_signature child_pid child_start_time child_command_signature; do
    [ -n "$(record_value "$key" "$record")" ] || return 1
  done
}

assert_single_complete_record() {
  local state_dir=$1
  local -a records
  shopt -s nullglob
  records=("$state_dir"/processes/*.record)
  shopt -u nullglob
  ((${#records[@]} == 1)) || return 1
  record_is_complete "${records[0]}"
}

assert_all_normal_records_complete() {
  local state_dir=$1 record
  local -a records labels
  shopt -s nullglob
  records=("$state_dir"/processes/*.record)
  shopt -u nullglob
  ((${#records[@]} == 4)) || return 1
  for record in "${records[@]}"; do
    record_is_complete "$record" || return 1
    labels+=("$(record_value label "$record")")
  done
  [ "$(printf '%s\n' "${labels[@]}" | sort | tr '\n' ' ')" = "hard initial reload-soft soft " ]
}

wait_for_single_complete_record() {
  local state_dir=$1 timeout_seconds=$2 started
  started=$SECONDS
  until assert_single_complete_record "$state_dir"; do
    if ((SECONDS - started >= timeout_seconds)); then
      return 1
    fi
    sleep 0.05
  done
}

assert_loader_destruction_cleanup() {
  local state_dir=$1 record pid child_pid
  local -a initial_records=()
  for record in "$state_dir"/processes/*.record; do
    [ -e "$record" ] || continue
    if [ "$(record_value label "$record")" = initial ]; then
      initial_records+=("$record")
    fi
  done
  ((${#initial_records[@]} == 1)) || return 1
  record=${initial_records[0]}
  record_is_complete "$record" || return 1
  pid=$(record_value pid "$record")
  child_pid=$(record_value child_pid "$record")
  ! recorded_pid_matches "$record" '' || return 1
  ! recorded_pid_matches "$record" child_ || return 1
  rg -q " child-owner-gone ${child_pid} ${pid} " "$state_dir/lifecycle.log"
}

find_generation_record() {
  local state_dir=$1 label=$2 record match=
  for record in "$state_dir"/processes/*.record; do
    [ -e "$record" ] || continue
    if [ "$(record_value label "$record")" = "$label" ]; then
      [ -z "$match" ] || return 1
      match=$record
    fi
  done
  [ -n "$match" ] || return 1
  printf '%s\n' "$match"
}

approve_normal_teardowns() {
  local state_dir=$1 index label action request approval record
  local -a labels=(initial reload-soft soft hard)
  local -a actions=(loader-destroy soft-reload hard-reload final-stop)
  for index in "${!labels[@]}"; do
    label=${labels[$index]}
    action=${actions[$index]}
    request="${state_dir}/teardown-request.${action}"
    approval="${state_dir}/teardown-approved.${action}"
    wait_for_path "$request" 10 || return 1
    record=$(find_generation_record "$state_dir" "$label") || return 1
    record_is_complete "$record" || return 1
    recorded_pid_matches "$record" '' || return 1
    recorded_pid_matches "$record" child_ || return 1
    printf 'approved\n' >"$approval"
  done
}

cleanup_fixture_processes() {
  local state_dir record pid
  for state_dir in "${fixture_state_dirs[@]}"; do
    [ -d "$state_dir/processes" ] || continue
    for record in "$state_dir"/processes/*.record; do
      [ -e "$record" ] || continue
      for prefix in '' child_; do
        if recorded_pid_matches "$record" "$prefix"; then
          pid=$(record_value "${prefix}pid" "$record")
          kill -TERM "$pid" 2>/dev/null || true
        fi
      done
    done
  done
}

wait_for_registered_qs() {
  local pid=$1 timeout_seconds=$2 started rc=0
  [ -z "${fixture_qs_reaped[$pid]:-}" ] || return 0
  started=$SECONDS
  while fixture_qs_matches "$pid"; do
    if ((SECONDS - started >= timeout_seconds)); then
      return 124
    fi
    sleep 0.05
  done
  wait "$pid" 2>/dev/null || rc=$?
  fixture_qs_reaped[$pid]=1
  return "$rc"
}

stop_and_reap_fixture_qs() {
  local pid=$1 rc=0
  [ -z "${fixture_qs_reaped[$pid]:-}" ] || return 0
  if fixture_qs_matches "$pid"; then
    kill -TERM "$pid" 2>/dev/null || true
  fi
  wait_for_registered_qs "$pid" 2 || rc=$?
  if ((rc == 124)); then
    if fixture_qs_matches "$pid"; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    wait_for_registered_qs "$pid" 2 >/dev/null 2>&1 || true
  fi
  fixture_qs_reaped[$pid]=1
}

cleanup_all_fixtures() {
  local status=$? pid state_dir
  trap - EXIT
  set +e
  for pid in "${fixture_qs_pids[@]}"; do
    stop_and_reap_fixture_qs "$pid"
  done
  cleanup_fixture_processes
  if ((status == 0)); then
    for state_dir in "${fixture_state_dirs[@]}"; do
      [ -d "$state_dir" ] || continue
      rm -rf -- "$state_dir"
    done
  else
    for state_dir in "${fixture_state_dirs[@]}"; do
      [ -d "$state_dir" ] || continue
      printf 'quickshell-services: preserved failed fixture state: %s\n' "$state_dir" >&2
    done
  fi
  exit "$status"
}

trap cleanup_all_fixtures EXIT

wait_for_path() {
  local path=$1 timeout_seconds=$2 started
  started=$SECONDS
  while [ ! -e "$path" ]; do
    if ((SECONDS - started >= timeout_seconds)); then
      return 1
    fi
    sleep 0.05
  done
}

wait_for_process() {
  local pid=$1 timeout_seconds=$2 started rc=0
  started=$SECONDS
  while kill -0 "$pid" 2>/dev/null; do
    if ((SECONDS - started >= timeout_seconds)); then
      return 124
    fi
    sleep 0.05
  done
  wait "$pid" || rc=$?
  if [ -n "${fixture_qs_known[$pid]:-}" ]; then
    fixture_qs_reaped[$pid]=1
  fi
  return "$rc"
}

write_process_identity_record() {
  local pid=$1 record=$2
  {
    printf 'pid=%s\n' "$pid"
    printf 'start_time=%s\n' "$(process_start_time "$pid")"
    printf 'command_signature=%s\n' "$(process_signature "$pid")"
  } >"$record"
}

wait_for_recorded_process() {
  local record=$1 prefix=$2 timeout_seconds=$3 pid started rc=0
  pid=$(record_value "${prefix}pid" "$record")
  started=$SECONDS
  while recorded_pid_matches "$record" "$prefix"; do
    if ((SECONDS - started >= timeout_seconds)); then
      return 124
    fi
    sleep 0.05
  done
  wait "$pid" 2>/dev/null || rc=$?
  return "$rc"
}

stop_and_reap_recorded_process() {
  local record=$1 prefix=$2 pid rc=0
  pid=$(record_value "${prefix}pid" "$record")
  if recorded_pid_matches "$record" "$prefix"; then
    kill -TERM "$pid" 2>/dev/null || true
  fi
  wait_for_recorded_process "$record" "$prefix" 2 || rc=$?
  if ((rc == 124)); then
    if recorded_pid_matches "$record" "$prefix"; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    rc=0
    wait_for_recorded_process "$record" "$prefix" 2 >/dev/null 2>&1 || rc=$?
    ((rc != 124)) || return 1
  fi
}

assert_no_fixture_survivors() {
  local state_dir=$1 started record prefix pid survivor=0
  started=$SECONDS
  while :; do
    survivor=0
    for record in "$state_dir"/processes/*.record; do
      [ -e "$record" ] || continue
      for prefix in '' child_; do
        if recorded_pid_matches "$record" "$prefix"; then
          survivor=1
        fi
      done
    done
    ((survivor == 0)) && return 0
    ((SECONDS - started >= 5)) && break
    sleep 0.05
  done

  printf 'quickshell-services: fixture processes survived five seconds:\n' >&2
  for record in "$state_dir"/processes/*.record; do
    [ -e "$record" ] || continue
    for prefix in '' child_; do
      if recorded_pid_matches "$record" "$prefix"; then
        pid=$(record_value "${prefix}pid" "$record")
        printf '  pid=%s record=%s\n' "$pid" "$record" >&2
      fi
    done
  done
  return 1
}

new_fixture_state() {
  fixture_state=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-services.XXXXXX")
  fixture_state_dirs+=("$fixture_state")
  mkdir -p "$fixture_state/fixture-bin"
  ln -s "$fixture_bin" "$fixture_state/fixture-bin/qs-test-owned-process"
  printf 'initial\n' >"$fixture_state/phase"
  printf '{}\n' >"$fixture_state/diagnostics.json"
}

run_forced_failure_child() {
  local state_dir=$1 qs_pid
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin"
  ln -sf "$fixture_bin" "$state_dir/fixture-bin/qs-test-owned-process"
  printf 'initial\n' >"$state_dir/phase"
  printf '{}\n' >"$state_dir/diagnostics.json"
  QS_TEST_STATE_DIR="$state_dir" QS_TEST_MODE=term QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$fixture_qml" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  {
    printf 'pid=%s\n' "$qs_pid"
    printf 'start_time=%s\n' "$(process_start_time "$qs_pid")"
    printf 'command_signature=%s\n' "$(process_signature "$qs_pid")"
  } >"$state_dir/quickshell.record"
  wait_for_path "$state_dir/ready" 10 || fail 'forced-failure fixture did not become ready'
  fail 'forced fixture precondition failure'
}

run_failure_cleanup_probe() {
  local state_dir rc=0 pid leaked=0
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-services-cleanup-probe.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  QS_TEST_FORCE_FAILURE_CHILD=1 QS_TEST_PROBE_STATE_DIR="$state_dir" bash "${BASH_SOURCE[0]}" \
    >"$state_dir/probe.log" 2>&1 || rc=$?
  ((rc != 0)) || fail 'forced-failure cleanup probe unexpectedly succeeded'
  pid=$(record_value pid "$state_dir/quickshell.record")
  if recorded_pid_matches "$state_dir/quickshell.record" ''; then
    leaked=1
    kill -TERM "$pid" 2>/dev/null || true
  fi
  ((leaked == 0)) || fail 'forced precondition failure left fixture Quickshell alive'
  rm -rf -- "$state_dir"
}

run_overlap_timeout_rejection_probe() {
  local state_dir rc=0
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-services-overlap-timeout.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  QS_TEST_OVERLAP_TIMEOUT_PROBE_CHILD=1 QS_TEST_STALL_AFTER_OVERLAP=1 TMPDIR="$state_dir" \
    timeout --signal=TERM --kill-after=2 8 bash "${BASH_SOURCE[0]}" \
    >"$state_dir/probe.log" 2>&1 || rc=$?
  ((rc == 1)) || fail "forced overlap timeout probe was not rejected exactly (rc=${rc})"
  rg -q 'owned-process overlap probe timed out after recording overlap' "$state_dir/probe.log" \
    || fail 'forced overlap timeout probe lacked the expected timeout diagnostic'
  assert_probe_tree_has_no_survivors "$state_dir" \
    || fail 'forced overlap timeout probe left fixture survivors'
}

assert_probe_tree_has_no_survivors() {
  local state_dir=$1 record prefix pid survivor=0
  local -a records
  shopt -s nullglob
  records=(
    "$state_dir"/quickshell-services.*/*.record
    "$state_dir"/quickshell-services.*/processes/*.record
  )
  shopt -u nullglob
  for record in "${records[@]}"; do
    for prefix in '' child_; do
      if recorded_pid_matches "$record" "$prefix"; then
        pid=$(record_value "${prefix}pid" "$record")
        printf 'quickshell-services: probe survivor pid=%s record=%s\n' "$pid" "$record" >&2
        survivor=1
      fi
    done
  done
  ((survivor == 0))
}

cleanup_probe_tree_processes() {
  local state_dir=$1 record prefix
  local -a records
  shopt -s nullglob
  records=(
    "$state_dir"/quickshell-services.*/*.record
    "$state_dir"/quickshell-services.*/processes/*.record
  )
  shopt -u nullglob
  for record in "${records[@]}"; do
    for prefix in '' child_; do
      recorded_pid_matches "$record" "$prefix" || continue
      stop_and_reap_recorded_process "$record" "$prefix" || true
    done
  done
}

run_stubborn_prior_cleanup_probe() {
  local state_dir rc=0
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-services-stubborn-prior.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  QS_TEST_OVERLAP_TIMEOUT_PROBE_CHILD=1 QS_TEST_PRIOR_IGNORES_TERM=1 TMPDIR="$state_dir" \
    timeout --signal=TERM --kill-after=2 8 bash "${BASH_SOURCE[0]}" \
    >"$state_dir/probe.log" 2>&1 || rc=$?
  if ((rc != 0)); then
    cleanup_probe_tree_processes "$state_dir"
  fi
  ((rc == 0)) || fail "stubborn prior descendant cleanup was not bounded exactly (rc=${rc})"
  rg -q 'prior descendant ignored TERM and was reaped after escalation' "$state_dir/probe.log" \
    || fail 'stubborn prior descendant cleanup lacked the expected escalation diagnostic'
  assert_probe_tree_has_no_survivors "$state_dir" \
    || fail 'stubborn prior descendant cleanup left fixture survivors'
}

run_transient_timeout_cleanup_probe() {
  local state_dir rc=0
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-services-transient-timeout.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  QS_TEST_TRANSIENT_TIMEOUT_PROBE_CHILD=1 QS_TEST_SUPPRESS_READY=1 TMPDIR="$state_dir" \
    timeout --signal=TERM --kill-after=2 8 bash "${BASH_SOURCE[0]}" \
    >"$state_dir/probe.log" 2>&1 || rc=$?
  ((rc == 1)) || fail "forced transient readiness timeout was not bounded exactly (rc=${rc})"
  rg -q 'owned-process overlap probe timed out waiting for transient helper readiness' "$state_dir/probe.log" \
    || fail 'forced transient readiness timeout lacked the expected diagnostic'
  assert_probe_tree_has_no_survivors "$state_dir" \
    || fail 'forced transient readiness timeout left fixture survivors'
}

run_overlap_descendant_probe() {
  local state_dir prior_child fake_pid rc=0 record fake_record prior_term_marker cleanup_failed=0
  new_fixture_state
  state_dir=$fixture_state
  prior_term_marker="$state_dir/prior-term-observed"
  if [ "${QS_TEST_PRIOR_IGNORES_TERM:-0}" = 1 ]; then
    bash -c '
      set -euo pipefail
      trap '\''printf "observed\n" >"$1"'\'' TERM
      while :; do
        sleep 0.05
      done
    ' _ "$prior_term_marker" &
  else
    sleep 30 &
  fi
  prior_child=$!
  record="$state_dir/processes/prior.record"
  mkdir -p "$state_dir/processes"
  {
    printf 'pid=99999999\n'
    printf 'ppid=1\n'
    printf 'start_time=0\n'
    printf 'command_signature=dead\n'
    printf 'child_pid=%s\n' "$prior_child"
    printf 'child_start_time=%s\n' "$(process_start_time "$prior_child")"
    printf 'child_command_signature=%s\n' "$(process_signature "$prior_child")"
    printf 'label=prior-descendant\n'
  } >"$record"
  QS_TEST_STATE_DIR="$state_dir" "$fixture_bin" overlap-probe &
  fake_pid=$!
  fake_record="$state_dir/overlap-helper.record"
  write_process_identity_record "$fake_pid" "$fake_record"
  wait_for_recorded_process "$fake_record" '' 3 || rc=$?
  if ((rc == 124)); then
    stop_and_reap_recorded_process "$fake_record" '' || cleanup_failed=1
  fi
  stop_and_reap_recorded_process "$record" child_ || cleanup_failed=1
  ((cleanup_failed == 0)) || fail 'owned-process overlap probe could not reap its recorded processes'
  if [ "${QS_TEST_PRIOR_IGNORES_TERM:-0}" = 1 ]; then
    [ -e "$prior_term_marker" ] \
      || fail 'stubborn prior descendant did not observe TERM before escalation'
    printf 'quickshell-services: prior descendant ignored TERM and was reaped after escalation\n' >&2
  fi
  case $rc in
    1)
      rg -q ' overlap-child ' "$state_dir/lifecycle.log" \
        || fail 'owned-process overlap probe did not record the live prior descendant'
      ;;
    124)
      fail 'owned-process overlap probe timed out after recording overlap'
      ;;
    0)
      fail 'owned-process overlap probe accepted a live prior descendant with a dead parent'
      ;;
    *)
      fail "owned-process overlap probe exited unexpectedly (rc=${rc})"
      ;;
  esac
}

run_transient_descendant_probe() {
  local state_dir prior_child fake_pid record fake_record observed_marker release_marker cleanup_failed
  new_fixture_state
  state_dir=$fixture_state
  observed_marker="$state_dir/overlap-observed"
  release_marker="$state_dir/release-transient"
  bash -c '
    set -euo pipefail
    until [ -e "$1" ]; do
      sleep 0.01
    done
  ' _ "$release_marker" &
  prior_child=$!
  record="$state_dir/processes/prior.record"
  mkdir -p "$state_dir/processes"
  {
    printf 'pid=99999999\n'
    printf 'ppid=1\n'
    printf 'start_time=0\n'
    printf 'command_signature=dead\n'
    printf 'child_pid=%s\n' "$prior_child"
    printf 'child_start_time=%s\n' "$(process_start_time "$prior_child")"
    printf 'child_command_signature=%s\n' "$(process_signature "$prior_child")"
    printf 'label=prior-transient-descendant\n'
  } >"$record"
  QS_TEST_STATE_DIR="$state_dir" QS_TEST_OVERLAP_OBSERVED_MARKER="$observed_marker" \
    "$fixture_bin" transient-probe &
  fake_pid=$!
  fake_record="$state_dir/transient-helper.record"
  write_process_identity_record "$fake_pid" "$fake_record"
  if ! wait_for_path "$observed_marker" 2; then
    cleanup_failed=0
    stop_and_reap_recorded_process "$fake_record" '' || cleanup_failed=1
    printf 'release\n' >"$release_marker"
    stop_and_reap_recorded_process "$record" child_ || cleanup_failed=1
    ((cleanup_failed == 0)) \
      || fail 'owned-process overlap probe could not clean up after missing live descendant observation'
    fail 'owned-process overlap probe did not report its first live descendant observation'
  fi
  printf 'release\n' >"$release_marker"
  if ! wait_for_path "$state_dir/ready.${fake_pid}" 2; then
    cleanup_failed=0
    stop_and_reap_recorded_process "$fake_record" '' || cleanup_failed=1
    stop_and_reap_recorded_process "$record" child_ || cleanup_failed=1
    ((cleanup_failed == 0)) \
      || fail 'owned-process overlap probe could not clean up after transient helper readiness timeout'
    fail 'owned-process overlap probe timed out waiting for transient helper readiness'
  fi
  cleanup_failed=0
  stop_and_reap_recorded_process "$fake_record" '' || cleanup_failed=1
  stop_and_reap_recorded_process "$record" child_ || cleanup_failed=1
  ((cleanup_failed == 0)) || fail 'owned-process overlap probe could not clean up transient processes'
  if rg -q ' overlap-child ' "$state_dir/lifecycle.log"; then
    fail 'owned-process overlap probe recorded a descendant completing teardown as overlap'
  fi
}

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

run_media_service_probe() {
  local state_dir qs_pid rc=0 follow_pid follow_record real_jq
  printf 'quickshell-services: run_media_service_probe\n'
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-media-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal" "$state_dir/processes"
  ln -s "$audio_fixture_bin/playerctl" "$state_dir/fixture-bin/playerctl"
  ln -s "$audio_fixture_bin/jq" "$state_dir/fixture-bin/jq"
  cp "$media_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$media_fixture_qml/policy.json" "$state_dir/policy.json"
  cp "$repo_root/home/configs/quickshell/services/AudioService.qml" "$state_dir/config/services/AudioService.qml"
  cp "$repo_root/home/configs/quickshell/services/MediaService.qml" "$state_dir/config/services/MediaService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/AudioReducer.js" "$state_dir/config/services/internal/AudioReducer.js"
  cp "$repo_root/home/configs/quickshell/services/internal/AudioModel.qml" "$state_dir/config/services/internal/AudioModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PipewireAudioBackend.qml" "$state_dir/config/services/internal/PipewireAudioBackend.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/MediaParser.js" "$state_dir/config/services/internal/MediaParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/MediaModel.qml" "$state_dir/config/services/internal/MediaModel.qml"
  : >"$state_dir/actions.log"
  mkfifo "$state_dir/follow.fifo"
  jq -e '.selection == "bare playerctl default selection" and
    (.scenarios.onePlayer.state.available | type == "boolean") and
    (.scenarios.multipleDefaultPaused.state.players | length) >= 2 and
    .scenarios.multipleDefaultPaused.expected.status == "Paused" and
    .scenarios.disappearance.expectedAvailable == false and
    (.expectedActions | type == "array") and
    .forbiddenActionArg == "--player"' "$state_dir/policy.json" >/dev/null \
    || fail 'media policy fixture is incomplete or invalid'
  jq '.scenarios.onePlayer.state' "$state_dir/policy.json" >"$state_dir/player.json"

  real_jq=$(command -v jq)
  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QS_TEST_REAL_JQ="$real_jq" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'media fixture did not become ready'
  wait_for_process "$qs_pid" 50 || rc=$?
  ((rc == 0)) || {
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "media fixture exited unsuccessfully or timed out (rc=${rc})"
  }
  jq -e '.passed == true and .sharedIdentity == true and .policyPassed == true and
    .malformedPreserved == true and .disappearancePreserved == true and
    .recoveryPassed == true and .cadencePassed == true and
    .followCoalesced == true and .bareDefaultPassed == true and
    .noDuplicateEnablePassed == true and .followRestartPassed == true and
    .pendingInvalidationPassed == true and .queuedInvalidationPassed == true and
    .actionOrderPassed == true and .delayedActionPassed == true' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'media fixture reported invalid state or action routing'
  }
  diff -u <(jq -r '.expectedActions[]' "$state_dir/policy.json") "$state_dir/actions.log" \
    || fail 'media fixture did not route exactly one expected action per gesture'
  ! rg -F -q -- "$(jq -r '.forbiddenActionArg' "$state_dir/policy.json")" "$state_dir/playerctl-calls.log" \
    || fail 'media actions invented an explicit player selector'
  [ ! -s "$state_dir/playerctl-overlap.log" ] \
    || fail 'media fixture observed overlapping snapshot or action commands'
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || fail 'media fixture logged a binding or construction error'
  [ ! -e "$state_dir/follow.active" ] || fail 'media follow active marker survived shell exit'
  for follow_record in "$state_dir"/processes/follow.*.record; do
    [ -e "$follow_record" ] || continue
    follow_pid=$(record_value pid "$follow_record")
    ! kill -0 "$follow_pid" 2>/dev/null || fail 'media follow process survived shell exit'
  done
  [ "$(rg -c '^start ' "$state_dir/playerctl-lifecycle.log")" -eq 2 ] \
    || fail 'media fixture did not perform exactly one forced follow restart'
  [ "$(rg -c '^term ' "$state_dir/playerctl-lifecycle.log")" -eq 2 ] \
    || fail 'media fixture did not clean both follow process generations'
  jq -c . "$state_dir/result.json"
}

run_cava_service_probe() {
  local mode state_dir qs_pid rc=0 record pid expected_config fixture_path tool
  printf 'quickshell-services: run_cava_service_probe\n'
  for mode in normal destruction failed-start failed-start-cancel failed-start-destruction; do
    state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-cava-service.XXXXXX")
    fixture_state_dirs+=("$state_dir")
    mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal" "$state_dir/processes"
    ln -s "$audio_fixture_bin/cava" "$state_dir/fixture-bin/cava"
    fixture_path="$state_dir/fixture-bin:$PATH"
    if [[ "$mode" == failed-start* ]]; then
      for tool in bash cat date mkdir rmdir sleep; do
        ln -s "$(command -v "$tool")" "$state_dir/fixture-bin/$tool"
      done
      fixture_path="$state_dir/fixture-bin"
    fi
    cp "$cava_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
    cp "$repo_root/home/configs/quickshell/cava-bar.conf" "$state_dir/config/cava-bar.conf"
    cp "$repo_root/home/configs/quickshell/services/CavaService.qml" "$state_dir/config/services/CavaService.qml"
    cp "$repo_root/home/configs/quickshell/services/internal/CavaParser.js" "$state_dir/config/services/internal/CavaParser.js"
    mkfifo "$state_dir/cava.fifo"
    : >"$state_dir/cava-lifecycle.log"
    expected_config="$state_dir/config/cava-bar.conf"

    PATH="$fixture_path" QS_TEST_STATE_DIR="$state_dir" \
      QS_TEST_EXPECTED_CONFIG="$expected_config" QS_TEST_MODE="$mode" QT_QPA_PLATFORM=offscreen \
      "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
    qs_pid=$!
    register_fixture_qs "$qs_pid"

    if [ "$mode" = normal ]; then
      wait_for_process "$qs_pid" 20 || rc=$?
      ((rc == 0)) || {
        sed -n '1,240p' "$state_dir/quickshell.log" >&2
        fail "cava fixture exited unsuccessfully or timed out (rc=${rc})"
      }
      jq -e '.passed == true and .initialDemandPassed == true and
        .parsingPassed == true and .retryPassed == true and
        .recoveryPassed == true and .stopPassed == true and
        .restartPassed == true and .rapidDemandPassed == true and
        .canceledDemandPassed == true and .starts == 7' "$state_dir/result.json" >/dev/null \
        || fail 'cava fixture reported invalid parsing, demand, retry, or cleanup behavior'
    elif [ "$mode" = destruction ]; then
      wait_for_path "$state_dir/ready" 10 || fail 'cava destruction fixture did not become ready'
      kill -TERM "$qs_pid"
      wait_for_process "$qs_pid" 5 || true
    elif [ "$mode" = failed-start-destruction ]; then
      wait_for_path "$state_dir/ready" 10 || fail 'cava failed-start destruction fixture did not become ready'
      kill -TERM "$qs_pid"
      wait_for_process "$qs_pid" 5 || true
      ln -s "$(command -v setpriv)" "$state_dir/fixture-bin/setpriv"
      sleep 0.4
      [ ! -s "$state_dir/cava-lifecycle.log" ] \
        || fail 'cava retry survived shell destruction after FailedToStart'
    elif [ "$mode" = failed-start ]; then
      wait_for_path "$state_dir/ready" 10 || fail 'cava failed-start fixture did not request executable restoration'
      ln -s "$(command -v setpriv)" "$state_dir/fixture-bin/setpriv"
      wait_for_process "$qs_pid" 20 || rc=$?
      ((rc == 0)) || fail "cava failed-start fixture exited unsuccessfully or timed out (rc=${rc})"
      jq -e '.passed == true and .failedStartRecoveryPassed == true and .starts == 1' \
        "$state_dir/result.json" >/dev/null \
        || fail 'cava failed-start fixture did not recover through exactly one bounded retry'
    else
      wait_for_process "$qs_pid" 20 || rc=$?
      ((rc == 0)) || fail "cava failed-start cancellation fixture exited unsuccessfully or timed out (rc=${rc})"
      jq -e '.passed == true and .failedStartCancelPassed == true and .starts == 0' \
        "$state_dir/result.json" >/dev/null \
        || fail 'cava demand drop did not cancel failed-start retries'
    fi

    ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
      || fail 'cava fixture logged a binding or construction error'
    [ ! -s "$state_dir/cava-overlap.log" ] \
      || fail 'cava fixture observed overlapping instances'
    [ ! -d "$state_dir/cava.active" ] \
      || fail 'cava active marker survived fixture exit'
    for record in "$state_dir"/processes/cava.*.record; do
      [ -e "$record" ] || continue
      pid=$(record_value pid "$record")
      ! kill -0 "$pid" 2>/dev/null || fail 'cava process survived fixture exit'
    done
  done
}

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
    (.diagnostics.kernel | type == "string")' \
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
    (.diagnostics.wifiEnabled | type == "boolean") and
    (.diagnostics.connected | type == "boolean") and
    (.diagnostics.activeSsid | type == "string") and
    (.diagnostics.activeSignal | type == "number") and
    (.diagnostics.activeSecurity | type == "string") and
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

run_bluetooth_service_probe() {
  local state_dir qs_pid rc=0
  printf 'quickshell-services: run_bluetooth_service_probe\n'
  [ -n "$quickshell_bin" ] || fail 'host quickshell is absent; expected quickshell 0.3.0 or newer on PATH'

  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-bluetooth-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal" "$state_dir/bluetooth"
  ln -s "$audio_fixture_bin/busctl" "$state_dir/fixture-bin/busctl"
  ln -s "$audio_fixture_bin/blueman-manager" "$state_dir/fixture-bin/blueman-manager"
  cp "$bluetooth_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$repo_root/home/configs/quickshell/services/BluetoothService.qml" "$state_dir/config/services/BluetoothService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothModel.qml" "$state_dir/config/services/internal/BluetoothModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothParser.js" "$state_dir/config/services/internal/BluetoothParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/BluetoothReducer.js" "$state_dir/config/services/internal/BluetoothReducer.js"
  printf '/org/bluez/hci0\n' >"$state_dir/bluetooth/adapter"
  printf 'true\n' >"$state_dir/bluetooth/powered"
  printf '/org/bluez/hci0\n/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF\n/org/bluez/hci0/dev_11_22_33_44_55_66\n' >"$state_dir/bluetooth/tree"
  printf '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF\n/org/bluez/hci0/dev_11_22_33_44_55_66\n' >"$state_dir/bluetooth/paired"
  printf '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF\n' >"$state_dir/bluetooth/connected"
  printf '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF|Buds\n/org/bluez/hci0/dev_11_22_33_44_55_66|Keyboard\n' >"$state_dir/bluetooth/names"
  : >"$state_dir/busctl-calls.log"
  : >"$state_dir/blueman-calls.log"

  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'bluetooth fixture did not become ready'
  wait_for_process "$qs_pid" 30 || rc=$?
  if ((rc != 0)); then
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "bluetooth fixture exited unsuccessfully or timed out (rc=${rc})"
  fi
  jq -e '.passed == true and .busyObserved == true and
    .diagnostics.available == true and .diagnostics.enabled == true and
    .diagnostics.deviceCount == 2' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    fail 'bluetooth fixture reported invalid state or action behavior'
  }
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || {
      sed -n '1,240p' "$state_dir/quickshell.log" >&2
      fail 'bluetooth fixture logged a binding or construction error'
    }
  [ "$(wc -l <"$state_dir/blueman-calls.log")" -eq 1 ] \
    || fail 'bluetooth fixture did not launch blueman-manager exactly once'
  jq -c '.diagnostics' "$state_dir/result.json"
}

assert_native_probe_has_no_wpctl_dependency() {
  local probe_body
  printf 'quickshell-services: assert_native_probe_has_no_wpctl_dependency\n'
  probe_body=$(sed -n '/^run_native_construction_probes() {$/,/^}$/p' "${BASH_SOURCE[0]}")
  ! rg -n 'command -v wpctl|wpctl status' <<<"$probe_body" \
    || fail 'native audio construction probe still depends on wpctl availability'
}

assert_native_fixture_always_validates_public_contract() {
  printf 'quickshell-services: assert_native_fixture_always_validates_public_contract\n'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$audio_native_fixture_qml/shell.qml" \
    || fail 'native audio fixture lets skipped backends bypass public contract validation'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$power_native_fixture_qml/shell.qml" \
    || fail 'native power fixture lets skipped backends bypass public contract validation'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$network_native_fixture_qml/shell.qml" \
    || fail 'native network fixture lets skipped backends bypass public contract validation'
}

assert_no_view_processes_for_migrated_domains() {
  local process_matches timer_matches domain_command_matches fixture_process_matches
  local process_count timer_count domain_command_count fixture_process_count
  local process_digest timer_digest domain_command_digest fixture_process_digest
  printf 'quickshell-services: assert_no_view_processes_for_migrated_domains\n'
  process_matches=$(rg --no-filename -g '*.qml' '(^|[[:space:]])Process[[:space:]]*\{' "$repo_root"/home/configs/quickshell* || true)
  timer_matches=$(rg --no-filename -g '*.qml' '(^|[[:space:]])Timer[[:space:]]*\{' "$repo_root"/home/configs/quickshell* || true)
  domain_command_matches=$(rg --no-filename -i -g '*.qml' 'wpctl|nmcli|bluetoothctl|upower|brightnessctl' "$repo_root"/home/configs/quickshell* || true)
  fixture_process_matches=$(rg --no-filename -g '*.qml' '(^|[[:space:]])Process[[:space:]]*\{' "$repo_root/tests/quickshell" || true)
  process_count=$(printf '%s\n' "$process_matches" | sed '/^$/d' | wc -l)
  timer_count=$(printf '%s\n' "$timer_matches" | sed '/^$/d' | wc -l)
  domain_command_count=$(printf '%s\n' "$domain_command_matches" | sed '/^$/d' | wc -l)
  fixture_process_count=$(printf '%s\n' "$fixture_process_matches" | sed '/^$/d' | wc -l)
  process_digest=$(printf '%s\n' "$process_matches" | sort | sha256sum | awk '{ print $1 }')
  timer_digest=$(printf '%s\n' "$timer_matches" | sort | sha256sum | awk '{ print $1 }')
  domain_command_digest=$(printf '%s\n' "$domain_command_matches" | sort | sha256sum | awk '{ print $1 }')
  fixture_process_digest=$(printf '%s\n' "$fixture_process_matches" | sort | sha256sum | awk '{ print $1 }')
  printf 'quickshell-services: production baseline Process=%s:%s Timer=%s:%s domain-command=%s:%s\n' \
    "$process_count" "$process_digest" "$timer_count" "$timer_digest" \
    "$domain_command_count" "$domain_command_digest"
  printf 'quickshell-services: fixture baseline Process=%s:%s (excluded from production)\n' \
    "$fixture_process_count" "$fixture_process_digest"
  local production_dir="$repo_root/home/configs/quickshell"
  local shell="$production_dir/shell.qml"
  local audio_service="$production_dir/services/AudioService.qml"
  local audio_backend="$production_dir/services/internal/PipewireAudioBackend.qml"
  local media_service="$production_dir/services/MediaService.qml"
  local media_model="$production_dir/services/internal/MediaModel.qml"
  local media_popup="$production_dir/MediaPopup.qml"
  local cava_service="$production_dir/services/CavaService.qml"
  local power_service="$production_dir/services/PowerService.qml"
  local power_model="$production_dir/services/internal/PowerModel.qml"
  local power_backend="$production_dir/services/internal/UPowerBackend.qml"
  local view

  rg -q '^import Quickshell\.Services\.Pipewire$' "$audio_backend" \
    || fail 'PipewireAudioBackend.qml must import Quickshell.Services.Pipewire'
  rg -q 'PwObjectTracker[[:space:]]*\{' "$audio_backend" \
    || fail 'PipewireAudioBackend.qml must instantiate PwObjectTracker'
  rg -q 'Internal\.PipewireAudioBackend[[:space:]]*\{' "$audio_service" \
    || fail 'AudioService.qml must compose the native backend'
  rg -q 'Internal\.AudioModel[[:space:]]*\{' "$audio_service" \
    || fail 'AudioService.qml must compose the backend-free model'
  ! rg -n 'Quickshell\.Services\.Pipewire|PwObjectTracker|property[^:]*\b(sink|sinkAudio|backend|current[A-Z][A-Za-z]*)\b' "$audio_service" \
    || fail 'AudioService.qml exposes native objects or writable model state'
  ! rg -n -i '(^|[[:space:]])Process[[:space:]]*\{|wpctl|pw-mon|commandQueue|enqueueCommand|probeDebounce|(^|[[:space:]])Timer[[:space:]]*\{' "$audio_service" \
    || fail 'AudioService.qml still contains the command-backed audio backend'

  for view in Topbar.qml VolumePopup.qml MediaPopup.qml; do
    ! rg -n -i 'wpctl|pw-mon' "$production_dir/$view" \
      || fail "$view still owns system-sink audio commands"
  done
  ! rg -n -i -g '*.qml' -g '!AudioService.qml' 'wpctl|pw-mon|pavucontrol' "$production_dir" \
    || fail 'system-sink audio command construction exists outside AudioService.qml'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{' "$production_dir/VolumePopup.qml" \
    || fail 'VolumePopup.qml still owns a Process'
  [ "$(rg -o 'Services\.AudioService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.AudioService'
  rg -q 'id:[[:space:]]*audioService' "$shell" \
    || fail 'production shell.qml must name the AudioService audioService'
  for view in Topbar VolumePopup; do
    rg -q "${view}[[:space:]]*\{" "$shell" \
      || fail "production shell.qml is missing $view"
    rg -U -q "${view}[[:space:]]*\{[^}]*audioService:[[:space:]]*audioService" "$shell" \
      || fail "production shell.qml does not wire audioService directly to $view"
  done
  rg -U -q 'Services\.MediaService[[:space:]]*\{[^}]*audioService:[[:space:]]*audioService' "$shell" \
    || fail 'production shell.qml does not wire AudioService directly to MediaService'
  ! rg -n 'topbar\.(volume|setVolume|adjustVolume|toggleMute|openMixer|run\([^\n]*(wpctl|pavucontrol))' \
    "$production_dir/VolumePopup.qml" "$production_dir/MediaPopup.qml" "$shell" \
    || fail 'migrated popups still route audio through topbar'

  [ -f "$media_service" ] || fail 'MediaService.qml is missing'
  [ -f "$media_model" ] || fail 'MediaModel.qml is missing'
  rg -q 'Internal\.MediaModel[[:space:]]*\{' "$media_service" \
    || fail 'MediaService.qml must compose the deep internal MediaModel'
  ! rg -n '(^|[[:space:]])(Process|Timer)[[:space:]]*\{|property[^:]*[[:space:]]_[A-Za-z]|_requestSnapshot|_applySnapshot|_enqueue|_startNext|_action|playerctl|refreshDebounce' "$media_service" \
    || fail 'MediaService.qml leaks mutable media ownership instead of remaining a thin facade'
  ! rg -U -q 'function _action\([^}]*refreshDebounce\.restart\(' "$media_model" \
    || fail 'MediaModel actions must schedule reconciliation after completion, not enqueue time'
  ! rg -U -q 'job && job\.reconcileAfter[^}]*_requestSnapshot\(' "$media_model" \
    || fail 'MediaModel action completion must reconcile through the debounce policy'
  [ "$(rg '^[[:space:]]*(required[[:space:]]+)?property' "$media_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = $'property bool detailedMonitoring: false\nrequired property AudioService audioService' ] \
    || fail 'MediaService.qml exposes writable properties beyond audioService and detailedMonitoring'
  for public_property in available playing status title artist album artUrl positionSeconds lengthSeconds effectiveVolume shuffleEnabled volumeIsPlayer loopMode canSeek canTogglePlaying canGoNext canGoPrevious canShuffle canLoop canSetPlayerVolume; do
    rg -q "readonly property [^:]* ${public_property}:" "$media_service" \
      || fail "MediaService.qml is missing readonly public property: $public_property"
  done
  [ "$(rg -o 'Services\.MediaService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.MediaService'
  ! rg -n -i -g '*.qml' -g '!MediaService.qml' -g '!MediaModel.qml' 'playerctl' "$production_dir" \
    || fail 'playerctl media commands exist outside the MediaService implementation'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io' "$media_popup" \
    || fail 'MediaPopup.qml still owns media processes, timers, or Quickshell.Io'
  ! rg -n 'media(Status|Title|Artist|Album|ArtUrl)|mediaFollowProc' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns media scalar state or follow process'
  rg -q 'required property Services\.MediaService mediaService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require MediaService'
  rg -q 'required property Services\.MediaService mediaService' "$media_popup" \
    || fail 'MediaPopup.qml must require MediaService'
  for signature in \
    'function togglePlaying(): void' \
    'function next(): void' \
    'function previous(): void' \
    'function seek(seconds: real): void' \
    'function toggleShuffle(): void' \
    'function cycleLoop(): void' \
    'function setEffectiveVolume(value: real): void'; do
    rg -F -q "$signature" "$media_service" \
      || fail "MediaService.qml is missing typed action signature: $signature"
  done
  ! rg -U -q 'onDetailedMonitoringChanged:[^\n]*refreshDebounce|onDetailedMonitoringChanged:[[:space:]]*\{[^}]*refreshDebounce' "$media_service" \
    || fail 'MediaService detailedMonitoring enable must not schedule the follow debounce timer'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*mediaService:[[:space:]]*mediaService' "$shell" \
    || fail 'production shell.qml does not wire MediaService directly to Topbar'
  rg -U -q 'MediaPopup[[:space:]]*\{[^}]*mediaService:[[:space:]]*mediaService' "$shell" \
    || fail 'production shell.qml does not wire MediaService directly to MediaPopup'
  ! rg -n 'status:[[:space:]]*topbar\.media|track:[[:space:]]*topbar\.media|artist:[[:space:]]*topbar\.media|album:[[:space:]]*topbar\.media|artUrl:[[:space:]]*topbar\.media' "$shell" \
    || fail 'MediaPopup still receives media state through Topbar'

  [ -f "$cava_service" ] || fail 'CavaService.qml is missing'
  [ "$(rg '^[[:space:]]*property' "$cava_service" | rg -v 'readonly property|property[^:]* _' | sed 's/^[[:space:]]*//' | sort)" = $'property bool playing: false\nproperty bool requested: false' ] \
    || fail 'CavaService.qml public demand contract or private state changed unexpectedly'
  rg -q 'readonly property list<int> values:' "$cava_service" \
    || fail 'CavaService.qml must expose typed readonly values'
  if ! rg -q '^bars = 12$' "$production_dir/cava-bar.conf" \
    || ! rg -q '^var barCount = 12;$' "$production_dir/services/internal/CavaParser.js"; then
    fail 'Cava parser width must match cava-bar.conf'
  fi
  rg -U -q 'command:[[:space:]]*\["setpriv",[[:space:]]*"--pdeathsig",[[:space:]]*"TERM",[[:space:]]*"--",[[:space:]]*"cava",[[:space:]]*"-p",[[:space:]]*root\._configPath\]' "$cava_service" \
    || fail 'CavaService.qml must own the parent-death-protected Cava command'
  [ "$(rg -o 'Services\.CavaService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one CavaService'
  rg -U -q 'Services\.CavaService[[:space:]]*\{[^}]*playing:[[:space:]]*mediaService\.playing[^}]*requested:[[:space:]]*topbar\.cavaRequested[[:space:]]*\|\|[[:space:]]*mediaPopup\.active' "$shell" \
    || fail 'production shell.qml must bind exact media, bar, and popup Cava demand'
  rg -q 'required property Services\.CavaService cavaService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require CavaService'
  rg -q 'readonly property bool cavaRequested:[[:space:]]*mediaPill\.visible' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml Cava demand must exactly follow mediaPill.visible'
  rg -q 'required property Services\.CavaService cavaService' "$media_popup" \
    || fail 'MediaPopup.qml must require CavaService'
  ! rg -n 'cavaConfigPath|cavaProc|property var cavaValues|setpriv[^\n]*cava|command:[^\n]*cava' \
    "$production_dir/Topbar.qml" "$media_popup" \
    || fail 'Cava process, parsing, or writable values remain in presentation files'
  rg -q 'model:[[:space:]]*topbarWindow\.cavaService\.values' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must render CavaService values directly'
  rg -q 'model:[[:space:]]*root\.cavaService\.values' "$media_popup" \
    || fail 'MediaPopup.qml must render CavaService values directly'

  [ -f "$power_service" ] || fail 'PowerService.qml is missing'
  [ -f "$power_model" ] || fail 'PowerModel.qml is missing'
  [ -f "$power_backend" ] || fail 'UPowerBackend.qml is missing'
  rg -q '^import Quickshell\.Services\.UPower$' "$power_backend" \
    || fail 'UPowerBackend.qml must import Quickshell.Services.UPower'
  rg -q 'UPower\.displayDevice' "$power_backend" \
    || fail 'UPowerBackend.qml must read UPower.displayDevice'
  rg -q 'PowerProfiles\.profile' "$power_backend" \
    || fail 'UPowerBackend.qml must read or write PowerProfiles.profile'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io' "$power_backend" \
    || fail 'UPowerBackend.qml must stay a pure native reader/writer with no subprocess ownership'
  rg -q 'Internal\.UPowerBackend[[:space:]]*\{' "$power_service" \
    || fail 'PowerService.qml must compose the native UPower/PowerProfiles backend'
  rg -q 'Internal\.PowerModel[[:space:]]*\{' "$power_service" \
    || fail 'PowerService.qml must compose the deep internal PowerModel'
  rg -U -q 'Internal\.PowerModel[[:space:]]*\{[^}]*backend:[[:space:]]*backend' "$power_service" \
    || fail 'PowerService.qml must wire the native backend directly into PowerModel'
  [ "$(rg '^[[:space:]]*property' "$power_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool detailedMonitoring: false' ] \
    || fail 'PowerService.qml must expose only the narrow detailed-monitoring demand input'
  ! rg -n 'Quickshell\.Services\.UPower|PowerProfiles|property[^:]*\b(device|backend)\b' "$power_service" \
    || fail 'PowerService.qml exposes native power objects or writable backend state'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|"upower"|"powerprofilesctl"' "$power_service" \
    || fail 'PowerService.qml still contains subprocess-backed power adapters'
  ! rg -n 'Quickshell\.Services\.UPower' "$power_model" \
    || fail 'PowerModel.qml must not import native UPower services directly; use the backend'
  ! rg -n -g '*.qml' '"upower"|"powerprofilesctl"' "$production_dir" \
    || fail 'upower/powerprofilesctl command literals remain in production Quickshell QML'
  [ "$(rg -o 'Services\.PowerService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one PowerService'
  for view in Topbar.qml BatteryPopup.qml; do
    rg -q 'required property Services\.PowerService powerService' "$production_dir/$view" \
      || fail "$view must require PowerService"
  done
  rg -U -q 'Topbar[[:space:]]*\{[^}]*powerService:[[:space:]]*powerService' "$shell" \
    || fail 'production shell.qml does not wire PowerService directly to Topbar'
  rg -U -q 'BatteryPopup[[:space:]]*\{[^}]*powerService:[[:space:]]*powerService' "$shell" \
    || fail 'production shell.qml does not wire PowerService directly to BatteryPopup'
  rg -U -q 'Services\.PowerService[[:space:]]*\{[^}]*detailedMonitoring:[[:space:]]*batteryPopup\.shown' "$shell" \
    || fail 'production shell.qml must bind power cadence demand to BatteryPopup shown state'
  rg -q 'interval:[[:space:]]*root\.detailedMonitoring \? 5000 : 30000' "$power_model" \
    || fail 'PowerModel cadence must be five seconds shown and thirty seconds hidden'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|upower|powerprofilesctl|charge_control_end_threshold|stasis' \
    "$production_dir/BatteryPopup.qml" \
    || fail 'BatteryPopup.qml still owns power processes, timers, imports, or command construction'
  ! rg -n 'batteryPercent|powerProfileOrder|property string powerProfile|setPowerProfile|powerprofilesctl|/sys/class/power_supply/BAT' \
    "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns power state, parsing, or command construction'
  rg -U -q 'function batteryIcon\(\)[^{]*\{[^}]*if \(!topbarWindow\.powerService\.available\)[[:space:]]*return "󰁹"' \
    "$production_dir/Topbar.qml" \
    || fail 'Topbar unavailable battery icon no longer preserves the previous full/default visual'
  rg -q 'powerService\.state === "full" \? "fully charged"' "$production_dir/BatteryPopup.qml" \
    || fail 'BatteryPopup full state no longer renders as fully charged'
  for signature in \
    'function setProfile(profile: string): void' \
    'function cycleProfile(direction: int): void' \
    'function setChargeLimit(percent: int): void' \
    'function toggleChargeLimit(): void' \
    'function toggleIdleInhibit(): void'; do
    rg -F -q "$signature" "$power_service" \
      || fail "PowerService.qml is missing typed action signature: $signature"
  done

  local system_service="$production_dir/services/SystemService.qml"
  local system_model="$production_dir/services/internal/SystemModel.qml"
  local system_popup="$production_dir/SystemPopup.qml"
  [ -f "$system_service" ] || fail 'SystemService.qml is missing'
  [ -f "$system_model" ] || fail 'SystemModel.qml is missing'
  rg -q 'Internal\.SystemModel[[:space:]]*\{' "$system_service" \
    || fail 'SystemService.qml must compose the deep internal SystemModel'
  [ "$(rg '^[[:space:]]*property' "$system_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool detailedMonitoring: false' ] \
    || fail 'SystemService.qml must expose only the narrow detailed-monitoring demand input'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"lock-screen"|"systemctl"' "$system_service" \
    || fail 'SystemService.qml must stay a thin facade with no owned processes or command literals'
  for public_property in available cpuPercent ramUsedGiB ramPercent diskPercent hostName kernel uptime nixGeneration lastError; do
    rg -q "readonly property [^:]* ${public_property}:" "$system_service" \
      || fail "SystemService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function lock(): void' \
    'function suspend(): void' \
    'function reboot(): void' \
    'function powerOff(): void'; do
    rg -F -q "$signature" "$system_service" \
      || fail "SystemService.qml is missing typed action signature: $signature"
  done
  rg -U -q 'execDetached\(\["lock-screen"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact lock-screen argv'
  rg -U -q 'execDetached\(\["systemctl",[[:space:]]*"suspend"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact systemctl suspend argv'
  rg -U -q 'execDetached\(\["systemctl",[[:space:]]*"reboot"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact systemctl reboot argv'
  rg -U -q 'execDetached\(\["systemctl",[[:space:]]*"poweroff"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact systemctl poweroff argv'
  ! rg -n -i -g '*.qml' -g '!SystemModel.qml' 'lock-screen|"systemctl"' "$production_dir" \
    || fail 'lock-screen/systemctl command construction exists outside SystemModel.qml'
  [ "$(rg -o 'Services\.SystemService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.SystemService'
  rg -q 'id:[[:space:]]*systemService' "$shell" \
    || fail 'production shell.qml must name the SystemService systemService'
  for view in Topbar SystemPopup; do
    rg -q "${view}[[:space:]]*\{" "$shell" \
      || fail "production shell.qml is missing $view"
    rg -U -q "${view}[[:space:]]*\{[^}]*systemService:[[:space:]]*systemService" "$shell" \
      || fail "production shell.qml does not wire systemService directly to $view"
  done
  rg -U -q 'Services\.SystemService[[:space:]]*\{[^}]*detailedMonitoring:[[:space:]]*systemPopup\.shown' "$shell" \
    || fail 'production shell.qml must bind system metadata cadence demand to SystemPopup shown state'
  rg -q 'required property Services\.SystemService systemService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require SystemService'
  rg -q 'required property Services\.SystemService systemService' "$system_popup" \
    || fail 'SystemPopup.qml must require SystemService'
  ! rg -n 'statsProc|cpuUsage|ramUsage|diskUsage' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns cpu/ram/disk metrics state or the composite stats process'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io' "$system_popup" \
    || fail 'SystemPopup.qml still owns processes, timers, or Quickshell.Io'
  ! rg -n '/proc/stat|/proc/meminfo|"df"|df -P|hostnamectl|uname -r|readlink[^\n]*nix' "$system_popup" \
    || fail 'SystemPopup.qml still constructs system-metrics or metadata commands'
  ! rg -n '"niri"|niri msg' "$system_popup" \
    || fail 'SystemPopup.qml must not contain any niri command construction; logout is a NiriService action'
  ! rg -n 'niri msg action quit -s' "$system_service" "$system_model" \
    || fail 'Niri session logout must remain a NiriService action, not SystemService'

  local niri_service="$production_dir/services/NiriService.qml"
  local niri_model="$production_dir/services/internal/NiriModel.qml"
  local niri_parser="$production_dir/services/internal/NiriParser.js"
  [ -f "$niri_service" ] || fail 'NiriService.qml is missing'
  [ -f "$niri_model" ] || fail 'NiriModel.qml is missing'
  [ -f "$niri_parser" ] || fail 'NiriParser.js is missing'
  rg -q 'Internal\.NiriModel[[:space:]]*\{' "$niri_service" \
    || fail 'NiriService.qml must compose the deep internal NiriModel'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"niri"' "$niri_service" \
    || fail 'NiriService.qml must stay a thin facade with no owned processes or command literals'
  for public_property in activeWorkspaceId workspaces focusedTitle focusedAppId streamHealthy lastError; do
    rg -q "readonly property [^:]* ${public_property}:" "$niri_service" \
      || fail "NiriService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function focusWorkspace(id: int): void' \
    'function focusAdjacent(direction: int): void' \
    'function quitSession(): void'; do
    rg -F -q "$signature" "$niri_service" \
      || fail "NiriService.qml is missing typed action signature: $signature"
  done
  rg -U -q 'command:[[:space:]]*\["niri",[[:space:]]*"msg",[[:space:]]*"-j",[[:space:]]*"workspaces"\]' "$niri_model" \
    || fail 'NiriModel.qml must own the exact direct workspaces snapshot argv'
  rg -U -q 'command:[[:space:]]*\["niri",[[:space:]]*"msg",[[:space:]]*"-j",[[:space:]]*"focused-window"\]' "$niri_model" \
    || fail 'NiriModel.qml must own the exact direct focused-window snapshot argv'
  rg -U -q 'command:[[:space:]]*\["setpriv",[[:space:]]*"--pdeathsig",[[:space:]]*"TERM",[[:space:]]*"--",[[:space:]]*"niri",[[:space:]]*"msg",[[:space:]]*"-j",[[:space:]]*"event-stream"\]' "$niri_model" \
    || fail 'NiriModel.qml must own the exact parent-death-protected event-stream argv'
  rg -U -q 'execDetached\(\["niri",[[:space:]]*"msg",[[:space:]]*"action",[[:space:]]*"focus-workspace",[[:space:]]*String\(id\)\]\)' "$niri_model" \
    || fail 'NiriModel.qml must own the exact focus-workspace argv'
  rg -U -q 'execDetached\(\["niri",[[:space:]]*"msg",[[:space:]]*"action",[[:space:]]*direction < 0 \? "focus-workspace-up" : "focus-workspace-down"\]\)' "$niri_model" \
    || fail 'NiriModel.qml must own the exact focus-workspace-up/down argv'
  rg -U -q 'execDetached\(\["niri",[[:space:]]*"msg",[[:space:]]*"action",[[:space:]]*"quit",[[:space:]]*"-s"\]\)' "$niri_model" \
    || fail 'NiriModel.qml must own the exact session quit argv'
  ! rg -n -i -g '*.qml' -g '!NiriModel.qml' -g '!NiriService.qml' '"niri"|niri msg' "$production_dir" \
    || fail 'niri command construction exists outside the NiriService implementation'
  [ "$(rg -o 'Services\.NiriService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.NiriService'
  rg -q 'id:[[:space:]]*niriService' "$shell" \
    || fail 'production shell.qml must name the NiriService niriService'
  for view in Topbar SystemPopup; do
    rg -U -q "${view}[[:space:]]*\{[^}]*niriService:[[:space:]]*niriService" "$shell" \
      || fail "production shell.qml does not wire niriService directly to $view"
  done
  rg -q 'required property Services\.NiriService niriService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require NiriService'
  rg -q 'required property Services\.NiriService niriService' "$system_popup" \
    || fail 'SystemPopup.qml must require NiriService'
  ! rg -n 'workspacesProc|titleProc|niriEventStream|\bactiveWorkspace\b|occupiedWorkspaces|\bworkspaceList\b' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns Niri processes, timers, parser state, or command construction'
  rg -q 'model:[[:space:]]*topbarWindow\.niriService\.workspaces' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must render NiriService workspaces directly'
  ! rg -n '\(topbarWindow\.activeWorkspace - 1\) \* 36' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml workspace indicator must not assume workspace id minus one'
  rg -q 'niriService\.focusWorkspace\(' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml workspace click must call niriService.focusWorkspace'
  rg -q 'niriService\.focusAdjacent\(' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml workspace wheel must call niriService.focusAdjacent'
  rg -q 'niriService\.quitSession\(\)' "$system_popup" \
    || fail 'SystemPopup.qml logout must call niriService.quitSession()'

  local network_service="$production_dir/services/NetworkService.qml"
  local network_backend="$production_dir/services/internal/NetworkBackend.qml"
  local network_model="$production_dir/services/internal/NetworkModel.qml"
  local network_parser="$production_dir/services/internal/NetworkParser.js"
  local network_reducer="$production_dir/services/internal/NetworkReducer.js"
  local wifi_popup="$production_dir/WifiPopup.qml"
  [ -f "$network_service" ] || fail 'NetworkService.qml is missing'
  [ -f "$network_backend" ] || fail 'NetworkBackend.qml is missing'
  [ -f "$network_model" ] || fail 'NetworkModel.qml is missing'
  [ -f "$network_parser" ] || fail 'NetworkParser.js is missing'
  [ -f "$network_reducer" ] || fail 'NetworkReducer.js is missing'
  rg -q '^import Quickshell\.Networking$' "$network_backend" \
    || fail 'NetworkBackend.qml must import Quickshell.Networking'
  rg -q 'Networking\.(backend|wifiEnabled|connectivity|devices)' "$network_backend" \
    || fail 'NetworkBackend.qml must read native Networking singleton state'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"nmcli"' "$network_backend" \
    || fail 'NetworkBackend.qml must not own processes, timers, or nmcli'
  rg -q 'Internal\.NetworkBackend[[:space:]]*\{' "$network_service" \
    || fail 'NetworkService.qml must compose the native NetworkBackend'
  rg -q 'Internal\.NetworkModel[[:space:]]*\{' "$network_service" \
    || fail 'NetworkService.qml must compose the deep internal NetworkModel'
  [ "$(rg '^[[:space:]]*property' "$network_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool scanningRequested: false' ] \
    || fail 'NetworkService.qml must expose only the narrow scanning-demand input'
  ! rg -n 'Quickshell\.Networking|property[^:]*\b(backend|wifiDevice|native)\b|(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"nmcli"' "$network_service" \
    || fail 'NetworkService.qml must stay a thin facade with no native objects, processes, or nmcli'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"nmcli"|Quickshell\.Networking' "$network_model" \
    || fail 'NetworkModel.qml must stay backend-free of Process/Timer/nmcli/Networking imports'
  for public_property in available wifiEnabled connected activeSsid activeSignal activeSecurity networks; do
    rg -q "readonly property [^:]* ${public_property}:" "$network_service" \
      || fail "NetworkService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function setWifiEnabled(enabled: bool): void' \
    'function connectKnown(ssid: string): void' \
    'function connectInteractive(ssid: string): void' \
    'function openSettings(): void'; do
    rg -F -q "$signature" "$network_service" \
      || fail "NetworkService.qml is missing typed action signature: $signature"
  done
  rg -q 'interactiveConnectArgv|settingsArgv' "$network_parser" \
    || fail 'NetworkParser.js must own the kitty interactive/settings argv helpers'
  ! rg -n -i -g '*.qml' -g '*.js' 'nmcli' "$production_dir" \
    || fail 'nmcli command construction remains in production Quickshell code'
  [ "$(rg -o 'Services\.NetworkService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.NetworkService'
  rg -q 'id:[[:space:]]*networkService' "$shell" \
    || fail 'production shell.qml must name the NetworkService networkService'
  rg -U -q 'Services\.NetworkService[[:space:]]*\{[^}]*scanningRequested:[[:space:]]*wifiPopup\.shown' "$shell" \
    || fail 'production shell.qml must bind scanningRequested directly to WifiPopup shown state'
  for view in Topbar WifiPopup; do
    rg -U -q "${view}[[:space:]]*\{[^}]*networkService:[[:space:]]*networkService" "$shell" \
      || fail "production shell.qml does not wire networkService directly to $view"
  done
  rg -q 'required property Services\.NetworkService networkService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require NetworkService'
  rg -q 'required property Services\.NetworkService networkService' "$wifi_popup" \
    || fail 'WifiPopup.qml must require NetworkService'
  ! rg -n -i 'networkProc|nmcli|networkIcon:[[:space:]]*"' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns network connectivity state, the residual nmcli probe, or nmcli command construction'
  ! rg -n -i '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|nmcli' "$wifi_popup" \
    || fail 'WifiPopup.qml still owns network processes, timers, or nmcli command construction'
  rg -q 'networkService\.openSettings\(\)' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml right-click settings must call networkService.openSettings()'
  rg -q 'networkService\.setWifiEnabled\(' "$wifi_popup" \
    || fail 'WifiPopup.qml radio toggle must call networkService.setWifiEnabled'
  rg -q 'networkService\.connectKnown\(' "$wifi_popup" \
    || fail 'WifiPopup.qml known-network click must call networkService.connectKnown'
  rg -q 'networkService\.connectInteractive\(' "$wifi_popup" \
    || fail 'WifiPopup.qml unknown-network click must call networkService.connectInteractive'
  rg -q 'model:[[:space:]]*root\.networkService\.wifiEnabled[[:space:]]*\?[[:space:]]*root\.networkService\.networks' "$wifi_popup" \
    || fail 'WifiPopup.qml must render NetworkService networks directly'

  local bluetooth_service="$production_dir/services/BluetoothService.qml"
  local bluetooth_model="$production_dir/services/internal/BluetoothModel.qml"
  local bluetooth_parser="$production_dir/services/internal/BluetoothParser.js"
  local bluetooth_reducer="$production_dir/services/internal/BluetoothReducer.js"
  local bluetooth_popup="$production_dir/BluetoothPopup.qml"
  [ -f "$bluetooth_service" ] || fail 'BluetoothService.qml is missing'
  [ -f "$bluetooth_model" ] || fail 'BluetoothModel.qml is missing'
  [ -f "$bluetooth_parser" ] || fail 'BluetoothParser.js is missing'
  [ -f "$bluetooth_reducer" ] || fail 'BluetoothReducer.js is missing'
  rg -q 'Internal\.BluetoothModel[[:space:]]*\{' "$bluetooth_service" \
    || fail 'BluetoothService.qml must compose the deep internal BluetoothModel'
  [ "$(rg '^[[:space:]]*property' "$bluetooth_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool detailedMonitoring: false' ] \
    || fail 'BluetoothService.qml must expose only the narrow detailed-monitoring demand input'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"busctl"' "$bluetooth_service" \
    || fail 'BluetoothService.qml must stay a thin facade with no owned processes or command literals'
  for public_property in available enabled connectedCount devices; do
    rg -q "readonly property [^:]* ${public_property}:" "$bluetooth_service" \
      || fail "BluetoothService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function setEnabled(enabled: bool): void' \
    'function toggleDevice(id: string): void' \
    'function openManager(): void'; do
    rg -F -q "$signature" "$bluetooth_service" \
      || fail "BluetoothService.qml is missing typed action signature: $signature"
  done
  rg -q 'busctl' "$bluetooth_parser" \
    || fail 'BluetoothParser.js must own the busctl command construction'
  ! rg -n -i -g '*.qml' -g '*.js' -g '!BluetoothParser.js' -g '!BluetoothModel.qml' 'busctl|blueman-manager' "$production_dir" \
    || fail 'bluetooth command construction exists outside the BluetoothService implementation'
  [ "$(rg -o 'Services\.BluetoothService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.BluetoothService'
  rg -U -q 'Services\.BluetoothService[[:space:]]*\{[^}]*detailedMonitoring:[[:space:]]*bluetoothPopup\.shown' "$shell" \
    || fail 'production shell.qml must bind bluetooth cadence demand to BluetoothPopup shown state'
  for view in Topbar BluetoothPopup; do
    rg -U -q "${view}[[:space:]]*\{[^}]*bluetoothService:[[:space:]]*bluetoothService" "$shell" \
      || fail "production shell.qml does not wire bluetoothService directly to $view"
  done
  rg -q 'required property Services\.BluetoothService bluetoothService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require BluetoothService'
  rg -q 'required property Services\.BluetoothService bluetoothService' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml must require BluetoothService'
  ! rg -n -i '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|busctl|blueman' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml still owns bluetooth processes, timers, or command construction'
  rg -q 'bluetoothService\.openManager\(\)' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml right-click manager must call bluetoothService.openManager()'
  rg -q 'bluetoothService\.setEnabled\(' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml adapter toggle must call bluetoothService.setEnabled'
  rg -q 'bluetoothService\.toggleDevice\(' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml device click must call bluetoothService.toggleDevice'
}

if [ "${QS_TEST_FORCE_FAILURE_CHILD:-0}" = 1 ]; then
  run_forced_failure_child "${QS_TEST_PROBE_STATE_DIR:?QS_TEST_PROBE_STATE_DIR is required}"
fi

if [ "${QS_TEST_OVERLAP_TIMEOUT_PROBE_CHILD:-0}" = 1 ]; then
  run_overlap_descendant_probe
  exit 0
fi

if [ "${QS_TEST_TRANSIENT_TIMEOUT_PROBE_CHILD:-0}" = 1 ]; then
  run_transient_descendant_probe
  exit 0
fi

assert_native_probe_has_no_wpctl_dependency
assert_native_fixture_always_validates_public_contract
run_unit_tests
run_process_cleanup_fixture
run_native_construction_probes
run_media_service_probe
run_cava_service_probe
run_power_service_probe
run_power_destruction_probe probe
run_power_destruction_probe action
run_power_native_construction_probe
run_system_service_probe
run_niri_service_probe
run_network_native_construction_probe
run_bluetooth_service_probe
assert_no_view_processes_for_migrated_domains
