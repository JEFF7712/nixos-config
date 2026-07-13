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
    .mcp.json | \
      hosts/iso/configuration.nix | \
      hosts/laptop/base.nix | \
      modules/nixos/auto-update.nix | \
      modules/nixos/git.nix)
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
      --glob '!CLAUDE.md' \
      --glob '!AGENTS.md' \
      --glob '!AGENT_MAP.md' \
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
  local entry path

  while IFS= read -r entry; do
    path=${entry#*:}
    if [ ! -d "$path" ]; then
      fail "profile references missing wallpaper directory: $entry"
    fi
  done < <(
    rg --pcre2 -No --replace '$1' \
      'wallpaperDir(?:Light)? = "\$\{config\.repoPath\}/([^"]+)"' \
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
    fail "use repo auto-update/nh clean modules instead of this option: $entry"
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
  local module=${AUTO_UPDATE_MODULE:-modules/nixos/auto-update.nix}
  local pipeline=${FLAKE_UPDATE_PIPELINE:-home/scripts/nixos-flake-update}
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
  if ! rg -q 'OnCalendar = "hourly"' "$module"; then
    fail "nixos-ai-tools-auto-update timer must stay hourly"
  fi
  if ! rg -q 'skipping rebuild' "$pipeline"; then
    fail "nixos-flake-update must skip rebuild when flake.lock is unchanged"
  fi
}

check_flake_update_pipeline_wiring() {
  local module=${AUTO_UPDATE_MODULE:-modules/nixos/auto-update.nix}
  local pipeline=${FLAKE_UPDATE_PIPELINE:-home/scripts/nixos-flake-update}
  local reference_count
  local service

  reference_count=$( (rg -o 'nixos-flake-update' "$module" || true) | wc -l)
  if [ "$reference_count" -ne 2 ]; then
    fail "auto-update module must reference nixos-flake-update exactly twice"
  fi

  for service in nixos-auto-update nixos-ai-tools-auto-update; do
    if ! rg -q "^[[:space:]]*systemd\\.services\\.$service = mkUpdateService \\{" "$module"; then
      fail "$service must use mkUpdateService"
    fi
  done

  if ! rg -q '^[[:space:]]*name = "nixos-flake-update";' "$module" \
    || ! rg -q '^[[:space:]]*text = builtins\.readFile ../../home/scripts/nixos-flake-update;' "$module" \
    || ! rg -q '^[[:space:]]*exec \$\{lib\.getExe updatePipeline\}' "$module"; then
    fail "mkUpdateService must invoke the packaged nixos-flake-update pipeline"
  fi

  local operation pattern
  while IFS='|' read -r operation pattern; do
    if ! rg -q "$pattern" "$pipeline"; then
      fail "nixos-flake-update must own the $operation operation"
    fi
    if rg -q "$pattern" "$module"; then
      fail "auto-update module must not inline the $operation operation"
    fi
  done <<'EOF'
eval|^[[:space:]]*if ! runuser .* -- nix eval
cascade|^[[:space:]]*runuser .* -- "\$cascade_guard"
commit|^[[:space:]]*runuser .* -- git .* commit
rebuild|^[[:space:]]*"\$nixos_rebuild" switch
EOF
}

check_hardcoded_repo_paths
check_auto_discovered_imports
check_module_options
check_wallpaper_dirs
check_script_refs
check_disabled_nix_services
check_profile_artifact_contract
check_laptop_build_caps
check_flake_update_pipeline_wiring

if [ "$failures" -gt 0 ]; then
  exit 1
fi
