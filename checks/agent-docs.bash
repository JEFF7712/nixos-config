#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

require_file() {
  local path=$1

  if [ ! -s "$path" ]; then
    echo "missing or empty: $path" >&2
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

require_backtick_in_claude() {
  local name=$1
  local what=$2

  if ! rg -qF "\`$name\`" CLAUDE.md; then
    echo "CLAUDE.md does not name $what: $name" >&2
    exit 1
  fi
}

require_file AGENT_MAP.md
require_file CLAUDE.md
require_file docs/agent-self-improvement.md
require_file hooks/after-edit
require_file hooks/before-shell
require_file hooks/friction-log
require_file hooks/friction-stop
require_file hooks/session-start
require_file .cursor/hooks.json
require_file .claude/settings.json
require_file .codex/hooks.json

# AGENT_MAP must route the core surfaces, cover validation, and point to closeout.
require_match 'NixOS module' AGENT_MAP.md
require_match 'home-manager module' AGENT_MAP.md
require_match 'desktop profile' AGENT_MAP.md
require_match 'just eval' AGENT_MAP.md
require_match 'just check' AGENT_MAP.md
require_match 'agent-self-improve' AGENT_MAP.md
require_match 'hooks/' AGENT_MAP.md

# Self-improvement protocol must keep its triggers and the closeout command.
require_match 'agent-self-improve --check' docs/agent-self-improvement.md
require_match 'hurdle' docs/agent-self-improvement.md
require_match 'hooks/friction-stop' docs/agent-self-improvement.md

# Shared agent hooks must stay wired from Cursor, Claude, and Codex configs.
require_match 'hooks/' CLAUDE.md
for hook_config in .cursor/hooks.json .claude/settings.json .codex/hooks.json; do
  require_match 'hooks/after-edit' "$hook_config"
  require_match 'hooks/before-shell' "$hook_config"
  require_match 'hooks/friction-log' "$hook_config"
  require_match 'hooks/friction-stop' "$hook_config"
  require_match 'hooks/session-start' "$hook_config"
done

# agent-context recipe must exist and surface validation + closeout guidance.
# SessionStart injects it; agent docs must not tell agents to run it first.
require_match '^agent-context:' justfile
require_match 'Suggested validation' justfile
require_match 'agent-self-improve' justfile
require_match 'hooks/session-start' CLAUDE.md
require_match 'hooks/before-shell' CLAUDE.md
if rg -q 'run `just agent-context`' CLAUDE.md AGENTS.md AGENT_MAP.md; then
  echo "session-start injects agent-context; don't tell agents to run it first" >&2
  exit 1
fi

# CLAUDE.md must name every host, imported overlay, and profile module.
# Reverse overlay/profile checks use backtick tokens on those listing lines so
# unrelated prose (for example nh clean) cannot false-fail.

while IFS= read -r host_dir; do
  require_backtick_in_claude "$(basename "$host_dir")" host
done < <(fd -t d -d 1 . hosts | sort)

while IFS= read -r overlay; do
  [ -n "$overlay" ] || continue
  require_backtick_in_claude "$overlay" overlay
done < <(
  {
    rg -o 'import \./([A-Za-z0-9_-]+)\.nix' -r '$1' overlays/default.nix || true
    rg -o '([A-Za-z0-9_-]+)\.overlays' -r '$1' overlays/default.nix || true
  } | sort -u
)

overlays_line=$(rg '^- Overlays live in' CLAUDE.md || true)
if [ -z "$overlays_line" ]; then
  echo "CLAUDE.md is missing the Overlays gotcha line" >&2
  exit 1
fi
while IFS= read -r overlay; do
  [ -n "$overlay" ] || continue
  if [ ! -f "overlays/${overlay}.nix" ] && ! rg -qF "$overlay" overlays/default.nix; then
    echo "CLAUDE.md names overlay that does not exist: $overlay" >&2
    exit 1
  fi
done < <(printf '%s\n' "$overlays_line" | rg -o '`([a-z][a-z0-9-]*)`' -r '$1' || true)

while IFS= read -r profile_file; do
  require_backtick_in_claude "$(basename "$profile_file" .nix)" profile
done < <(fd -t f -e nix . modules/home-manager/profiles | sort)

profiles_block=$(awk '/^\*\*Desktop profiles\*\*/ { p=1; print; next } p && /^\*\*/ { exit } p { print }' CLAUDE.md)
if [ -z "$profiles_block" ]; then
  echo "CLAUDE.md is missing the Desktop profiles paragraph" >&2
  exit 1
fi
while IFS= read -r profile; do
  [ -n "$profile" ] || continue
  if [ ! -f "modules/home-manager/profiles/${profile}.nix" ]; then
    echo "CLAUDE.md names profile that has no module: $profile" >&2
    exit 1
  fi
done < <(printf '%s\n' "$profiles_block" | rg -o '`([a-z]+)`' -r '$1' || true)
