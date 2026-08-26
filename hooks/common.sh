# Shared helpers for repo agent hooks. Sourced, not executed.
# Cursor, Claude, and Codex all invoke the scripts in this directory.

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HOOKS_DIR/.." && pwd)"
FRICTION_PREFIX="${NIXOS_AGENT_FRICTION_PREFIX:-/tmp/nixos-agent-friction}"

HOOK_INPUT=""
HOOK_EVENT_NAME=""
HOOK_SESSION_ID=""
HOOK_CWD=""

agent_hooks_have_jq() {
  command -v jq >/dev/null 2>&1
}

agent_hooks_load() {
  HOOK_INPUT=$(cat)
  agent_hooks_have_jq || return 1
  [ -n "$HOOK_INPUT" ] || return 1
  HOOK_EVENT_NAME=$(jq -r '.hook_event_name // empty' <<<"$HOOK_INPUT" 2>/dev/null) || return 1
  HOOK_SESSION_ID=$(jq -r '.session_id // .conversation_id // "unknown"' <<<"$HOOK_INPUT" 2>/dev/null) || return 1
  HOOK_CWD=$(jq -r '.cwd // empty' <<<"$HOOK_INPUT" 2>/dev/null) || return 1
  return 0
}

agent_hooks_friction_log() {
  printf '%s\n' "$FRICTION_PREFIX-$1.log"
}

agent_hooks_friction_fired() {
  printf '%s\n' "$FRICTION_PREFIX-$1.fired"
}

# True when the path is inside this repo (after resolving .. and links).
agent_hooks_in_repo() {
  local resolved
  resolved=$(realpath -m "$1" 2>/dev/null) || return 1
  case "$resolved" in
    "$REPO_ROOT" | "$REPO_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

agent_hooks_in_repo_cwd() {
  local cwd=${1:-$HOOK_CWD}
  [ -z "$cwd" ] && return 0
  agent_hooks_in_repo "$cwd"
}

# Resolve a hook-provided path to an absolute repo file, or print nothing.
agent_hooks_resolve_repo_file() {
  local raw=$1
  local candidate
  [ -n "$raw" ] || return 0
  case "$raw" in
    /*) candidate=$raw ;;
    *)
      if [ -n "$HOOK_CWD" ]; then
        candidate="$HOOK_CWD/$raw"
      else
        candidate="$REPO_ROOT/$raw"
      fi
      ;;
  esac
  candidate=$(realpath -m "$candidate" 2>/dev/null) || return 0
  agent_hooks_in_repo "$candidate" || return 0
  printf '%s\n' "$candidate"
}

# Unique repo-absolute files touched by this hook event.
agent_hooks_touched_files() {
  local raw path
  [ -n "$HOOK_INPUT" ] || return 0
  {
    jq -r '
      .file_path // empty,
      .tool_input.file_path // empty,
      .tool_input.path // empty,
      (.tool_input.paths // [] | .[])
    ' <<<"$HOOK_INPUT"
    jq -r '.tool_input.command // empty' <<<"$HOOK_INPUT" |
      sed -nE 's/^\*\*\* (Add|Update) File: //p'
  } | while IFS= read -r raw; do
    path=$(agent_hooks_resolve_repo_file "$raw")
    [ -n "$path" ] && printf '%s\n' "$path"
  done | awk 'NF && !seen[$0]++'
}

agent_hooks_is_validation_command() {
  local cmd=$1
  [[ $cmd =~ (^|[;\&|[:space:]])(just|nixos-rebuild|nh)[[:space:]] ]] ||
    [[ $cmd =~ nix[[:space:]]+(build|eval|(flake[[:space:]]+check)) ]]
}

# Numeric or obvious failed-exit payload from Codex/Cursor PostToolUse.
agent_hooks_tool_failed() {
  local event=${HOOK_EVENT_NAME:-}
  local code
  case "$event" in
    PostToolUseFailure | postToolUseFailure) return 0 ;;
  esac
  code=$(jq -r '
    .tool_response.exit_code
    // .tool_response.exitCode
    // .tool_response.metadata.exit_code
    // empty
  ' <<<"$HOOK_INPUT" 2>/dev/null || true)
  if [ -z "$code" ]; then
    code=$(jq -r '
      try (.tool_output | fromjson | .exitCode // .exit_code // empty) catch empty
    ' <<<"$HOOK_INPUT" 2>/dev/null || true)
  fi
  if [ -n "$code" ] && [ "$code" != "null" ] && [ "$code" != "0" ]; then
    return 0
  fi
  return 1
}

agent_hooks_emit_block() {
  local reason=$1
  case "${HOOK_EVENT_NAME:-}" in
    PostToolUse)
      jq -n --arg r "$reason" '{decision: "block", reason: $r}'
      ;;
  esac
}

agent_hooks_emit_stop_nudge() {
  local msg=$1
  local event=${HOOK_EVENT_NAME:-}
  local status
  status=$(jq -r '.status // empty' <<<"$HOOK_INPUT")
  if [ "$event" = "stop" ] || [ -n "$status" ]; then
    jq -n --arg c "$msg" '{followup_message: $c}'
    return 0
  fi
  if jq -e '.model != null' <<<"$HOOK_INPUT" >/dev/null; then
    jq -n --arg c "$msg" '{decision: "block", reason: $c}'
    return 0
  fi
  jq -n --arg c "$msg" \
    '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $c}}'
}
