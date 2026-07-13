#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
real_git="$(command -v git)"

repo="$tmpdir/repo"
bin_dir="$tmpdir/bin"
mkdir -p "$repo" "$bin_dir"
: > "$repo/flake.nix"
: > "$repo/flake.lock"

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
  if [[ "${TEST_DIFF_STATUS:-0}" == 2 ]]; then
    rm -f "$TEST_REPO/flake.lock"
  elif [[ "${TEST_MUTATE_LOCK:-}" == 1 || "${TEST_DIFF_STATUS:-0}" == 1 ]]; then
    printf 'mutated by update\n' > "$TEST_REPO/flake.lock"
  fi
fi
if [[ " $* " == *' eval '* ]]; then
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
exit "${TEST_REBUILD_STATUS:-0}"
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

assert_one_update() {
  local expected="$1" name="$2" count=0 line
  while IFS= read -r line; do
    if [[ $line == *'nix flake update'* && $line != *'runuser '* ]]; then
      ((count += 1))
    fi
  done < "$COMMAND_LOG"
  [[ $count -eq 1 ]] || fail "$name expected one update invocation, got $count"
  assert_log_has "$expected" "$name"
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
  local command_log="$CASE_DIR/commands.log"
  local output_log="$CASE_DIR/output.log"
  local -a args=(
    --label "$variant"
    --repo "$repo"
    --target "path:$repo#laptop"
    --commit-message "flake.lock: $variant auto-update"
  )
  if [[ $variant == ai ]]; then
    args+=(--input claude-code-nix --input codex-cli-nix --input code-cursor-nix)
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
    REAL_GIT="${REAL_GIT:-}" \
    TEST_REAL_GIT="${TEST_REAL_GIT:-0}" \
    TEST_MUTATE_LOCK="${TEST_MUTATE_LOCK:-0}" \
    TEST_UPDATE_STATUS="${TEST_UPDATE_STATUS:-0}" \
    TEST_DIFF_STATUS="${TEST_DIFF_STATUS:-0}" \
    TEST_EVAL_STATUS="${TEST_EVAL_STATUS:-0}" \
    TEST_COMMIT_STATUS="${TEST_COMMIT_STATUS:-0}" \
    TEST_CASCADE_STATUS="${TEST_CASCADE_STATUS:-0}" \
    TEST_CASCADE_ACTION="${TEST_CASCADE_ACTION:-}" \
    TEST_FLOCK_STATUS="${TEST_FLOCK_STATUS:-0}" \
    TEST_DNS_STATUS="${TEST_DNS_STATUS:-0}" \
    TEST_REBUILD_STATUS="${TEST_REBUILD_STATUS:-0}" \
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
    printf 'mock baseline\n' > "$repo/flake.lock"
  fi
  unset TEST_UPDATE_STATUS TEST_DIFF_STATUS TEST_EVAL_STATUS TEST_COMMIT_STATUS TEST_CASCADE_STATUS
  unset TEST_CASCADE_ACTION TEST_FLOCK_STATUS TEST_DNS_STATUS TEST_REBUILD_STATUS
  unset TEST_REAL_GIT TEST_MUTATE_LOCK REAL_GIT
}

update_weekly="nix flake update --flake path:$repo"
update_ai="nix flake update --flake path:$repo claude-code-nix codex-cli-nix code-cursor-nix"
commit_weekly="git -C $repo commit -m flake.lock:\ weekly\ auto-update -- flake.lock"
rebuild="nixos-rebuild switch --flake path:$repo#laptop --option max-jobs 2 --option cores 8"

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

case_eval_failure() {
  TEST_EVAL_STATUS=1 run_pipeline
  assert_log_lacks 'nix-cascade-guard ' eval_failure
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
  assert_log_lacks 'nixos-rebuild ' commit_failure
}

case_success_order() {
  TEST_DIFF_STATUS=1 run_pipeline
  assert_log_has "$commit_weekly" success_order
  assert_log_has "$rebuild" success_order
  assert_before "$commit_weekly" "$rebuild" success_order
}

case_rebuild_failure() {
  TEST_DIFF_STATUS=1 TEST_REBUILD_STATUS=5 run_pipeline
  assert_log_has "$commit_weekly" rebuild_failure
  assert_log_has "$rebuild" rebuild_failure
  assert_before "$commit_weekly" "$rebuild" rebuild_failure
}

case_termination() {
  TEST_DIFF_STATUS=1 TEST_CASCADE_ACTION=term run_pipeline
  assert_log_lacks ' commit ' termination
  assert_log_lacks 'nixos-rebuild ' termination
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
run_case eval_failure 1
run_case diff_error 1
run_case cascade_deferred 0
run_case cascade_error 1
run_case commit_failure 1
run_case success_order 0
run_case rebuild_failure 5
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
  local name="$1" expected_status="$2"
  local saved_repo="$repo"
  local expected_mode
  repo="$real_repo"
  setup_case "real-$name"
  printf 'dirty pre-run lock\nsecond line without newline' > "$repo/flake.lock"
  cp -p "$repo/flake.lock" "$CASE_DIR/expected.lock"
  expected_mode="$(stat -c %a "$repo/flake.lock")"
  case "$name" in
    update_failure) TEST_UPDATE_STATUS=1 ;;
    cascade_deferred) TEST_CASCADE_STATUS=10 ;;
    termination) TEST_CASCADE_ACTION=term ;;
  esac
  TEST_REAL_GIT=1 TEST_MUTATE_LOCK=1 REAL_GIT="$real_git" TEST_DIFF_STATUS=1 run_pipeline
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
case_real_restore cascade_deferred 0
case_real_restore termination 143

printf 'flake update pipeline checks passed\n'
