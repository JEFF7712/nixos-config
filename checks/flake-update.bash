#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'chmod -R u+w "$tmpdir" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT
real_git="$(command -v git)"
real_mv="$(command -v mv)"
real_rm="$(command -v rm)"

repo="$tmpdir/repo"
bin_dir="$tmpdir/bin"
mkdir -p "$repo" "$bin_dir"
printf 'snapshot baseline\n' > "$repo/flake.nix"
printf 'mock baseline\n' > "$repo/flake.lock"
"$real_git" -C "$repo" init -q
"$real_git" -C "$repo" config user.name Fixture
"$real_git" -C "$repo" config user.email fixture@example.invalid
"$real_git" -C "$repo" add flake.nix flake.lock
"$real_git" -C "$repo" commit -qm fixture

make_fake() {
  local name="$1"
  cat > "$bin_dir/$name"
  chmod +x "$bin_dir/$name"
}

make_fake runuser <<'EOF'
#!/usr/bin/env bash
printf 'runuser %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
while [[ $# -gt 0 && "$1" != -- ]]; do shift; done
shift
exec "$@"
EOF

make_fake nix <<'EOF'
#!/usr/bin/env bash
printf 'nix %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
if [[ " $* " == *' flake update '* ]]; then
  flake_path=""
  for ((i = 1; i <= $#; i++)); do
    if [[ ${!i} == --flake ]]; then
      ((i += 1))
      flake_path="${!i#path:}"
      break
    fi
  done
  if [[ "${TEST_DIFF_STATUS:-0}" == 2 ]]; then
    rm -f "$flake_path/flake.lock"
  elif [[ "${TEST_MUTATE_LOCK:-}" == 1 || "${TEST_DIFF_STATUS:-0}" == 1 ]]; then
    if [[ -n ${TEST_MUTATED_LOCK_CONTENT:-} ]]; then
      printf '%s\n' "$TEST_MUTATED_LOCK_CONTENT" > "$flake_path/flake.lock"
    else
      printf 'mutated by update\n' > "$flake_path/flake.lock"
    fi
  fi
  if [[ "${TEST_MUTATE_CHECKOUT_AFTER_UPDATE:-}" == 1 ]]; then
    printf 'editable changed\n' > "$TEST_REPO/flake.nix"
  fi
fi
if [[ " $* " == *' eval '* ]]; then
  ref="${!#}"
  flake_path="${ref#path:}"
  flake_path="${flake_path%%#*}"
  printf 'eval-source %s\n' "$(cat "$flake_path/flake.nix")" >> "$COMMAND_LOG"
  exit "${TEST_EVAL_STATUS:-0}"
fi
exit "${TEST_UPDATE_STATUS:-0}"
EOF

make_fake git <<'EOF'
#!/usr/bin/env bash
printf 'git %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
if [[ "${TEST_REAL_GIT:-}" == 1 ]]; then
  exec "$REAL_GIT" "$@"
fi
case " $* " in
  *' archive --format=tar HEAD '*) exec "$REAL_GIT" "$@" ;;
  *' rev-parse HEAD '*) printf 'fixture-head\n' ;;
  *' show HEAD:flake.lock'*) printf 'mock baseline\n' ;;
  *' rev-parse --show-toplevel '*) printf '%s\n' "$TEST_REPO" ;;
  *' diff --quiet '*) exit "${TEST_DIFF_STATUS:-0}" ;;
  *' diff --exit-code '*) exit 0 ;;
  *' commit '*) exit "${TEST_COMMIT_STATUS:-0}" ;;
  *' status --porcelain '*) exit 0 ;;
esac
EOF

make_fake getent <<'EOF'
#!/usr/bin/env bash
printf 'getent %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
if [[ "$1" == passwd ]]; then
  printf 'rupan:x:1000:1000:Rupan:%s:/bin/bash\n' "$TEST_REPO"
  exit 0
fi
exit "${TEST_DNS_STATUS:-0}"
EOF

make_fake flock <<'EOF'
#!/usr/bin/env bash
printf 'flock %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
exit "${TEST_FLOCK_STATUS:-0}"
EOF

make_fake nix-cascade-guard <<'EOF'
#!/usr/bin/env bash
printf '%s' "${0##*/}" >> "$COMMAND_LOG"
printf ' %q' "$@" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
ref="$1"
flake_path="${ref#path:}"
flake_path="${flake_path%%#*}"
printf 'cascade-source %s\n' "$(cat "$flake_path/flake.nix")" >> "$COMMAND_LOG"
if [[ "${TEST_CASCADE_ACTION:-}" == term ]]; then
  kill -TERM "$PPID"
  sleep 1
fi
exit "${TEST_CASCADE_STATUS:-0}"
EOF

make_fake nixos-rebuild <<'EOF'
#!/usr/bin/env bash
printf '%s' "${0##*/}" >> "$COMMAND_LOG"
printf ' %q' "$@" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
while [[ $# -gt 0 ]]; do
  if [[ $1 == --flake ]]; then
    ref="$2"
    flake_path="${ref#path:}"
    flake_path="${flake_path%%#*}"
    printf 'rebuild-source %s\n' "$(cat "$flake_path/flake.nix")" >> "$COMMAND_LOG"
    break
  fi
  shift
done
exit "${TEST_REBUILD_STATUS:-0}"
EOF

make_fake mv <<'EOF'
#!/usr/bin/env bash
printf 'mv %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
source_path=""
destination=""
for argument in "$@"; do
  [[ $argument == -- || $argument == -* ]] && continue
  source_path="$destination"
  destination="$argument"
done
if [[ $destination == */state && $source_path == */.state.* ]]; then
  next_state="$(cat "$source_path")"
  if [[ ${TEST_MV_ACTION:-} == "$next_state-before" ]]; then
    kill -TERM "$PPID"
    sleep 1
    exit 0
  fi
  if [[ ${TEST_MV_ACTION:-} == "$next_state-after" ]]; then
    "$REAL_MV" "$@"
    kill -TERM "$PPID"
    sleep 1
    exit 0
  fi
fi
exec "$REAL_MV" "$@"
EOF

make_fake rm <<'EOF'
#!/usr/bin/env bash
printf 'rm %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
if [[ ${TEST_RM_ACTION:-} == retire-term ]]; then
  for argument in "$@"; do
    if [[ $argument == */retired-* ]]; then
      kill -TERM "$PPID"
      sleep 1
      exit 0
    fi
  done
fi
exec "$REAL_RM" "$@"
EOF

fail() {
  printf '%s\n' "$1" >&2
  cat "$COMMAND_LOG" >&2
  exit 1
}

assert_status() {
  local expected="$1" actual="$2" name="$3"
  [[ $actual -eq $expected ]] || fail "$name expected status $expected, got $actual"
}

assert_log_has() {
  local line="$1" name="$2"
  grep -Fqx -- "$line" "$COMMAND_LOG" || fail "$name missing exact log line: $line"
}

assert_log_lacks() {
  local text="$1" name="$2"
  ! grep -Fq -- "$text" "$COMMAND_LOG" || fail "$name unexpectedly logged: $text"
}

assert_output_has() {
  local text="$1" name="$2"
  grep -Fq -- "$text" "$CASE_DIR/output.log" ||
    fail "$name missing output: $text"
}

assert_lock_restored() {
  local name="$1"
  cmp -s "$CASE_DIR/expected.lock" "$repo/flake.lock" ||
    fail "$name did not restore the pre-update flake.lock exactly"
}

assert_one_update() {
  local expected_inputs="$1" name="$2" count=0 line update_line=""
  while IFS= read -r line; do
    if [[ $line == *'nix flake update'* && $line != *'runuser '* ]]; then
      ((count += 1))
      update_line="$line"
    fi
  done < "$COMMAND_LOG"
  [[ $count -eq 1 ]] || fail "$name expected one update invocation, got $count"
  [[ $update_line == nix\ flake\ update\ --flake\ path:"$CASE_DIR"/state/.candidate-*/candidate"$expected_inputs" ]] ||
    fail "$name used an unexpected update command: $update_line"
}

assert_before() {
  local first="$1" second="$2" name="$3" line
  local first_line=0 second_line=0 line_number=0
  while IFS= read -r line; do
    ((line_number += 1))
    [[ $line == "$first" ]] && first_line=$line_number
    [[ $line == "$second" ]] && second_line=$line_number
  done < "$COMMAND_LOG"
  [[ $first_line -gt 0 && $second_line -gt 0 && $first_line -lt $second_line ]] ||
    fail "$name expected ordered lines: $first before $second"
}

run_pipeline() {
  local variant="${1:-weekly}"
  local eval_failure="${2:-}"
  local label="$variant"
  [[ $variant == ai ]] && label="AI tools"
  local command_log="$CASE_DIR/commands.log"
  local output_log="$CASE_DIR/output.log"
  : > "$command_log"
  : > "$output_log"
  local -a args=(
    --label "$label"
    --repo "$repo"
    --target "path:$repo#laptop"
    --commit-message "flake.lock: $variant auto-update"
  )
  if [[ $variant == ai ]]; then
    args+=(--input claude-code-nix --input codex-cli-nix --input code-cursor-nix --input opencode-nix)
  fi
  if [[ -n $eval_failure ]]; then
    args+=(--eval-failure "$eval_failure")
  fi
  set +e
  PATH="$bin_dir:$PATH" \
    COMMAND_LOG="$command_log" \
    TEST_REPO="$repo" \
    UPDATE_LOCK="$CASE_DIR/update.lock" \
    DNS_RETRIES=1 \
    DNS_RETRY_DELAY=0 \
    CASCADE_GUARD="$bin_dir/nix-cascade-guard" \
    NIXOS_REBUILD="$bin_dir/nixos-rebuild" \
    REAL_GIT="${REAL_GIT:-$real_git}" \
    REAL_MV="$real_mv" \
    REAL_RM="$real_rm" \
    TEST_REAL_GIT="${TEST_REAL_GIT:-0}" \
    TEST_MUTATE_LOCK="${TEST_MUTATE_LOCK:-0}" \
    TEST_MUTATE_CHECKOUT_AFTER_UPDATE="${TEST_MUTATE_CHECKOUT_AFTER_UPDATE:-0}" \
    TEST_MV_ACTION="${TEST_MV_ACTION:-}" \
    TEST_RM_ACTION="${TEST_RM_ACTION:-}" \
    TEST_MUTATED_LOCK_CONTENT="${TEST_MUTATED_LOCK_CONTENT:-}" \
    TEST_UPDATE_STATUS="${TEST_UPDATE_STATUS:-0}" \
    TEST_DIFF_STATUS="${TEST_DIFF_STATUS:-0}" \
    TEST_EVAL_STATUS="${TEST_EVAL_STATUS:-0}" \
    TEST_COMMIT_STATUS="${TEST_COMMIT_STATUS:-0}" \
    TEST_CASCADE_STATUS="${TEST_CASCADE_STATUS:-0}" \
    TEST_CASCADE_ACTION="${TEST_CASCADE_ACTION:-}" \
    TEST_FLOCK_STATUS="${TEST_FLOCK_STATUS:-0}" \
    TEST_DNS_STATUS="${TEST_DNS_STATUS:-0}" \
    TEST_REBUILD_STATUS="${TEST_REBUILD_STATUS:-0}" \
    STATE_DIRECTORY="$CASE_DIR/state" \
    home/scripts/nixos-flake-update "${args[@]}" >"$output_log" 2>&1
  PIPELINE_STATUS=$?
  set -e
}

setup_case() {
  CASE_DIR="$tmpdir/$1"
  COMMAND_LOG="$CASE_DIR/commands.log"
  mkdir -p "$CASE_DIR"
  : > "$COMMAND_LOG"
  if [[ $repo == "$tmpdir/repo" ]]; then
    printf 'snapshot baseline\n' > "$repo/flake.nix"
    printf 'mock baseline\n' > "$repo/flake.lock"
  fi
  cp -p "$repo/flake.lock" "$CASE_DIR/expected.lock"
  unset TEST_UPDATE_STATUS TEST_DIFF_STATUS TEST_EVAL_STATUS TEST_COMMIT_STATUS TEST_CASCADE_STATUS
  unset TEST_CASCADE_ACTION TEST_FLOCK_STATUS TEST_DNS_STATUS TEST_REBUILD_STATUS
  unset TEST_REAL_GIT TEST_MUTATE_LOCK REAL_GIT
  unset TEST_MUTATE_CHECKOUT_AFTER_UPDATE TEST_MV_ACTION TEST_RM_ACTION
  unset TEST_MUTATED_LOCK_CONTENT
}

update_weekly=""
update_ai=" claude-code-nix codex-cli-nix code-cursor-nix opencode-nix"
commit_weekly="git -C $repo commit -m flake.lock:\ weekly\ auto-update -- flake.lock"

case_unchanged() {
  run_pipeline
  assert_one_update "$update_weekly" unchanged
  assert_log_lacks 'nix-cascade-guard ' unchanged
  assert_log_lacks ' commit ' unchanged
  assert_log_lacks 'nixos-rebuild ' unchanged
}

case_ai_inputs() {
  run_pipeline ai
  assert_one_update "$update_ai" ai_inputs
}

case_lock_contention() {
  TEST_FLOCK_STATUS=1 run_pipeline
  assert_log_lacks 'nix flake update' lock_contention
}

case_dns_timeout() {
  TEST_DNS_STATUS=1 run_pipeline
  assert_log_lacks 'nix flake update' dns_timeout
}

case_eval_failure_hard() {
  TEST_MUTATE_LOCK=1 TEST_EVAL_STATUS=1 run_pipeline weekly hard
  assert_lock_restored eval_failure_hard
  assert_output_has 'weekly update fails eval; flake.lock reverted' eval_failure_hard
  assert_log_lacks 'nix-cascade-guard ' eval_failure_hard
  assert_log_lacks ' commit ' eval_failure_hard
  assert_log_lacks 'nixos-rebuild ' eval_failure_hard
}

case_eval_failure_default_hard() {
  TEST_MUTATE_LOCK=1 TEST_EVAL_STATUS=1 run_pipeline
  assert_lock_restored eval_failure_default_hard
  assert_output_has 'weekly update fails eval; flake.lock reverted' eval_failure_default_hard
  assert_log_lacks 'nix-cascade-guard ' eval_failure_default_hard
  assert_log_lacks ' commit ' eval_failure_default_hard
  assert_log_lacks 'nixos-rebuild ' eval_failure_default_hard
}

case_eval_failure_defer() {
  TEST_MUTATE_LOCK=1 TEST_EVAL_STATUS=1 run_pipeline ai defer
  assert_lock_restored eval_failure_defer
  assert_output_has \
    'AI tools update deferred: updated inputs fail eval; flake.lock reverted, will retry next run' \
    eval_failure_defer
  assert_log_lacks 'nix-cascade-guard ' eval_failure_defer
  assert_log_lacks ' commit ' eval_failure_defer
  assert_log_lacks 'nixos-rebuild ' eval_failure_defer
}

case_invalid_eval_failure() {
  run_pipeline weekly invalid
  assert_output_has \
    'invalid --eval-failure: invalid (expected hard or defer)' \
    invalid_eval_failure
  assert_log_lacks 'nix flake update' invalid_eval_failure
}

case_diff_error() {
  TEST_DIFF_STATUS=2 run_pipeline
  assert_log_lacks 'nix-cascade-guard ' diff_error
  assert_log_lacks ' commit ' diff_error
  assert_log_lacks 'nixos-rebuild ' diff_error
}

case_cascade_deferred() {
  TEST_DIFF_STATUS=1 TEST_CASCADE_STATUS=10 run_pipeline
  assert_log_lacks ' commit ' cascade_deferred
  assert_log_lacks 'nixos-rebuild ' cascade_deferred
}

case_cascade_error() {
  TEST_DIFF_STATUS=1 TEST_CASCADE_STATUS=7 run_pipeline
  assert_log_lacks ' commit ' cascade_error
  assert_log_lacks 'nixos-rebuild ' cascade_error
}

case_commit_failure() {
  TEST_DIFF_STATUS=1 TEST_COMMIT_STATUS=1 run_pipeline
  assert_status 1 "$PIPELINE_STATUS" commit_failure_first_run
  grep -q '^nixos-rebuild switch ' "$COMMAND_LOG" ||
    fail 'commit_failure did not activate the candidate before committing'
  [[ $(cat "$CASE_DIR/state/pending-weekly/state") == activated ]] ||
    fail 'commit_failure did not preserve activated candidate state'
  assert_lock_restored commit_failure

  TEST_DIFF_STATUS=1 run_pipeline
  assert_log_lacks 'nixos-rebuild ' commit_failure_retry
  assert_log_has "$commit_weekly" commit_failure_retry
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail 'commit_failure retry did not clear pending state'
}

case_success_order() {
  TEST_DIFF_STATUS=1 run_pipeline
  assert_log_has "$commit_weekly" success_order
  rebuild=$(grep -m1 '^nixos-rebuild switch ' "$COMMAND_LOG")
  [[ -n $rebuild ]] || fail 'success_order did not rebuild the candidate'
  assert_before "$rebuild" "$commit_weekly" success_order
}

case_rebuild_failure() {
  TEST_DIFF_STATUS=1 TEST_REBUILD_STATUS=5 run_pipeline
  assert_log_lacks ' commit ' rebuild_failure
  [[ -f $CASE_DIR/state/pending-weekly/candidate/flake.lock ]] ||
    fail 'rebuild_failure did not leave a durable pending candidate'
  [[ $(stat -c %a "$CASE_DIR/state/pending-weekly") == 755 ]] ||
    fail 'rebuild_failure pending candidate is not traversable by the activation user'
  assert_lock_restored rebuild_failure
}

case_pending_retry() {
  local retained_rebuild
  TEST_REAL_GIT=1 TEST_DIFF_STATUS=1 TEST_REBUILD_STATUS=5 run_pipeline
  assert_status 5 "$PIPELINE_STATUS" pending_retry_first_run
  [[ -d $CASE_DIR/state/pending-weekly/candidate ]] ||
    fail 'pending_retry first run did not leave a pending candidate'
  retained_rebuild="nixos-rebuild switch --flake path:$CASE_DIR/state/pending-weekly/candidate#laptop --option max-jobs 2 --option cores 8"
  assert_log_has "$retained_rebuild" pending_retry_first_run
  assert_one_update "$update_weekly" pending_retry_first_run
  [[ ! -w $CASE_DIR/state/pending-weekly/candidate/flake.lock ]] ||
    fail 'pending_retry candidate is mutable before retry'

  TEST_REAL_GIT=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" pending_retry_second_run
  assert_log_has "$retained_rebuild" pending_retry_second_run
  assert_log_lacks 'nix flake update' pending_retry_second_run
  [[ $("$real_git" -C "$repo" show -s --format=%s HEAD) == 'flake.lock: weekly auto-update' ]] ||
    fail 'pending_retry did not create the expected flake.lock commit'
  cmp -s "$repo/flake.lock" "$CASE_DIR/state/deployed-weekly.lock" ||
    fail 'pending_retry did not record the deployed candidate lock'
  "$real_git" -C "$repo" diff --quiet -- flake.lock ||
    fail 'pending_retry did not publish the candidate flake.lock cleanly'
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail 'pending_retry did not clear pending state after success'
}

case_candidate_isolation() {
  local retained_rebuild
  TEST_DIFF_STATUS=1 TEST_MUTATE_CHECKOUT_AFTER_UPDATE=1 TEST_REBUILD_STATUS=5 run_pipeline
  assert_status 5 "$PIPELINE_STATUS" candidate_isolation_first_run
  assert_log_has 'eval-source snapshot baseline' candidate_isolation
  assert_log_has 'cascade-source snapshot baseline' candidate_isolation
  assert_log_has 'rebuild-source snapshot baseline' candidate_isolation
  assert_log_lacks "path:$repo#nixosConfigurations" candidate_isolation
  assert_log_lacks "--flake path:$repo#laptop" candidate_isolation
  retained_rebuild="nixos-rebuild switch --flake path:$CASE_DIR/state/pending-weekly/candidate#laptop --option max-jobs 2 --option cores 8"

  run_pipeline
  assert_status 0 "$PIPELINE_STATUS" candidate_isolation_second_run
  assert_log_has "$retained_rebuild" candidate_isolation_second_run
  assert_log_has 'rebuild-source snapshot baseline' candidate_isolation
  assert_log_lacks 'nix flake update' candidate_isolation_second_run
}

case_termination() {
  TEST_DIFF_STATUS=1 TEST_CASCADE_ACTION=term run_pipeline
  assert_log_lacks ' commit ' termination
  assert_log_lacks 'nixos-rebuild ' termination
}

assert_valid_state() {
  local state_path="$1" name="$2" state
  state="$(cat "$state_path")"
  case "$state" in
    pending|activated|deployed) ;;
    *) fail "$name left an invalid state marker: $state" ;;
  esac
}

exercise_atomic_transition() {
  local action="$1" expected_state="$2" name="$3"
  TEST_REAL_GIT=1 TEST_MV_ACTION="$action" TEST_DIFF_STATUS=1 run_pipeline
  assert_status 143 "$PIPELINE_STATUS" "${name}_first_run"
  [[ $(cat "$CASE_DIR/state/pending-weekly/state") == "$expected_state" ]] ||
    fail "$name did not retain the expected recoverable state"
  assert_valid_state "$CASE_DIR/state/pending-weekly/state" "$name"

  TEST_REAL_GIT=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" "${name}_recovery"
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail "$name recovery did not clear active pending state"
}

case_activated_before() {
  exercise_atomic_transition activated-before pending activated_before
}

case_activated_after() {
  exercise_atomic_transition activated-after activated activated_after
}

case_deployed_before() {
  exercise_atomic_transition deployed-before activated deployed_before
}

case_deployed_after() {
  exercise_atomic_transition deployed-after deployed deployed_after
}

case_retirement_termination() {
  TEST_REAL_GIT=1 TEST_DIFF_STATUS=1 TEST_RM_ACTION=retire-term run_pipeline
  assert_status 143 "$PIPELINE_STATUS" retirement_termination_first_run
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail 'retirement_termination left the candidate active after retirement'
  [[ -d $CASE_DIR/state/retired-weekly ]] ||
    fail 'retirement_termination did not retain the retired candidate'

  TEST_REAL_GIT=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" retirement_termination_recovery
  [[ ! -e $CASE_DIR/state/retired-weekly ]] ||
    fail 'retirement_termination recovery did not clean retired state'
  assert_log_lacks 'nixos-rebuild ' retirement_termination_recovery
}

run_case() {
  local name="$1" expected_status="$2"
  setup_case "$name"
  "case_$name"
  assert_status "$expected_status" "$PIPELINE_STATUS" "$name"
}

run_case unchanged 0
run_case ai_inputs 0
run_case lock_contention 0
run_case dns_timeout 1
run_case eval_failure_hard 1
run_case eval_failure_default_hard 1
run_case eval_failure_defer 0
run_case invalid_eval_failure 2
run_case diff_error 1
run_case cascade_deferred 0
run_case cascade_error 1
run_case commit_failure 0
run_case success_order 0
run_case rebuild_failure 5
run_case pending_retry 0
run_case candidate_isolation 0
run_case termination 143

real_repo="$tmpdir/real-repo"
mkdir -p "$real_repo"
"$real_git" -C "$real_repo" init -q
"$real_git" -C "$real_repo" config user.name Fixture
"$real_git" -C "$real_repo" config user.email fixture@example.invalid
printf '{}\n' > "$real_repo/flake.nix"
printf 'committed lock\n' > "$real_repo/flake.lock"
"$real_git" -C "$real_repo" add flake.nix flake.lock
"$real_git" -C "$real_repo" commit -qm fixture

create_fresh_real_repo() {
  local name="$1"
  repo="$tmpdir/$name-repo"
  mkdir -p "$repo"
  "$real_git" -C "$repo" init -q
  "$real_git" -C "$repo" config user.name Fixture
  "$real_git" -C "$repo" config user.email fixture@example.invalid
  printf 'snapshot baseline\n' > "$repo/flake.nix"
  printf 'mock baseline\n' > "$repo/flake.lock"
  "$real_git" -C "$repo" add flake.nix flake.lock
  "$real_git" -C "$repo" commit -qm fixture
}

run_isolated_case() {
  local name="$1" expected_status="$2" saved_repo="$repo"
  create_fresh_real_repo "$name"
  setup_case "$name"
  "case_$name"
  assert_status "$expected_status" "$PIPELINE_STATUS" "$name"
  repo="$saved_repo"
}

run_isolated_case activated_before 0
run_isolated_case activated_after 0
run_isolated_case deployed_before 0
run_isolated_case deployed_after 0
run_isolated_case retirement_termination 0

case_stale_manual_commit() {
  local saved_repo="$repo"
  create_fresh_real_repo stale-manual
  setup_case stale-manual
  TEST_REAL_GIT=1 TEST_DIFF_STATUS=1 TEST_MUTATED_LOCK_CONTENT='weekly candidate' \
    TEST_REBUILD_STATUS=5 run_pipeline
  assert_status 5 "$PIPELINE_STATUS" stale_manual_first_run

  printf 'manual newer commit\n' > "$repo/flake.lock"
  "$real_git" -C "$repo" add flake.lock
  "$real_git" -C "$repo" commit -qm manual

  TEST_REAL_GIT=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" stale_manual_recovery
  assert_log_lacks 'nixos-rebuild ' stale_manual_recovery
  assert_log_lacks 'nix flake update' stale_manual_recovery
  cmp -s "$repo/flake.lock" <("$real_git" -C "$repo" show HEAD:flake.lock) ||
    fail 'stale_manual_recovery overwrote the newer committed flake.lock'
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail 'stale_manual_recovery left the stale candidate active'
  repo="$saved_repo"
}

case_stale_dirty_lock() {
  local saved_repo="$repo"
  create_fresh_real_repo stale-dirty
  setup_case stale-dirty
  TEST_REAL_GIT=1 TEST_DIFF_STATUS=1 TEST_MUTATED_LOCK_CONTENT='weekly candidate' \
    TEST_REBUILD_STATUS=5 run_pipeline
  assert_status 5 "$PIPELINE_STATUS" stale_dirty_first_run

  printf 'manual dirty lock\n' > "$repo/flake.lock"
  cp "$repo/flake.lock" "$CASE_DIR/manual.lock"

  TEST_REAL_GIT=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" stale_dirty_recovery
  assert_log_lacks 'nixos-rebuild ' stale_dirty_recovery
  cmp -s "$CASE_DIR/manual.lock" "$repo/flake.lock" ||
    fail 'stale_dirty_recovery overwrote the dirty flake.lock'
  "$real_git" -C "$repo" diff --quiet -- flake.lock &&
    fail 'stale_dirty_recovery unexpectedly cleaned the dirty flake.lock'
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail 'stale_dirty_recovery left the stale candidate active'
  repo="$saved_repo"
}

case_interleaved_labels() {
  local saved_repo="$repo"
  create_fresh_real_repo interleaved
  setup_case interleaved
  TEST_REAL_GIT=1 TEST_DIFF_STATUS=1 TEST_MUTATED_LOCK_CONTENT='weekly candidate' \
    TEST_REBUILD_STATUS=5 run_pipeline
  assert_status 5 "$PIPELINE_STATUS" interleaved_weekly_first_run

  TEST_REAL_GIT=1 TEST_DIFF_STATUS=1 TEST_MUTATED_LOCK_CONTENT='ai candidate' run_pipeline ai defer
  assert_status 0 "$PIPELINE_STATUS" interleaved_ai_run
  cmp -s "$repo/flake.lock" <("$real_git" -C "$repo" show HEAD:flake.lock) ||
    fail 'interleaved_ai_run did not publish its lock'

  TEST_REAL_GIT=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" interleaved_weekly_recovery
  assert_log_lacks 'nixos-rebuild ' interleaved_weekly_recovery
  assert_log_lacks 'nix flake update' interleaved_weekly_recovery
  [[ $(cat "$repo/flake.lock") == 'ai candidate' ]] ||
    fail 'interleaved_weekly_recovery overwrote the newer AI lock'
  [[ ! -e $CASE_DIR/state/pending-weekly ]] ||
    fail 'interleaved_weekly_recovery left the stale weekly candidate active'
  repo="$saved_repo"
}

case_real_dirty_noop() {
  local saved_repo="$repo"
  repo="$real_repo"
  setup_case real-dirty-noop
  printf 'dirty no-op lock\nsecond line without newline' > "$repo/flake.lock"
  cp -p "$repo/flake.lock" "$CASE_DIR/expected.lock"
  TEST_REAL_GIT=1 REAL_GIT="$real_git" run_pipeline
  assert_status 0 "$PIPELINE_STATUS" real_dirty_noop
  cmp -s "$CASE_DIR/expected.lock" "$repo/flake.lock" ||
    fail 'real_dirty_noop changed the dirty pre-run lock'
  if "$real_git" -C "$repo" diff --quiet -- flake.lock; then
    fail 'real_dirty_noop committed the dirty pre-run lock'
  fi
  assert_log_lacks 'nix-cascade-guard ' real_dirty_noop
  assert_log_lacks ' commit ' real_dirty_noop
  assert_log_lacks 'nixos-rebuild ' real_dirty_noop
  if compgen -G "$repo/.flake.lock.snapshot.*" >/dev/null; then
    fail 'real_dirty_noop left a lock snapshot behind'
  fi
  repo="$saved_repo"
}

case_real_restore() {
  local name="$1" expected_status="$2" eval_failure="${3:-}"
  local saved_repo="$repo"
  local expected_mode
  repo="$real_repo"
  setup_case "real-$name"
  printf 'dirty pre-run lock\nsecond line without newline' > "$repo/flake.lock"
  cp -p "$repo/flake.lock" "$CASE_DIR/expected.lock"
  expected_mode="$(stat -c %a "$repo/flake.lock")"
  case "$name" in
    update_failure) TEST_UPDATE_STATUS=1 ;;
    eval_failure_hard) TEST_EVAL_STATUS=1 ;;
    eval_failure_defer) TEST_EVAL_STATUS=1 ;;
    cascade_deferred) TEST_CASCADE_STATUS=10 ;;
    termination) TEST_CASCADE_ACTION=term ;;
  esac
  TEST_REAL_GIT=1 TEST_MUTATE_LOCK=1 REAL_GIT="$real_git" TEST_DIFF_STATUS=1 \
    run_pipeline weekly "$eval_failure"
  assert_status "$expected_status" "$PIPELINE_STATUS" "real_$name"
  cmp -s "$CASE_DIR/expected.lock" "$repo/flake.lock" ||
    fail "real_$name did not restore the dirty pre-run lock byte-for-byte"
  [[ $(stat -c %a "$repo/flake.lock") == "$expected_mode" ]] ||
    fail "real_$name did not preserve the pre-run lock mode"
  if compgen -G "$repo/.flake.lock.snapshot.*" >/dev/null; then
    fail "real_$name left a lock snapshot behind"
  fi
  repo="$saved_repo"
}

case_real_dirty_noop
case_real_restore update_failure 1
case_real_restore eval_failure_hard 1 hard
case_real_restore eval_failure_defer 0 defer
case_real_restore cascade_deferred 0
case_real_restore termination 143
case_stale_manual_commit
case_stale_dirty_lock
case_interleaved_labels

weekly_service=$(nix eval --raw --no-write-lock-file \
  '.#nixosConfigurations.laptop.config.systemd.services.nixos-auto-update.script')
ai_service=$(nix eval --raw --no-write-lock-file \
  '.#nixosConfigurations.laptop.config.systemd.services.nixos-ai-tools-auto-update.script')

[[ $weekly_service == *'--eval-failure hard'* ]] ||
  fail 'weekly service did not evaluate with --eval-failure hard'
[[ $weekly_service != *'--eval-failure defer'* ]] ||
  fail 'weekly service evaluated with defer policy'
[[ $ai_service == *'--eval-failure defer'* ]] ||
  fail 'AI service did not evaluate with --eval-failure defer'
[[ $ai_service != *'--eval-failure hard'* ]] ||
  fail 'AI service evaluated with hard policy'

printf 'flake update pipeline checks passed\n'
