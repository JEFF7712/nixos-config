# Agent Map

Fast routing for AI agents working in this repo. Use this before broad code search.

## Task Routing

| Task | Inspect first | Usually edit | Validate |
| --- | --- | --- | --- |
| Add or change a NixOS module | `modules/nixos/`, `hosts/<host>/configuration.nix` | `modules/nixos/<name>.nix`, host enable flags | `just fmt-check && just eval <host>` |
| Add or change a home-manager module | `modules/home-manager/`, `home/rupan/<host>.nix` | `modules/home-manager/<name>.nix`, user enable flags | `just fmt-check && just eval laptop` |
| Scaffold a NixOS module | `modules/nixos/`, `hosts/<host>/configuration.nix` | run `new-nixos-module <name>`, then edit the generated module | `just check-agent-workflows && just fmt-check` |
| Scaffold a home-manager module | `modules/home-manager/`, `home/rupan/<host>.nix` | run `new-home-module <name>`, then edit the generated module | `just check-agent-workflows && just fmt-check` |
| Change desktop profile behavior | `modules/home-manager/desktop-profiles.nix`, `lib/desktop-profiles/` | profile module, profile helper library | `just check-profiles && just fmt-check` |
| Add or tune a desktop profile | `modules/home-manager/profiles/`, `home/scripts/new-profile` | `modules/home-manager/profiles/<name>.nix`, `home/assets/wallpapers/<name>/` | `just check-profiles && just fmt-check` |
| Change runtime profile scripts | `home/scripts/profile-common`, target script | `home/scripts/<script>` | `just shell-check && just wallpaper-script-check` |
| Change Quickshell UI | `home/configs/quickshell*/`, profile bar references | QML/config files under `home/configs/quickshell*/` | `just qml-lint && just eval laptop` |
| Add a local package | `pkgs/`, `overlays/local-packages.nix` | `pkgs/<name>/default.nix`, overlay export | `just build laptop` |
| Change overlays | `overlays/default.nix`, target overlay file | `overlays/<name>.nix` | `just build laptop` |
| Update flake inputs | `flake.nix`, `flake.lock` | `flake.lock` via `just update` | `just check` |
| Change ISO behavior | `hosts/iso/configuration.nix`, `home/rupan/iso.nix` | ISO host or ISO home config | `just eval iso && just build-iso` |
| Change agent tooling | `modules/home-manager/ai-tools.nix`, `modules/home-manager/serena.nix`, agent docs | agent module, `CLAUDE.md`, `AGENT_MAP.md` | `just check-agent-docs && just eval laptop` |
| Change agent invariants or scaffolds | `checks/agent-invariants.bash`, `checks/agent-workflows.bash`, `home/scripts/new-*module` | invariant checker, workflow test, scaffold scripts | `just check-agent-workflows && just shell-check` |
| Change agent self-improvement behavior | `docs/agent-self-improvement.md`, `AGENT_MAP.md`, `checks/agent-*.bash` | protocol doc, agent checks, helper scripts | `just check-agent-docs && just check-agent-workflows` |

## Edit Rules

- New NixOS modules go in `modules/nixos/` and are auto-discovered by `import-tree`.
- New home-manager modules go in `modules/home-manager/` and are auto-discovered by `import-tree`.
- Use `lib.mkEnableOption` plus `lib.mkIf config.<option>.enable` for module toggles.
- Use `config.repoPath` for repo-relative paths that must point outside the Nix store.
- Do not add manual imports for files under auto-discovered module trees.
- Do not add `nix.gc` or `system.autoUpgrade`; cleanup and updates are already handled by repo modules.
- Prefer existing helpers in `lib/desktop-profiles/` before adding profile-specific generated file logic.
- Keep generated or mutable desktop config under `home/configs/` or `home/scripts/`, not inline in unrelated modules.
- Do not use `git add .`; stage the specific files changed.
- Use `new-nixos-module <name>` and `new-home-module <name>` for new auto-discovered modules.

## Validation

Run the smallest command that proves the touched surface; the "Validate" column above is the per-task minimum. Run `just check` before larger handoffs.

- `just quick` - fast default for low-risk Nix edits: laptop eval plus whitespace.
- `just check` - broad local gate: agent checks, fmt, shell/wallpaper/profile checks, flake check, host evals, whitespace. Superset of CI (CI skips the heavier evals/builds).
- `just build <host>` - realizes the closure and catches build failures eval misses. Use for package, overlay, or flake-input changes.
- `just dry` / `just switch` - activation and final apply for laptop changes; intentional, they touch system state.
- Escalate a task's minimum to `just check` when the change is risky, then `just build <host>` if it affects realized packages or services.

## Session Closeout

Run `agent-self-improve --check` when a session hits durable friction (unexplained validation failures, unclear ownership, missing or weak docs/checks, time hunting conventions), not as a per-session ritual (`home/scripts/agent-self-improve --check` if `~/.local/bin` is off PATH). In Claude Code a `Stop` hook surfaces failed `just`/`nix` runs as a nudge. If friction appeared, fix the smallest relevant doc, check, script, or `just` recipe; a clean session needs no note. Full protocol: `docs/agent-self-improvement.md`.

## Search Shortcuts

| Need | Command |
| --- | --- |
| Find an option owner | `rg -n "options\\..*<name>|<name>\\.enable" modules hosts home` |
| Find package placement | `rg -n "<package>|pkgs-stable|home.packages|environment.systemPackages" modules hosts home overlays pkgs` |
| Find profile fields | `rg -n "desktopProfiles\\.profiles|wallpaperDir|quickshellTheme|waybar" modules/home-manager/profiles lib/desktop-profiles` |
| Find runtime script callers | `rg -n "<script-name>|\\.local/bin|home/scripts" home modules` |
