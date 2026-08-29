#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'check-whitespace test failed: %s\n' "$1" >&2
  exit 1
}

repo_root=$(mktemp -d)
trap 'rm -rf "$repo_root"' EXIT

git -C "$repo_root" init -q
git -C "$repo_root" config user.email check@example.invalid
git -C "$repo_root" config user.name check
printf 'baseline\n' >"$repo_root/tracked"
git -C "$repo_root" add tracked
git -C "$repo_root" commit -qm baseline

printf 'staged whitespace \n' >"$repo_root/tracked"
git -C "$repo_root" add tracked
if CHECK_WHITESPACE_ROOT="$repo_root" bash checks/run-whitespace-check.bash HEAD >/dev/null 2>&1; then
  fail 'staged whitespace was accepted'
fi

git -C "$repo_root" restore --staged --worktree tracked
printf 'untracked whitespace \n' >"$repo_root/untracked"
if CHECK_WHITESPACE_ROOT="$repo_root" bash checks/run-whitespace-check.bash HEAD >/dev/null 2>&1; then
  fail 'untracked whitespace was accepted'
fi

printf 'clean\n' >"$repo_root/untracked"
CHECK_WHITESPACE_ROOT="$repo_root" bash checks/run-whitespace-check.bash HEAD

rm "$repo_root/untracked"
base=$(git -C "$repo_root" rev-parse HEAD)
printf 'committed whitespace \n' >"$repo_root/tracked"
git -C "$repo_root" add tracked
git -C "$repo_root" commit -qm whitespace
if CHECK_WHITESPACE_ROOT="$repo_root" \
  bash checks/run-whitespace-check.bash "$base" >/dev/null 2>&1; then
  fail 'committed whitespace since the base was accepted'
fi

if CHECK_WHITESPACE_ROOT="$repo_root" \
  bash checks/run-whitespace-check.bash refs/heads/check-whitespace-missing >/dev/null 2>&1; then
  fail 'invalid whitespace base was accepted'
fi

echo 'check-whitespace: all tests passed'
