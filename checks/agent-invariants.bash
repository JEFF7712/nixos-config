#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

is_allowed_hardcoded_repo_path() {
  case "$1" in
    .mcp.json | hosts/iso/configuration.nix)
      return 0
      ;;
    # programs.nix-agent.flake is lib.types.path, so it cannot use the
    # string-typed config.repoPath option and must stay a path literal.
    hosts/laptop/base.nix)
      return 0
      ;;
    # This file is the NixOS-level source of truth: the option default is
    # the path literal that other modules should reference via config.repoPath.
    modules/nixos/repo-path.nix)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_hardcoded_repo_paths() {
  local entry file

  while IFS= read -r entry; do
    file=${entry%%:*}
    file=${file#./}
    if ! is_allowed_hardcoded_repo_path "$file"; then
      fail "hardcoded /home/rupan/nixos outside allowlist: $entry"
    fi
  done < <(
    rg -n --hidden '/home/rupan/nixos' \
      --glob '!.git' \
      --glob '!vendor/**' \
      --glob '!CLAUDE.md' \
      --glob '!AGENTS.md' \
      --glob '!AGENT_MAP.md' \
      --glob '!docs/deployment.md' \
      --glob '!checks/agent-invariants.bash' \
      . || true
  )
}

check_auto_discovered_imports() {
  local entry

  while IFS= read -r entry; do
    fail "manual import of auto-discovered module tree: $entry"
  done < <(
    rg -n 'import-tree ../../modules/(nixos|home-manager)|\.\./\.\./modules/(nixos|home-manager)|\./modules/(nixos|home-manager)' \
      --glob '!hosts/*/configuration.nix' \
      --glob '!hosts/laptop/base.nix' \
      --glob '!home/rupan/*.nix' \
      --glob '!CLAUDE.md' \
      --glob '!AGENTS.md' \
      --glob '!AGENT_MAP.md' \
      --glob '!README.md' \
      . || true
  )
}

check_module_options() {
  local file

  while IFS= read -r file; do
    if ! rg -q 'options\.' "$file" || ! rg -q 'lib\.mk(EnableOption|Option)' "$file"; then
      fail "module has no top-level option declaration: $file"
    fi
  done < <(
    fd -t f '\.nix$' modules/nixos modules/home-manager \
      --exclude profiles
  )
}

check_wallpaper_dirs() {
  local assets_root="${HOME}/nixos-assets"
  local entry path

  if [ ! -d "$assets_root" ]; then
    echo "agent-invariants: assets repo not present, skipping wallpaper dir check" >&2
    return 0
  fi

  while IFS= read -r entry; do
    path=${entry#*:}
    if [ ! -d "$assets_root/$path" ]; then
      fail "profile references missing wallpaper directory: $entry"
    fi
  done < <(
    rg --pcre2 -No --replace '$1' \
      'wallpaperDir(?:Light)? = "\$\{config\.assetsPath\}/([^"]+)"' \
      modules/home-manager/profiles || true
  )
}

check_script_refs() {
  local entry script

  while IFS= read -r entry; do
    script=${entry##*/}
    if [ ! -e "home/scripts/$script" ]; then
      fail "missing script referenced by config: $entry"
    fi
  done < <(
    rg --pcre2 -No \
      'home/scripts/[A-Za-z0-9_-]+|\.local/bin/[A-Za-z0-9_-]+' \
      modules home lib hosts \
      --glob '*.nix' || true
  )
}

check_disabled_nix_services() {
  local entry

  while IFS= read -r entry; do
    fail "use comin/nh clean modules instead of this option: $entry"
  done < <(
    rg -n '^\s*(nix\.gc|system\.autoUpgrade)\b' \
      modules hosts home flake.nix || true
  )
}

check_profile_artifact_contract() {
  local entry
  while IFS= read -r entry; do
    fail "legacy desktop profile artifact reference: $entry"
  done < <(
    rg -n 'meta\.json|runtime\.json|wallpaper-dir-light|wallpaper-dir' \
      home/scripts modules/home-manager lib/desktop-profiles \
      --glob '!profile-manifest' \
      --glob '!desktop-profiles.nix' || true
  )
}

check_laptop_build_caps() {
  local settings
  settings=$(
    rg -U --multiline -n 'nix\s*=\s*\{[\s\S]*?settings\s*=\s*\{[\s\S]*?\};' \
      hosts/laptop/base.nix || true
  )

  if ! printf '%s\n' "$settings" | rg -q 'max-jobs\s*=\s*[1-9][0-9]*\s*;'; then
    fail "hosts/laptop/base.nix must cap nix.settings.max-jobs to a positive integer (not auto)"
  fi
  if printf '%s\n' "$settings" | rg -q 'cores\s*=\s*0\s*;'; then
    fail "hosts/laptop/base.nix must not set nix.settings.cores = 0 (uses all CPUs per job)"
  fi
}

check_sops_encrypted() {
  local secret_file
  while IFS= read -r secret_file; do
    if ! rg -q '^sops:\s*$' "$secret_file"; then
      fail "secrets file missing sops metadata block (unencrypted?): $secret_file"
    fi
    if rg -n --pcre2 '^[A-Za-z0-9_-]+:\s+(?!ENC\[)' "$secret_file" | rg -qv '^\d+:sops:'; then
      fail "secrets file has unencrypted top-level scalar value: $secret_file"
    fi
  done < <(fd -t f '\.ya?ml$' secrets || true)
}

check_hardcoded_repo_paths
check_auto_discovered_imports
check_module_options
check_wallpaper_dirs
check_script_refs
check_disabled_nix_services
check_profile_artifact_contract
check_laptop_build_caps
check_sops_encrypted

if [ "$failures" -gt 0 ]; then
  exit 1
fi
