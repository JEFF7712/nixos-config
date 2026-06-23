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
require_file docs/validation-matrix.md
require_file docs/agent-self-improvement.md

require_match '^## Task Routing$' AGENT_MAP.md
require_match '^## Edit Rules$' AGENT_MAP.md
require_match '^## Session Closeout$' AGENT_MAP.md
require_match 'desktop profile' AGENT_MAP.md
require_match 'home-manager module' AGENT_MAP.md
require_match 'NixOS module' AGENT_MAP.md
require_match 'agent-self-improve' AGENT_MAP.md

require_match '^## Validation Matrix$' docs/validation-matrix.md
require_match 'just quick' docs/validation-matrix.md
require_match 'just check-profiles' docs/validation-matrix.md
require_match 'just qml-lint' docs/validation-matrix.md
require_match 'just build' docs/validation-matrix.md
require_match 'agent self-improvement' docs/validation-matrix.md

require_match '^## Triggers$' docs/agent-self-improvement.md
require_match '^## Improvement Targets$' docs/agent-self-improvement.md
require_match 'end of every coding-agent session' docs/agent-self-improvement.md
require_match 'hurdle' docs/agent-self-improvement.md

require_match '^agent-context:' justfile
require_match "printf 'Repo\\\\n'" justfile
require_match "printf 'Git\\\\n'" justfile
require_match "printf 'Hosts\\\\n'" justfile
require_match "printf 'Active desktop profile\\\\n'" justfile
require_match "printf 'Suggested validation\\\\n'" justfile
require_match "printf 'Self-improvement\\\\n'" justfile
