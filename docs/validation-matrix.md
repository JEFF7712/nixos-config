# Validation Matrix

Use the smallest command set that proves the touched surface, then run `just check` before larger handoffs.

## Validation Matrix

| Change type | Minimum validation | Stronger validation |
| --- | --- | --- |
| Documentation only | `just check-agent-docs` when touching agent docs, otherwise `git diff --check` | `just quick` |
| Agent invariants or scaffolding | `just check-agent-workflows && just shell-check` | `just check` |
| Agent self-improvement protocol | `just check-agent-docs && just check-agent-workflows` | `just check` |
| Nix formatting or simple module edit | `just fmt-check && just eval laptop` | `just check` |
| NixOS module enabled on one host | `just eval <host>` | `just build <host>` |
| Home-manager module | `just eval laptop` | `just check` |
| Desktop profile or profile library | `just check-profiles && just fmt-check` | `just check` |
| Runtime shell scripts | `just shell-check` | `just shell-check && just wallpaper-script-check` |
| Wallpaper/profile generation scripts | `just wallpaper-script-check` | `just check` |
| Quickshell QML | `just qml-lint` | `just qml-lint && just eval laptop` |
| Local package or overlay | `just build laptop` | `just check` |
| Flake input update | `just check` | `just build laptop && just build-iso` |
| ISO config | `just eval iso` | `just build-iso` |
| Full pre-handoff | `just check` | `just build laptop` if the change affects realized packages or services |

## Command Notes

- `just quick` is the fast default for low-risk Nix changes: laptop eval plus whitespace checks.
- `just check` mirrors the broad local gate: formatting, shell checks, wallpaper/profile checks, flake check, host evals, profile eval, and whitespace checks.
- `just build <host>` realizes the system closure and catches build failures that eval can miss.
- `just dry` is useful for activation-level confidence on the laptop, but it touches the local system state enough that it should be intentional.
- `just switch` is the final local apply step for laptop changes.
- `agent-self-improve --check` is the closeout prompt for agent self-improvement; use it after validation and after any meaningful hurdle.
