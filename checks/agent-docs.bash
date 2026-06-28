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

require_file AGENT_MAP.md
require_file docs/agent-self-improvement.md

# AGENT_MAP must route the core surfaces, cover validation, and point to closeout.
require_match 'NixOS module' AGENT_MAP.md
require_match 'home-manager module' AGENT_MAP.md
require_match 'desktop profile' AGENT_MAP.md
require_match 'just eval' AGENT_MAP.md
require_match 'just check' AGENT_MAP.md
require_match 'agent-self-improve' AGENT_MAP.md

# Self-improvement protocol must keep its triggers and the closeout command.
require_match 'agent-self-improve --check' docs/agent-self-improvement.md
require_match 'hurdle' docs/agent-self-improvement.md

# agent-context recipe must exist and surface validation + closeout guidance.
require_match '^agent-context:' justfile
require_match 'Suggested validation' justfile
require_match 'agent-self-improve' justfile
