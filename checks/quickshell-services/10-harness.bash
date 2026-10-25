# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
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
  QS_TEST_FORCE_FAILURE_CHILD=1 QS_TEST_PROBE_STATE_DIR="$state_dir" bash "${repo_root}/checks/quickshell-services.bash" \
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
    timeout --signal=TERM --kill-after=2 30 bash "${repo_root}/checks/quickshell-services.bash" \
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
    timeout --signal=TERM --kill-after=2 30 bash "${repo_root}/checks/quickshell-services.bash" \
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
    timeout --signal=TERM --kill-after=2 8 bash "${repo_root}/checks/quickshell-services.bash" \
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
  # The overlap scan alone needs ~3s on a cold or loaded box (20 grace
  # iterations of fork-heavy liveness checks); 3s here flaked under load.
  wait_for_recorded_process "$fake_record" '' 10 || rc=$?
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
