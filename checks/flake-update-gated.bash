#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

bin_dir="$tmpdir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/flock" <<'EOF'
#!/usr/bin/env bash
printf 'flock' >> "$COMMAND_LOG"
printf ' %q' "$@" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
exit "${TEST_FLOCK_STATUS:-0}"
EOF

cat >"$bin_dir/nix" <<'EOF'
#!/usr/bin/env bash
printf 'nix' >> "$COMMAND_LOG"
printf ' %q' "$@" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
if [[ " $* " == *' flake update '* ]]; then
  if [[ "${TEST_KEEP_LOCK:-0}" != 1 ]]; then
    for arg in "$@"; do
      if [[ -n "${saw_flake:-}" ]]; then
        printf 'mutated\n' >> "$arg/flake.lock"
        unset saw_flake
      fi
      [[ "$arg" == --flake ]] && saw_flake=1
    done
  fi
  exit "${TEST_UPDATE_STATUS:-0}"
fi
if [[ " $* " == *' eval '* ]]; then
  if [[ " $* " == *'/shells#'* ]]; then
    exit "${TEST_EVAL_SHELLS_STATUS:-0}"
  fi
  exit "${TEST_EVAL_STATUS:-0}"
fi
printf 'fake nix saw unexpected args: %s\n' "$*" >&2
exit 2
EOF
chmod +x "$bin_dir/flock" "$bin_dir/nix"

setup_repo() {
  CASE_DIR="$tmpdir/$1"
  COMMAND_LOG="$CASE_DIR/commands.log"
  mkdir -p "$CASE_DIR" "$CASE_DIR/shells"
  printf 'main baseline\n' > "$CASE_DIR/flake.lock"
  printf 'shells baseline\n' > "$CASE_DIR/shells/flake.lock"
  cp -p "$CASE_DIR/flake.lock" "$CASE_DIR/expected-main.lock"
  cp -p "$CASE_DIR/shells/flake.lock" "$CASE_DIR/expected-shells.lock"
  : >"$COMMAND_LOG"
  unset TEST_UPDATE_STATUS TEST_EVAL_STATUS TEST_EVAL_SHELLS_STATUS
  unset TEST_KEEP_LOCK TEST_FLOCK_STATUS
}

run_gated() {
  set +e
  PATH="$bin_dir:$PATH" \
    COMMAND_LOG="$COMMAND_LOG" \
    UPDATE_LOCK="$tmpdir/update.lock" \
    TEST_UPDATE_STATUS="${TEST_UPDATE_STATUS:-0}" \
    TEST_EVAL_STATUS="${TEST_EVAL_STATUS:-0}" \
    TEST_EVAL_SHELLS_STATUS="${TEST_EVAL_SHELLS_STATUS:-0}" \
    TEST_KEEP_LOCK="${TEST_KEEP_LOCK:-0}" \
    TEST_FLOCK_STATUS="${TEST_FLOCK_STATUS:-0}" \
    home/scripts/flake-update-gated --repo "$CASE_DIR" "$@" >"$CASE_DIR/output.log" 2>&1
  GATED_STATUS=$?
  set -e
}

assert_restored() {
  local name="$1"
  cmp -s "$CASE_DIR/expected-main.lock" "$CASE_DIR/flake.lock" ||
    fail "$name did not restore the main flake.lock exactly"
  cmp -s "$CASE_DIR/expected-shells.lock" "$CASE_DIR/shells/flake.lock" ||
    fail "$name did not restore the shells flake.lock exactly"
}

# Full update, eval passes: both locks keep the update.
setup_repo success
run_gated
[[ $GATED_STATUS -eq 0 ]] || fail "success exited $GATED_STATUS"
grep -q '^mutated$' "$CASE_DIR/flake.lock" || fail "success did not keep the main update"
grep -q '^mutated$' "$CASE_DIR/shells/flake.lock" || fail "success did not keep the shells update"
grep -Fq 'nix eval' "$COMMAND_LOG" || fail "success skipped the eval gate"

# Full update, laptop eval fails: both locks revert.
setup_repo eval-failure
TEST_EVAL_STATUS=1 run_gated
[[ $GATED_STATUS -ne 0 ]] || fail "eval-failure exited 0"
assert_restored eval-failure
grep -Fq 'laptop eval failed; flake.lock reverted' "$CASE_DIR/output.log" ||
  fail "eval-failure missing the revert message"

# Full update, shells eval fails: both locks revert.
setup_repo shells-eval-failure
TEST_EVAL_SHELLS_STATUS=1 run_gated
[[ $GATED_STATUS -ne 0 ]] || fail "shells-eval-failure exited 0"
assert_restored shells-eval-failure

# Update with no changes: eval is skipped, locks untouched.
setup_repo unchanged
TEST_KEEP_LOCK=1 run_gated
[[ $GATED_STATUS -eq 0 ]] || fail "unchanged exited $GATED_STATUS"
assert_restored unchanged
grep -Fq 'nix eval' "$COMMAND_LOG" && fail "unchanged ran eval for identical locks"
grep -Fq 'unchanged; skipping eval' "$CASE_DIR/output.log" ||
  fail "unchanged missing the skip message"

# Partial update (named inputs): shells flake is not touched.
setup_repo partial
run_gated opencode-nix
[[ $GATED_STATUS -eq 0 ]] || fail "partial exited $GATED_STATUS"
grep -q '^mutated$' "$CASE_DIR/flake.lock" || fail "partial did not keep the main update"
cmp -s "$CASE_DIR/expected-shells.lock" "$CASE_DIR/shells/flake.lock" ||
  fail "partial touched the shells flake.lock"
grep -Fq 'shells' "$COMMAND_LOG" && fail "partial touched the shells flake"

# Partial update, eval fails: main lock still reverts.
setup_repo partial-eval-failure
TEST_EVAL_STATUS=1 run_gated opencode-nix
[[ $GATED_STATUS -ne 0 ]] || fail "partial-eval-failure exited 0"
cmp -s "$CASE_DIR/expected-main.lock" "$CASE_DIR/flake.lock" ||
  fail "partial-eval-failure did not restore the main flake.lock"

# Lock contention: no update is attempted.
setup_repo lock-contention
TEST_FLOCK_STATUS=1 run_gated
[[ $GATED_STATUS -ne 0 ]] || fail "lock-contention exited 0"
assert_restored lock-contention
grep -Fq 'nix flake update' "$COMMAND_LOG" && fail "lock-contention updated despite the lock"

echo 'flake-update-gated: ok'
