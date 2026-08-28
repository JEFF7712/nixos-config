#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Cursor CLI treats empty stdout as a failed hook; no-ops must print JSON.
assert_ok_json() {
  local out=$1 event=$2
  case "$event" in
    preToolUse)
      printf '%s\n' "$out" | jq -e '.permission == "allow"' >/dev/null \
        || fail "expected preToolUse allow JSON, got: $out"
      ;;
    PreToolUse)
      printf '%s\n' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null \
        || fail "expected PreToolUse allow JSON, got: $out"
      ;;
    *)
      printf '%s\n' "$out" | jq -e '. == {}' >/dev/null \
        || fail "expected empty-object JSON, got: $out"
      ;;
  esac
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
assert_ok_json "$fmt_out" PostToolUse
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
assert_ok_json "$cursor_parse" afterFileEdit
[ -s /tmp/nixos-agent-hooks-test-hook-test-cursor-parse.log ] \
  || fail "afterFileEdit parse error was not logged as friction"
rm -f /tmp/nixos-agent-hooks-test-hook-test-cursor-parse.log

prefix=/tmp/nixos-agent-hooks-test
sid=hook-test-friction
rm -f "$prefix-$sid.log" "$prefix-$sid.fired"

log_cmd() {
  local payload=$1
  printf '%s\n' "$payload" | NIXOS_AGENT_FRICTION_PREFIX=$prefix hooks/friction-log >/dev/null
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
assert_ok_json "$aborted" stop
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
assert_ok_json "$cursor_again" stop
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
assert_ok_json "$allow_add" preToolUse

allow_dot_file=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git add ./hosts/laptop/base.nix"}}'
  )"
)
assert_ok_json "$allow_dot_file" preToolUse

rewrite_diff=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git diff --cached",working_directory:"'"$PWD"'"}}'
  )"
)
printf '%s\n' "$rewrite_diff" | jq -e '
  .permission == "allow"
  and (.updated_input.command | test("git diff --no-ext-diff --cached"))
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
  and (.hookSpecificOutput.updatedInput.command | test("git diff --no-ext-diff HEAD"))
  and (.hookSpecificOutput.updatedInput.command | test("^git status &&"))
' >/dev/null || fail "before-shell did not rewrite compound git diff: $rewrite_compound"

# The rewritten form has to be one git actually accepts. `git --no-ext-diff
# diff` parses it as a global option and dies; this catches that class of bug
# without caring what the working tree currently looks like.
flag_probe=$(git diff --no-ext-diff --stat HEAD 2>&1 || true)
case "$flag_probe" in
  *'unknown option'*)
    fail "git rejects the flag position the hook rewrites to: $flag_probe"
    ;;
esac

skip_flagged=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git --no-ext-diff diff"}}'
  )"
)
assert_ok_json "$skip_flagged" preToolUse

skip_status=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"preToolUse",cwd:$cwd,tool_input:{command:"git status"}}'
  )"
)
assert_ok_json "$skip_status" preToolUse

codex_skip_status=$(
  run_before_shell "$(
    jq -n --arg cwd "$PWD" \
      '{hook_event_name:"PreToolUse",turn_id:"hook-test-turn",tool_name:"Bash",cwd:$cwd,tool_input:{command:"git status"}}'
  )"
)
printf '%s\n' "$codex_skip_status" | jq -e '. == {}' >/dev/null \
  || fail "Codex before-shell emitted an unsupported no-op decision: $codex_skip_status"

outside_add=$(
  run_before_shell "$(
    jq -n '{hook_event_name:"preToolUse",cwd:"/tmp",tool_input:{command:"git add ."}}'
  )"
)
assert_ok_json "$outside_add" preToolUse

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
