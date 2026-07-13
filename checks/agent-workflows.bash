#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

require_executable() {
  local path=$1

  if [ ! -x "$path" ]; then
    echo "missing executable: $path" >&2
    exit 1
  fi
}

require_match() {
  local pattern=$1
  local path=$2

  if ! rg -q "$pattern" "$path"; then
    echo "missing pattern in $path: $pattern" >&2
    exit 1
  fi
}

require_executable checks/agent-invariants.bash
require_executable home/scripts/new-nixos-module
require_executable home/scripts/new-home-module
require_executable home/scripts/agent-self-improve

git_metadata_fixture=checks/.git/agent-invariants-hardcoded-path-test
mkdir -p "${git_metadata_fixture%/*}"
printf '/home/rupan/%s\n' nixos >"$git_metadata_fixture"
if ! invariants_output=$(bash checks/agent-invariants.bash 2>&1); then
  rm -f "$git_metadata_fixture"
  rmdir "${git_metadata_fixture%/*}" 2>/dev/null || true
  if grep -Eq '(^|/|:)\.git(:|/)' <<<"$invariants_output"; then
    echo "agent invariants scanned Git metadata:" >&2
  fi
  printf '%s\n' "$invariants_output" >&2
  exit 1
fi
rm -f "$git_metadata_fixture"
rmdir "${git_metadata_fixture%/*}" 2>/dev/null || true

invariant_fixture=checks/.agent-invariants-hardcoded-path-test
printf '/home/rupan/%s\n' nixos >"$invariant_fixture"
if fixture_output=$(bash checks/agent-invariants.bash 2>&1); then
  rm -f "$invariant_fixture"
  echo "agent invariants missed a hardcoded repo path in a project file" >&2
  exit 1
fi
rm -f "$invariant_fixture"
if ! grep -Fq "$invariant_fixture" <<<"$fixture_output"; then
  echo "agent invariants failed for an unexpected reason:" >&2
  printf '%s\n' "$fixture_output" >&2
  exit 1
fi

assert_auto_update_wiring_rejected() {
  local service=$1
  local replacement=$2
  local fixture expected output
  fixture=$(mktemp)
  expected="$service must use mkUpdateService"
  cp modules/nixos/auto-update.nix "$fixture"
  perl -0pi -e \
    "s/systemd\\.services\\.$service = mkUpdateService \\{/$replacement/" \
    "$fixture"

  if output=$(AUTO_UPDATE_MODULE="$fixture" bash checks/agent-invariants.bash 2>&1); then
    rm -f "$fixture"
    echo "agent invariants accepted missing or substituted $service wiring" >&2
    exit 1
  fi
  rm -f "$fixture"
  if ! grep -Fq "$expected" <<<"$output"; then
    echo "agent invariants rejected $service wiring for an unexpected reason:" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

assert_auto_update_wiring_rejected nixos-auto-update '# deleted weekly service wiring'
assert_auto_update_wiring_rejected nixos-ai-tools-auto-update \
  'systemd.services.nixos-ai-tools-auto-update = {'

self_improve_output=$(home/scripts/agent-self-improve --check)
for expected in \
  'Self-improvement check' \
  'Session trigger' \
  'Hurdle trigger' \
  'Update target'; do
  if ! grep -Fq "$expected" <<<"$self_improve_output"; then
    echo "agent-self-improve --check missing: $expected" >&2
    exit 1
  fi
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/modules/nixos" "$tmpdir/modules/home-manager"

NIXOS_REPO_ROOT="$tmpdir" home/scripts/new-nixos-module test-service >/dev/null
NIXOS_REPO_ROOT="$tmpdir" home/scripts/new-home-module test-tool >/dev/null

nixos_module="$tmpdir/modules/nixos/test-service.nix"
home_module="$tmpdir/modules/home-manager/test-tool.nix"

require_match 'options\.test-service\.enable = lib\.mkEnableOption "test-service";' "$nixos_module"
require_match 'config = lib\.mkIf config\.test-service\.enable' "$nixos_module"
require_match 'environment\.systemPackages' "$nixos_module"

require_match 'options\.test-tool\.enable = lib\.mkEnableOption "test-tool";' "$home_module"
require_match 'config = lib\.mkIf config\.test-tool\.enable' "$home_module"
require_match 'home\.packages' "$home_module"

if NIXOS_REPO_ROOT="$tmpdir" home/scripts/new-nixos-module test-service >/dev/null 2>&1; then
  echo "new-nixos-module overwrote an existing module" >&2
  exit 1
fi

if NIXOS_REPO_ROOT="$tmpdir" home/scripts/new-home-module test-tool >/dev/null 2>&1; then
  echo "new-home-module overwrote an existing module" >&2
  exit 1
fi
