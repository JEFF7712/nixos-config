#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

tmp_nix=
cleanup() {
  if [ -n "${tmp_nix:-}" ]; then
    git -C . restore --staged -- "$tmp_nix" >/dev/null 2>&1 || true
    rm -f "$tmp_nix"
  fi
}
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || fail "jq is required to test agent hooks"
command -v nixfmt >/dev/null 2>&1 || fail "nixfmt is required to test after-edit formatting"

tmp_nix=$(mktemp --suffix=.nix "$PWD/checks/.agent-hooks-XXXXXX")

printf '{foo=1;}\n' >"$tmp_nix"
fmt_out=$(
  jq -n --arg f "$tmp_nix" \
    '{hook_event_name:"PostToolUse",session_id:"hook-test-fmt",tool_input:{file_path:$f}}' |
    hooks/after-edit
)
[ -z "$fmt_out" ] || fail "after-edit printed on a valid file: $fmt_out"
grep -Fq '{ foo = 1; }' "$tmp_nix" || fail "after-edit did not nixfmt $tmp_nix"
git -C . diff --cached --quiet -- "$tmp_nix" && fail "after-edit did not stage new file $tmp_nix"
git -C . restore --staged -- "$tmp_nix"

printf '{ foo = ; }\n' >"$tmp_nix"
parse_out=$(
  jq -n --arg f "$tmp_nix" \
    '{hook_event_name:"PostToolUse",session_id:"hook-test-parse",tool_input:{file_path:$f}}' |
    hooks/after-edit
)
printf '%s\n' "$parse_out" | jq -e '.decision == "block" and (.reason | test("parse error"))' >/dev/null \
  || fail "after-edit did not block a Nix parse error: $parse_out"

cursor_parse=$(
  jq -n --arg f "$tmp_nix" --arg sid "hook-test-cursor-parse" \
    '{hook_event_name:"afterFileEdit",conversation_id:$sid,file_path:$f}' |
    NIXOS_AGENT_FRICTION_PREFIX=/tmp/nixos-agent-hooks-test \
    hooks/after-edit
)
[ -z "$cursor_parse" ] || fail "afterFileEdit parse check printed: $cursor_parse"
[ -s /tmp/nixos-agent-hooks-test-hook-test-cursor-parse.log ] \
  || fail "afterFileEdit parse error was not logged as friction"
rm -f /tmp/nixos-agent-hooks-test-hook-test-cursor-parse.log

prefix=/tmp/nixos-agent-hooks-test
sid=hook-test-friction
rm -f "$prefix-$sid.log" "$prefix-$sid.fired"

log_cmd() {
  local payload=$1
  printf '%s\n' "$payload" | NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-log
}

log_cmd "$(
  jq -n --arg cwd "$PWD" \
    '{hook_event_name:"PostToolUseFailure",session_id:"hook-test-friction",cwd:$cwd,tool_input:{command:"just eval laptop"}}'
)"
[ -s "$prefix-$sid.log" ] || fail "friction-log missed a failed just command"

: >"$prefix-$sid.log"
log_cmd "$(
  jq -n --arg cwd "$PWD" \
    '{hook_event_name:"PostToolUse",session_id:"hook-test-friction",cwd:$cwd,tool_input:{command:"just eval laptop"},tool_response:{exit_code:0}}'
)"
[ ! -s "$prefix-$sid.log" ] || fail "friction-log recorded a successful command"

log_cmd "$(
  jq -n --arg cwd "$PWD" \
    '{hook_event_name:"PostToolUseFailure",session_id:"hook-test-friction",cwd:$cwd,tool_input:{command:"rg foo"}}'
)"
[ ! -s "$prefix-$sid.log" ] || fail "friction-log recorded a non-validation command"

log_cmd "$(
  jq -n \
    '{hook_event_name:"PostToolUseFailure",session_id:"hook-test-friction",cwd:"/tmp",tool_input:{command:"just eval laptop"}}'
)"
[ ! -s "$prefix-$sid.log" ] || fail "friction-log recorded a command outside the repo"

log_cmd "$(
  jq -n --arg cwd "$PWD" \
    '{hook_event_name:"PostToolUse",session_id:"hook-test-friction",cwd:$cwd,tool_input:{command:"nix eval .#foo"},tool_response:{exit_code:1}}'
)"
[ -s "$prefix-$sid.log" ] || fail "friction-log missed a failed Codex nix eval"

aborted=$(
  printf '%s\n' '{"hook_event_name":"stop","status":"aborted","conversation_id":"hook-test-friction"}' |
    NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-stop
)
[ -z "$aborted" ] || fail "friction-stop nudged on abort: $aborted"
[ -s "$prefix-$sid.log" ] || fail "friction-stop consumed the log on abort"

cursor_stop=$(
  printf '%s\n' '{"hook_event_name":"stop","status":"completed","conversation_id":"hook-test-friction"}' |
    NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-stop
)
printf '%s\n' "$cursor_stop" | jq -e '.followup_message | test("Validation friction")' >/dev/null \
  || fail "Cursor stop nudge missing: $cursor_stop"

printf '%s\n' 'just eval laptop' >"$prefix-$sid.log"
cursor_again=$(
  printf '%s\n' '{"hook_event_name":"stop","status":"completed","conversation_id":"hook-test-friction"}' |
    NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-stop
)
[ -z "$cursor_again" ] || fail "friction-stop looped after firing: $cursor_again"
rm -f "$prefix-$sid.log" "$prefix-$sid.fired"

printf '%s\n' 'just eval laptop' >"$prefix-$sid.log"
codex_stop=$(
  printf '%s\n' '{"hook_event_name":"Stop","session_id":"hook-test-friction","model":"gpt-5.6"}' |
    NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-stop
)
printf '%s\n' "$codex_stop" | jq -e '.decision == "block" and (.reason | test("Validation friction"))' >/dev/null \
  || fail "Codex stop nudge missing: $codex_stop"
rm -f "$prefix-$sid.log" "$prefix-$sid.fired"

printf '%s\n' 'just eval laptop' >"$prefix-$sid.log"
claude_nudge=$(
  printf '%s\n' '{"hook_event_name":"Stop","session_id":"hook-test-friction"}' |
    NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-stop
)
printf '%s\n' "$claude_nudge" | jq -e '.hookSpecificOutput.additionalContext | test("Validation friction")' >/dev/null \
  || fail "Claude stop nudge missing: $claude_nudge"
rm -f "$prefix-$sid.log" "$prefix-$sid.fired"

run_before_shell() {
  local payload=$1
  printf '%s\n' "$payload" | hooks/before-shell
}

deny_add=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git add ."}}'
  )"
)
printf '%s\n' "$deny_add" | jq -e '.permission == "deny" and (.agent_message | test("git add"))' >/dev/null \
  || fail "Cursor before-shell did not deny git add .: $deny_add"

deny_all=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"PreToolUse",cwd:$cwd,tool_input:{command:"git add -A"}}'
  )"
)
printf '%s\n' "$deny_all" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null \
  || fail "Claude before-shell did not deny git add -A: $deny_all"

deny_all_long=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"PreToolUse",cwd:$cwd,tool_input:{command:"git add --all && just eval laptop"}}'
  )"
)
printf '%s\n' "$deny_all_long" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null \
  || fail "before-shell did not deny git add --all: $deny_all_long"

allow_add=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git add hosts/laptop/base.nix"}}'
  )"
)
[ -z "$allow_add" ] || fail "before-shell blocked a specific git add: $allow_add"

allow_dot_file=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git add ./hosts/laptop/base.nix"}}'
  )"
)
[ -z "$allow_dot_file" ] || fail "before-shell blocked git add ./file: $allow_dot_file"

rewrite_diff=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git diff --cached",working_directory:"'"$PWD"'"}}'
  )"
)
printf '%s\n' "$rewrite_diff" | jq -e '
  .permission == "allow"
  and (.updated_input.command | test("git --no-ext-diff diff --cached"))
  and .updated_input.working_directory != null
' >/dev/null || fail "Cursor before-shell did not rewrite git diff: $rewrite_diff"

rewrite_compound=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"PreToolUse",cwd:$cwd,tool_input:{command:"git status && git diff HEAD"}}'
  )"
)
printf '%s\n' "$rewrite_compound" | jq -e '
  .hookSpecificOutput.permissionDecision == "allow"
  and (.hookSpecificOutput.updatedInput.command | test("git --no-ext-diff diff HEAD"))
' >/dev/null || fail "before-shell did not rewrite compound git diff: $rewrite_compound"

skip_flagged=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git --no-ext-diff diff"}}'
  )"
)
[ -z "$skip_flagged" ] || fail "before-shell rewrote an already-flagged git diff: $skip_flagged"

skip_status=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git status"}}'
  )"
)
[ -z "$skip_status" ] || fail "before-shell touched git status: $skip_status"

outside_add=$(
  run_before_shell "$(
    jq -n '{hook_event_name:"preToolUse",cwd:"/tmp",tool_input:{command:"git add ."}}'
  )"
)
[ -z "$outside_add" ] || fail "before-shell applied repo policy outside the repo: $outside_add"

cursor_ctx=$(
  printf '%s\n' '{"hook_event_name":"sessionStart","session_id":"hook-test-session"}' |
    hooks/session-start
)
printf '%s\n' "$cursor_ctx" | jq -e '.additional_context | test("Suggested validation")' >/dev/null \
  || fail "Cursor session-start missing agent-context: $cursor_ctx"

claude_ctx=$(
  printf '%s\n' '{"hook_event_name":"SessionStart","session_id":"hook-test-session"}' |
    hooks/session-start
)
printf '%s\n' "$claude_ctx" | jq -e '.hookSpecificOutput.additionalContext | test("just agent-context")' >/dev/null \
  || fail "Claude session-start missing agent-context: $claude_ctx"
