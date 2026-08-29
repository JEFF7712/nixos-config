#!/usr/bin/env bash
set -euo pipefail

repo_root=${CHECK_WHITESPACE_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}
base=${1:-HEAD}

cd "$repo_root"

if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
  printf 'check-whitespace: invalid Git base: %s\n' "$base" >&2
  exit 1
fi

git diff --no-ext-diff --check "$base"

errors=0
while IFS= read -r -d '' path; do
  status=0
  output=$(git diff --no-ext-diff --no-index --check -- /dev/null "$path" 2>&1) \
    || status=$?
  if [ -n "$output" ] || [ "$status" -gt 1 ]; then
    printf '%s\n' "$output" >&2
    errors=1
  fi
done < <(git ls-files --others --exclude-standard -z)

exit "$errors"
