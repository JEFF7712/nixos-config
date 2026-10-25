#!/usr/bin/env bash
# Laptop eval (~50s, never eval-cached) only when a changed file can affect
# evaluation, per the run-changed-checks classification; whitespace always.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "${QUICK_FORCE_EVAL:-0}" = 1 ] ||
  bash checks/run-changed-checks.bash --list-changed | rg -qx 'check|eval.*|build.*'; then
  just eval laptop
else
  echo 'quick: no eval-relevant changes; skipped laptop eval (QUICK_FORCE_EVAL=1 to force)'
fi

just diff-check
