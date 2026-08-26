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
