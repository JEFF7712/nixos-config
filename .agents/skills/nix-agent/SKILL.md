---
name: nix-agent
description: Operate on this machine's NixOS or integrated Home Manager configuration with the nix-agent MCP tools (build, diff, generations, eval_config, locate_option, check) alongside this repo's `just` workflow. Use when changing packages, options, or modules; diagnosing a failed build; rolling back a generation; or asking what the live config resolves to.
---

# Nix Agent

## Overview

`nix-agent` MCP tools do not edit configuration files. They build, diff, and
manage generations, and evaluate, locate, and check the configuration, handing
every result back as a compact JSON envelope. Read the envelope instead of
re-fetching logs or `systemctl` output by hand.

Division of labor in `~/nixos`:
- **Your native tools** (Read/Edit/Write) edit `.nix` files.
- **`mcp-nixos`** discovers upstream packages and options (what exists, what it means).
- **`nix-agent`** inspects and builds this repo's configuration (`eval_config`, `locate_option`, `check`, `build`, `diff`, `generations`).
- **`just` recipes** run repo-specific validation (`just check-changed`, `just quick`, `just fmt`) and **all local activations (`just switch`)**.

> **Activation rule in this repo (`docs/deployment.md`):**
> Never call `nix-agent` `switch()`, `nixos-rebuild switch|boot|test`, `nh os switch|boot|test`, or `home-manager switch`. `hooks/before-mcp` and `hooks/before-shell` intentionally block them. Activate **only** via `just switch` (and only when the user asks to apply/switch), because `just switch` holds the switch lock (concurrent builds OOM this laptop), runs `nix-cascade-guard`, and pauses `comin` so background GitOps does not revert local state.

## Check tool availability

Inspect the session's exposed tool catalog once before planning around MCP
calls. If `nix-agent` tools are absent in the current host session, state that
once and use the repo's `just` recipes (`just eval`, `just build`, `just dry`,
`just check-changed`) within existing hook rules.

## Preferred operations

| Operation | Preferred call |
|---|---|
| Local activation (only when requested) | `just switch` (never `switch()`) |
| Build closure without activating | `build()` (or `just build [target]`) |
| Dry-activate preview | `check("dry-activate")` (or `just dry`) |
| Evaluate merged option value(s) | `eval_config(attr)` (batch lists in one call) |
| Find which module sets an option | `locate_option(attr)` |
| Lint (`statix` + `deadnix`) | `check("lint")` (or `just fmt`) |
| Closure package diff | `diff()` |
| Read failed builder log | `failed_derivation.log_tail` on the envelope |
| Roll back a system generation | `generations(action="rollback", generation=<id>)` |
| Repo validation gates | `just check-changed` / `just check` |

## Tool Surface

All tools default `mode` to `"nixos"`. Because Home Manager is integrated into
every NixOS host here via `home-manager.nixosModules.home-manager` (there are no
standalone `homeConfigurations`), **always keep `mode="nixos"`** even when
inspecting Home Manager options.

- `build(flake_uri?, mode?, job_id?, log_offset?)`: start or poll a persistent
  background build without activating. Keep `job_id` and pass `log_offset` when
  polling `running` jobs. `ok` carries `store_path`; failures carry
  `failed_derivation`.
- `diff(flake_uri?, mode?, store_path?, against?)`: compare a built or target
  closure against the running closure (or `against`), returning structured
  package additions, removals, and version bumps.
- `generations(action="list"|"rollback", mode?, generation?, limit?)`: list
  generations or roll back to a specific generation ID.
- `eval_config(attr, flake_uri?, mode?)`: final merged value of one attr or a
  **list** of attrs on a host (`~/nixos#laptop`, `#iso`, `#vm`).
  In NixOS mode, unprefixed HM attrs retry as `home-manager.users.<user>.<attr>`
  (`hm_rewritten: true`). Values above ~2 KB truncate with a hint to query
  narrower leaf attributes.
- `locate_option(attr, flake_uri?, mode?)`: returns `declarations` and
  `definitions` (`{file, value}`) for an option. Prefer over tree-wide grep.
- `check(level, flake_uri?, mode?)`: `"lint"` (`statix` + `deadnix`),
  `"dry-build"`, or `"dry-activate"`.

*(Note: `switch()` exists on the server binary for generic repos, but is denied
in `~/nixos` by `hooks/before-mcp`; use `just switch` instead.)*

## Workflow

1. **Discover**: query `mcp-nixos` for upstream option/package schemas;
   `locate_option` / `eval_config` for what this repo resolves.
2. **Edit & format**: edit files with native tools, then run `just fmt` (`nix fmt`).
3. **Validate**: use `build()` / `diff()` for closure inspection and run
   `just check-changed` before handoff. On build/eval failure, read
   `first_error`, `error_detail`, and `failed_derivation.log_tail` before
   reaching for raw logs.
4. **Activate / Ship (only when asked)**:
   - Local apply: `just switch`
   - Land via PR + CI: `just ship`

## Hard Rules

- Never write secret payloads into tracked Nix files; manage encrypted secrets
  solely through `sops-nix` under `secrets/`.
- Never call `switch()` or raw `nixos-rebuild`/`nh`/`home-manager switch`;
  `just switch` is the sole local activation path.
- Batch `eval_config([...])` calls instead of evaluating one attribute at a time,
  and drill into child attributes when `truncated: true` rather than requesting
  unbounded output.
