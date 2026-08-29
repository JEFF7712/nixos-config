#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  printf 'check-changed test failed: %s\n' "$1" >&2
  exit 1
}

assert_selection() {
  local expected=$1
  shift
  local actual

  actual=$(bash checks/run-changed-checks.bash --list "$@")
  [ "$actual" = "$expected" ] \
    || fail "unexpected checks for $*: expected [$expected], got [$actual]"
}

assert_selection 'diff-check'

assert_selection 'qml-lint
quickshell-test
eval laptop
diff-check' \
  home/configs/quickshell/Topbar.qml

assert_selection 'shell-check
wallpaper-script-check
check-profiles
diff-check' \
  home/scripts/profile-transition

assert_selection 'fmt-check
eval laptop-crypt
diff-check' \
  hosts/laptop-crypt/configuration.nix

assert_selection 'fmt-check
eval-vm
eval laptop
diff-check' \
  hosts/laptop/base.nix

assert_selection 'fmt-check
build-iso
eval iso
diff-check' \
  hosts/iso/configuration.nix

assert_selection 'fmt-check
eval-all
diff-check' \
  lib/unclassified.nix

assert_selection 'check-agent-docs
diff-check' \
  AGENT_MAP.md

assert_selection 'diff-check' docs/luks-reinstall.md

assert_selection 'xhisper-check
eval laptop
diff-check' \
  pkgs/xhisper-local/default.nix

assert_selection 'check' flake.lock
assert_selection 'check' justfile
assert_selection 'check' checks/profile-transition.bash
assert_selection 'check' .github/workflows/check.yml
assert_selection 'check' home/configs/unknown/new-format.conf

if CHECK_CHANGED_BASE=refs/heads/check-changed-missing \
  bash checks/run-changed-checks.bash --list-changed >/dev/null 2>&1; then
  fail 'invalid Git base was accepted'
fi

assert_selection 'fmt-check
qml-lint
quickshell-test
eval laptop
diff-check' \
  home/configs/quickshell/Topbar.qml \
  modules/home-manager/quickshell.nix \
  home/configs/quickshell/Topbar.qml

echo 'check-changed: all tests passed'
