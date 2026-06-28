# Agent Self-Improvement

This repo is maintained mostly by coding agents. Treat repeated friction as a bug in the repo's agent interface, but keep the closeout check terse.

## Triggers

- Run `agent-self-improve --check` when a session hits a meaningful hurdle: failed assumptions, unclear ownership, missing validation, surprising formatter behavior, brittle commands, or time spent searching for repo conventions. This is friction-triggered, not a per-session ritual.
- In Claude Code a `Stop` hook (`~/.claude/hooks/friction-stop.sh`, fed by `friction-log.sh`) surfaces failed `just`/`nix` validation automatically; treat that nudge as a trigger. Other agents (Codex) self-assess against the hurdle list above.
- Use `home/scripts/agent-self-improve --check` when the shell lacks `~/.local/bin`.
- If the hurdle is caused by missing or weak repo guidance, make the smallest useful improvement before the final response.

## Improvement Targets

Prefer durable changes that make the next agent faster or less error-prone:

- `AGENT_MAP.md` for routing, ownership, edit rules, validation, and search shortcuts.
- `docs/agent-self-improvement.md` for this protocol.
- `checks/agent-*.bash` for machine-checkable repo conventions.
- `home/scripts/new-*` or other helper scripts for repeated edit patterns.
- `justfile` for stable command entrypoints.

## Rules

- Keep improvements narrow and directly connected to observed friction.
- Prefer executable checks over prose when a convention can be tested.
- Do not add vague reminders, placeholders, or future-work notes.
- Do not broaden validation just to be conservative; document the smallest command that proves the changed surface.
- If no useful improvement exists, say that the self-improvement check found nothing worth changing.

## Closeout Flow

1. Run the relevant validation for the task.
2. Run `agent-self-improve --check`, or `home/scripts/agent-self-improve --check` if needed.
3. If durable friction appeared, edit the smallest relevant doc, check, script, or `just` recipe.
4. Re-run the validation that covers that improvement.
5. Mention only whether a self-improvement change was made.
