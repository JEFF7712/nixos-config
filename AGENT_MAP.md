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
| Add or tune a desktop profile | `modules/home-manager/profiles/`, `home/scripts/new-profile` | `modules/home-manager/profiles/<name>.nix`, `~/nixos-assets/wallpapers/<name>/` (separate repo) | `just check-profiles && just fmt-check` |
| Change xhisper dictation | `pkgs/xhisper-local/`, `home/configs/xhisper/`, `modules/nixos/xhisper-local.nix` | package patches, xhisperrc, popup QML | `just xhisper-check && just eval laptop` |
| Change runtime profile scripts | `home/scripts/profile-common`, target script | `home/scripts/<script>` | `just shell-check && just wallpaper-script-check` |
| Change lid-close / Stasis stay-awake | `home/scripts/lid-close-action`, `home/rupan/laptop.nix` | same | `just lid-close-check && just shell-check` |
| Change Quickshell UI | `home/configs/quickshell*/`, profile bar references | QML/config files under `home/configs/quickshell*/` | `just qml-lint && just eval laptop` |
| Add a local package | `pkgs/`, `overlays/local-packages.nix` | `pkgs/<name>/default.nix`, overlay export | `nix build .#nixosConfigurations.laptop.pkgs.<name>` (stage new files first) |
| Change overlays | `overlays/default.nix`, target overlay file | `overlays/<name>.nix` | `nix build` the overlayed package attr, or `just eval laptop` if eval is enough |
| Update flake inputs | `flake.nix`, `flake.lock` | `flake.lock` via `just update` | `just check` |
| Change ISO behavior | `hosts/iso/configuration.nix`, `home/rupan/iso.nix` | ISO host or ISO home config | `just eval iso && just build-iso` |
| Change VM boot testing (`just vm`) | `justfile`, `virtualisation.vmVariant` in `hosts/laptop/base.nix` | vmVariant block, `vm`/`vm-iso` recipes | `just eval-vm` (vmVariant is not covered by `just eval`) |
| Change LUKS reinstall prep | `docs/luks-reinstall.md`, `hosts/laptop-crypt/`, `hosts/laptop/disko.nix` | disko layout, crypt host, runbook | `just eval laptop-crypt` + build `vmWithDisko` for layout changes |
| Change Obsidian vault fonts/CSS | `modules/home-manager/obsidian.nix`, `home/configs/obsidian/` | snippet CSS, custom-font-loader JSON, activation merge in module + `profile-common` / `iris-render.py` | `just fmt-check && just eval laptop` |
| Change agent tooling | `modules/home-manager/ai-tools.nix`, agent docs | agent module, `CLAUDE.md`, `AGENT_MAP.md` | `just check-agent-docs && just eval laptop` |
| Change agent hooks | `hooks/`, `.cursor/hooks.json`, `.claude/settings.json`, `.codex/hooks.json` | shared `hooks/` scripts only; keep the three configs pointing at the same commands | `just check-agent-workflows && just shell-check` |
| Change agent invariants or scaffolds | `checks/agent-invariants.bash`, `checks/agent-workflows.bash`, `home/scripts/new-*module` | invariant checker, workflow test, scaffold scripts | `just check-agent-workflows && just shell-check` |
| Change agent self-improvement behavior | `docs/agent-self-improvement.md`, `AGENT_MAP.md`, `checks/agent-*.bash` | protocol doc, agent checks, helper scripts | `just check-agent-docs && just check-agent-workflows` |

## Edit Rules

- New NixOS modules go in `modules/nixos/` and are auto-discovered by `import-tree`.
- New home-manager modules go in `modules/home-manager/` and are auto-discovered by `import-tree`.
- Use `lib.mkEnableOption` plus `lib.mkIf config.<option>.enable` for module toggles.
- New modules get a kebab-case file name and an option name matching that file name, as the `new-nixos-module` / `new-home-module` scaffolds emit; existing camelCase option names are grandfathered and must not be renamed.
- Use `config.repoPath` for repo-relative paths that must point outside the Nix store.
- Do not add manual imports for files under auto-discovered module trees.
- Do not add `nix.gc` or `system.autoUpgrade`; cleanup and updates are already handled by repo modules.
- Prefer existing helpers in `lib/desktop-profiles/` before adding profile-specific generated file logic.
- Keep generated or mutable desktop config under `home/configs/` or `home/scripts/`, not inline in unrelated modules.
- The Quickshell bar is launched from `home/configs/quickshell/shell.qml` by `profile-transition` and `toggle-bar`; it has no `xdg.configFile` or `home.file` entry and is not in `sync_live_config`.
- Do not use `git add .` / `git add -A` / `git add --all`; `hooks/before-shell` denies those. Stage the specific files changed (`hooks/after-edit` already stages newly created files).
- This flake only sees git-tracked files. New `pkgs/` or overlay paths created in the shell (`cp`, `diff`) skip `hooks/after-edit`; `git add <path>` before `nix build` / `just eval` or Nix errors with "is not tracked by Git".
- `git diff` renders through difftastic here; `hooks/before-shell` injects `--no-ext-diff` after the `diff` subcommand on agent `git diff`, and leaves every other git subcommand alone. Pass it yourself for a real unified patch outside the agent (`git apply`, hunk staging, or any machine parsing). Position matters: `git diff --no-ext-diff`, never `git --no-ext-diff diff` (git rejects it as a global option).
- Use `new-nixos-module <name>` and `new-home-module <name>` for new auto-discovered modules.
- Repo agent hooks live in `hooks/` and are wired from `.cursor/hooks.json`, `.claude/settings.json`, and `.codex/hooks.json`. Do not fork per-agent copies of the scripts. SessionStart injects `just agent-context`; do not run that recipe first.

## Validation

Run the smallest command that proves the touched surface; the "Validate" column above is the per-task minimum. Run `just check` before larger handoffs.

- `just quick` - fast default for low-risk Nix edits: laptop eval plus whitespace.
- `just check` - broad local gate: agent checks, laptop-safety, local-bin, flake-update, fmt, shell/wallpaper/xhisper, qml-lint, quickshell-test, flake check, host evals, profiles, whitespace. Superset of CI. Local-only: `just eval-all` and `just check-laptop-safety` (full host evals), `just check-flake-update` (update/pin script tests), `just check-local-bin` (inspects live `~/.local/bin` and user systemd `*.service.d` drop-ins for hardcoded `/nix/store` paths), and `just quickshell-test` (needs host `quickshell` plus a Wayland display).
- `just build <host>` - realizes the closure and catches build failures eval misses. Use for package, overlay, or flake-input changes.
- `just dry` / `just switch` - activation and final apply for laptop changes; intentional, they touch system state.
- Escalate a task's minimum to `just check` when the change is risky, then `just build <host>` if it affects realized packages or services.

## Session Closeout

Run `agent-self-improve --check` when a session hits durable friction (unexplained validation failures, unclear ownership, missing or weak docs/checks, time hunting conventions), not as a per-session ritual (`home/scripts/agent-self-improve --check` if `~/.local/bin` is off PATH). Shared `hooks/` Stop hooks (Cursor, Claude, Codex) surface failed `just`/`nix` runs as a nudge. If friction appeared, fix the smallest relevant doc, check, script, or `just` recipe; a clean session needs no note. Full protocol: `docs/agent-self-improvement.md`.

## Search Shortcuts

| Need | Command |
| --- | --- |
| Find an option owner | `rg -n "options\\..*<name>|<name>\\.enable" modules hosts home` |
| Find package placement | `rg -n "<package>|pkgs-stable|home.packages|environment.systemPackages" modules hosts home overlays pkgs` |
| Find profile fields | `rg -n "desktopProfiles\\.profiles|wallpaperDir|quickshellTheme" modules/home-manager/profiles lib/desktop-profiles` |
| Find runtime script callers | `rg -n "<script-name>|\\.local/bin|home/scripts" home modules` |
