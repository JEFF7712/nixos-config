#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
bin_dir="$tmpdir/bin"
command_log="$tmpdir/commands.log"
mkdir -p "$repo" "$bin_dir"
: > "$command_log"
: > "$repo/flake.nix"
: > "$repo/flake.lock"

make_fake() {
  local name="$1"
  shift
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
fi
EOF

make_fake flock <<'EOF'
#!/usr/bin/env bash
printf 'flock %q' "$1" >> "$COMMAND_LOG"
printf ' %q' "${@:2}" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
while [[ $# -gt 0 && "$1" == -* ]]; do shift; done
shift
exec "$@"
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
EOF

run_pipeline() {
  PATH="$bin_dir:$PATH" \
    COMMAND_LOG="$command_log" \
    TEST_REPO="$repo" \
    UPDATE_LOCK="$tmpdir/update.lock" \
    DNS_RETRIES=1 \
    DNS_RETRY_DELAY=0 \
    CASCADE_GUARD="$bin_dir/nix-cascade-guard" \
    NIXOS_REBUILD="$bin_dir/nixos-rebuild" \
    home/scripts/nixos-flake-update \
      --label weekly \
      --repo "$repo" \
      --target "path:$repo#laptop" \
      --commit-message "flake.lock: weekly auto-update"
}

set +e
run_pipeline
status=$?
set -e

if [[ $status -ne 0 ]]; then
  printf 'expected unchanged update pipeline to exit 0, got %d\n' "$status" >&2
  cat "$command_log" >&2
  exit 1
fi

expected_update="nix flake update --flake path:$repo"
update_count=$(grep -Ec '^nix .*flake update( |$)' "$command_log" || true)
exact_update_count=$(grep -Fxc "$expected_update" "$command_log" || true)
if [[ $update_count -ne 1 || $exact_update_count -ne 1 ]]; then
  printf 'expected exactly one %q, got %d update invocations and %d exact matches\n' \
    "$expected_update" "$update_count" "$exact_update_count" >&2
  cat "$command_log" >&2
  exit 1
fi

if grep -Eq '^(nix-cascade-guard|nixos-rebuild)( |$)|^git .*commit( |$)' "$command_log"; then
  printf 'unchanged lock file unexpectedly triggered cascade guard, commit, or rebuild\n' >&2
  cat "$command_log" >&2
  exit 1
fi

assert_restored_failure() {
  local name="$1"
  local status="$2"
  if [[ $status -eq 0 ]] || ! grep -Fq 'checkout -- flake.lock' "$command_log"; then
    printf '%s expected nonzero status and lock restoration, got %d\n' "$name" "$status" >&2
    cat "$command_log" >&2
    exit 1
  fi
}

: > "$command_log"
set +e
TEST_DIFF_STATUS=2 run_pipeline
status=$?
set -e
assert_restored_failure 'diff error' "$status"
if grep -Eq '^(nix-cascade-guard|nixos-rebuild)( |$)|^git .*commit( |$)' "$command_log"; then
  printf 'diff error unexpectedly continued the pipeline\n' >&2
  cat "$command_log" >&2
  exit 1
fi

: > "$command_log"
set +e
TEST_DIFF_STATUS=1 TEST_COMMIT_STATUS=1 run_pipeline
status=$?
set -e
assert_restored_failure 'commit failure' "$status"
if grep -Eq '^nixos-rebuild( |$)' "$command_log"; then
  printf 'commit failure unexpectedly rebuilt\n' >&2
  cat "$command_log" >&2
  exit 1
fi

: > "$command_log"
set +e
TEST_DIFF_STATUS=1 TEST_CASCADE_ACTION=term run_pipeline
status=$?
set -e
assert_restored_failure 'terminated pre-commit pipeline' "$status"
if grep -Eq '^git .*commit( |$)|^nixos-rebuild( |$)' "$command_log"; then
  printf 'terminated pipeline unexpectedly committed or rebuilt\n' >&2
  cat "$command_log" >&2
  exit 1
fi

printf 'flake update pipeline checks passed\n'
