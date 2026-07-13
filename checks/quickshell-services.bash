#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_qml="${repo_root}/tests/quickshell/integration/process-cleanup"
fixture_bin="${repo_root}/tests/quickshell/fixtures/bin/qs-test-owned-process"
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

run_overlap_descendant_probe() {
  local state_dir prior_child fake_pid rc=0 record
  new_fixture_state
  state_dir=$fixture_state
  sleep 30 &
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
  sleep 0.2
  if kill -0 "$fake_pid" 2>/dev/null; then
    kill -TERM "$fake_pid" 2>/dev/null || true
  fi
  wait "$fake_pid" || rc=$?
  kill -TERM "$prior_child" 2>/dev/null || true
  wait "$prior_child" 2>/dev/null || true
  ((rc != 0)) || fail 'owned-process overlap probe accepted a live prior descendant with a dead parent'
  rg -q ' overlap-child ' "$state_dir/lifecycle.log" \
    || fail 'owned-process overlap probe did not record the live prior descendant'
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
  fi
  run_overlap_descendant_probe
  run_normal_fixture
  run_term_fixture
}

run_native_construction_probes() {
  printf 'quickshell-services: run_native_construction_probes\n'
  printf 'quickshell-services: SKIP no native service construction probes are registered\n'
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
  printf 'quickshell-services: SKIP no migrated domains are registered for structural rejection\n'
}

if [ "${QS_TEST_FORCE_FAILURE_CHILD:-0}" = 1 ]; then
  run_forced_failure_child "${QS_TEST_PROBE_STATE_DIR:?QS_TEST_PROBE_STATE_DIR is required}"
fi

run_unit_tests
run_process_cleanup_fixture
run_native_construction_probes
assert_no_view_processes_for_migrated_domains
