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

agent_hooks_shell_command() {
  jq -r '.command // .tool_input.command // empty' <<<"$HOOK_INPUT"
}

agent_hooks_trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

agent_hooks_shell_segments() {
  printf '%s\n' "$1" | sed -E 's/&&/\n/g; s/\|\|/\n/g; s/;/\n/g; s/\|/\n/g; s/&/\n/g'
}

agent_hooks_strip_env_prefix() {
  local segment=$1
  while [[ $segment =~ ^[A-Za-z_][A-Za-z0-9_]*=([^[:space:]]*)[[:space:]]+(.*)$ ]]; do
    segment=${BASH_REMATCH[2]}
  done
  printf '%s' "$segment"
}

# True when this git-add argv is shotgun staging (. / -A / --all / *).
agent_hooks_git_add_args_are_shotgun() {
  local arg saw_dd=0
  for arg in "$@"; do
    if [ "$saw_dd" -eq 0 ]; then
      case "$arg" in
        --) saw_dd=1 ; continue ;;
        -A | --all) return 0 ;;
        -*) continue ;;
      esac
    fi
    case "$arg" in
      . | ./ | '*' | './*') return 0 ;;
    esac
  done
  return 1
}

# $1 is one shell segment. True when it is `git … add` with shotgun pathspecs.
agent_hooks_git_add_is_shotgun_segment() {
  local -a words
  local i=1 n
  read -r -a words <<<"$1" || return 1
  n=${#words[@]}
  [ "$n" -gt 0 ] || return 1
  [ "${words[0]}" = git ] || return 1
  while [ "$i" -lt "$n" ]; do
    case ${words[i]} in
      add)
        i=$((i + 1))
        agent_hooks_git_add_args_are_shotgun "${words[@]:i}"
        return $?
        ;;
      -C | -c | --git-dir | --work-tree | --namespace | --config-env | --super-prefix)
        i=$((i + 2))
        ;;
      -*)
        i=$((i + 1))
        ;;
      *)
        return 1
        ;;
    esac
  done
  return 1
}

agent_hooks_is_shotgun_git_add() {
  local segment
  while IFS= read -r segment; do
    segment=$(agent_hooks_trim "$segment")
    [ -n "$segment" ] || continue
    segment=$(agent_hooks_strip_env_prefix "$segment")
    agent_hooks_git_add_is_shotgun_segment "$segment" && return 0
  done < <(agent_hooks_shell_segments "$1")
  return 1
}

# $1 is one shell segment. True when the git subcommand is `diff`.
agent_hooks_git_diff_segment() {
  local -a words
  local i=1 n
  read -r -a words <<<"$1" || return 1
  n=${#words[@]}
  [ "$n" -gt 0 ] || return 1
  [ "${words[0]}" = git ] || return 1
  while [ "$i" -lt "$n" ]; do
    case ${words[i]} in
      diff) return 0 ;;
      -C | -c | --git-dir | --work-tree | --namespace | --config-env | --super-prefix)
        i=$((i + 2))
        ;;
      -*)
        i=$((i + 1))
        ;;
      *)
        return 1
        ;;
    esac
  done
  return 1
}

agent_hooks_needs_no_ext_diff() {
  local segment
  [[ $1 == *--no-ext-diff* ]] && return 1
  while IFS= read -r segment; do
    segment=$(agent_hooks_trim "$segment")
    [ -n "$segment" ] || continue
    segment=$(agent_hooks_strip_env_prefix "$segment")
    agent_hooks_git_diff_segment "$segment" && return 0
  done < <(agent_hooks_shell_segments "$1")
  return 1
}

# Insert --no-ext-diff after the `diff` subcommand, in git-diff invocations
# only. It is a diff-command option, not a git global one: `git --no-ext-diff
# diff` is a hard "unknown option" error, and the old rewrite also hit every
# other git subcommand in a compound command (`git status && git diff` broke
# the status half).
agent_hooks_rewrite_no_ext_diff() {
  local cmd=$1
  [[ $cmd == *--no-ext-diff* ]] && {
    printf '%s' "$cmd"
    return 0
  }
  # Words between `git` and `diff` are global flags (-C <path>, --no-pager);
  # the class excludes shell separators so the match cannot span segments.
  sed -E 's/(^|&&|\|\||;|\||&)([[:space:]]*git[[:space:]]+([^[:space:]|&;]+[[:space:]]+)*)diff([[:space:]]|$)/\1\2diff --no-ext-diff\4/g' <<<"$cmd"
}

# Always print JSON. Cursor CLI classifies empty stdout as a failed hook
# (errorClass empty_stdout) even when the process exits 0.
agent_hooks_emit_ok() {
  case "${HOOK_EVENT_NAME:-}" in
    beforeShellExecution | preToolUse)
      jq -n '{permission:"allow"}'
      ;;
    PreToolUse)
      if jq -e '.turn_id != null' <<<"$HOOK_INPUT" >/dev/null; then
        jq -n '{}'
      else
        jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow"}}'
      fi
      ;;
    *)
      jq -n '{}'
      ;;
  esac
}

agent_hooks_ok_exit() {
  agent_hooks_emit_ok
  exit 0
}

agent_hooks_emit_deny() {
  local reason=$1
  case "${HOOK_EVENT_NAME:-}" in
    beforeShellExecution | preToolUse)
      jq -n --arg r "$reason" \
        '{permission:"deny",agent_message:$r,user_message:$r}'
      ;;
    PreToolUse)
      jq -n --arg r "$reason" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
      ;;
    *)
      jq -n --arg r "$reason" '{decision:"block",reason:$r}'
      ;;
  esac
}

# Rewrite the shell command. Prints JSON and returns 0 when the event
# supports it; returns 1 so the caller can deny with a retry instead.
agent_hooks_emit_rewrite_command() {
  local new_cmd=$1
  local input
  input=$(jq -c '.tool_input // {}' <<<"$HOOK_INPUT")
  case "${HOOK_EVENT_NAME:-}" in
    preToolUse)
      jq -n --arg cmd "$new_cmd" --argjson input "$input" \
        '{permission:"allow",updated_input:($input + {command:$cmd})}'
      ;;
    PreToolUse)
      jq -n --arg cmd "$new_cmd" --argjson input "$input" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:($input + {command:$cmd})}}'
      ;;
    *)
      return 1
      ;;
  esac
}

agent_hooks_emit_additional_context() {
  local ctx=$1
  case "${HOOK_EVENT_NAME:-}" in
    sessionStart)
      jq -n --arg c "$ctx" '{additional_context:$c}'
      ;;
    SessionStart)
      jq -n --arg c "$ctx" \
        '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
      ;;
    *)
      jq -n --arg c "$ctx" \
        '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
      ;;
  esac
}
