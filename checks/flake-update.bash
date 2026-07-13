#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

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
  local expected="$1" name="$2" count
  count=$(grep -F 'nix flake update' "$COMMAND_LOG" | grep -Fv 'runuser ' | wc -l)
  [[ $count -eq 1 ]] || fail "$name expected one update invocation, got $count"
  assert_log_has "$expected" "$name"
}

assert_before() {
  local first="$1" second="$2" name="$3" first_line second_line
  first_line=$(grep -Fnx -- "$first" "$COMMAND_LOG" | cut -d: -f1)
  second_line=$(grep -Fnx -- "$second" "$COMMAND_LOG" | cut -d: -f1)
  [[ -n $first_line && -n $second_line && $first_line -lt $second_line ]] ||
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
    home/scripts/nixos-flake-update "${args[@]}" >"$output_log" 2>&1
  PIPELINE_STATUS=$?
  set -e
}

setup_case() {
  CASE_DIR="$tmpdir/$1"
  COMMAND_LOG="$CASE_DIR/commands.log"
  mkdir -p "$CASE_DIR"
  : > "$COMMAND_LOG"
  unset TEST_DIFF_STATUS TEST_EVAL_STATUS TEST_COMMIT_STATUS TEST_CASCADE_STATUS
  unset TEST_CASCADE_ACTION TEST_FLOCK_STATUS TEST_DNS_STATUS TEST_REBUILD_STATUS
}

update_weekly="nix flake update --flake path:$repo"
update_ai="nix flake update --flake path:$repo claude-code-nix codex-cli-nix code-cursor-nix"
restore="git -C $repo checkout -- flake.lock"
commit_weekly="git -C $repo commit -m flake.lock:\ weekly\ auto-update -- flake.lock"
rebuild="nixos-rebuild switch --flake path:$repo#laptop --option max-jobs 2 --option cores 8"

case_unchanged() {
  setup_case unchanged
  run_pipeline
  assert_status 0 "$PIPELINE_STATUS" unchanged
  assert_one_update "$update_weekly" unchanged
  assert_log_lacks 'nix-cascade-guard ' unchanged
  assert_log_lacks ' commit ' unchanged
  assert_log_lacks 'nixos-rebuild ' unchanged
}

case_ai_inputs() {
  setup_case ai_inputs
  run_pipeline ai
  assert_status 0 "$PIPELINE_STATUS" ai_inputs
  assert_one_update "$update_ai" ai_inputs
}

case_lock_contention() {
  setup_case lock_contention
  TEST_FLOCK_STATUS=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" lock_contention
  assert_log_lacks 'nix flake update' lock_contention
}

case_dns_timeout() {
  setup_case dns_timeout
  TEST_DNS_STATUS=1 run_pipeline
  assert_status 1 "$PIPELINE_STATUS" dns_timeout
  assert_log_lacks 'nix flake update' dns_timeout
}

case_eval_failure() {
  setup_case eval_failure
  TEST_EVAL_STATUS=1 run_pipeline
  assert_status 1 "$PIPELINE_STATUS" eval_failure
  assert_log_has "$restore" eval_failure
  assert_log_lacks 'nix-cascade-guard ' eval_failure
}

case_diff_error() {
  setup_case diff_error
  TEST_DIFF_STATUS=2 run_pipeline
  assert_status 1 "$PIPELINE_STATUS" diff_error
  assert_log_has "$restore" diff_error
  assert_log_lacks 'nix-cascade-guard ' diff_error
  assert_log_lacks ' commit ' diff_error
  assert_log_lacks 'nixos-rebuild ' diff_error
}

case_cascade_deferred() {
  setup_case cascade_deferred
  TEST_DIFF_STATUS=1 TEST_CASCADE_STATUS=10 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" cascade_deferred
  assert_log_has "$restore" cascade_deferred
  assert_log_lacks ' commit ' cascade_deferred
  assert_log_lacks 'nixos-rebuild ' cascade_deferred
}

case_cascade_error() {
  setup_case cascade_error
  TEST_DIFF_STATUS=1 TEST_CASCADE_STATUS=7 run_pipeline
  assert_status 1 "$PIPELINE_STATUS" cascade_error
  assert_log_has "$restore" cascade_error
  assert_log_lacks ' commit ' cascade_error
  assert_log_lacks 'nixos-rebuild ' cascade_error
}

case_commit_failure() {
  setup_case commit_failure
  TEST_DIFF_STATUS=1 TEST_COMMIT_STATUS=1 run_pipeline
  assert_status 1 "$PIPELINE_STATUS" commit_failure
  assert_log_has "$restore" commit_failure
  assert_log_lacks 'nixos-rebuild ' commit_failure
}

case_success_order() {
  setup_case success_order
  TEST_DIFF_STATUS=1 run_pipeline
  assert_status 0 "$PIPELINE_STATUS" success_order
  assert_log_has "$commit_weekly" success_order
  assert_log_has "$rebuild" success_order
  assert_before "$commit_weekly" "$rebuild" success_order
}

case_rebuild_failure() {
  setup_case rebuild_failure
  TEST_DIFF_STATUS=1 TEST_REBUILD_STATUS=5 run_pipeline
  assert_status 5 "$PIPELINE_STATUS" rebuild_failure
  assert_log_has "$commit_weekly" rebuild_failure
  assert_log_has "$rebuild" rebuild_failure
  assert_log_lacks "$restore" rebuild_failure
  assert_before "$commit_weekly" "$rebuild" rebuild_failure
}

case_termination() {
  setup_case termination
  TEST_DIFF_STATUS=1 TEST_CASCADE_ACTION=term run_pipeline
  assert_status 143 "$PIPELINE_STATUS" termination
  assert_log_has "$restore" termination
  assert_log_lacks ' commit ' termination
  assert_log_lacks 'nixos-rebuild ' termination
}

cases=(
  unchanged ai_inputs lock_contention dns_timeout eval_failure diff_error
  cascade_deferred cascade_error commit_failure success_order rebuild_failure termination
)
for case_name in "${cases[@]}"; do
  "case_$case_name"
done

printf 'flake update pipeline checks passed\n'
