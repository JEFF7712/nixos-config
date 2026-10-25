# CLAUDE.md

Guidance for Claude Code working in this repo.

## What This Is

NixOS flake-based system config for multiple hosts (`laptop`, `iso`, `agent-rupan`) with home-manager. Lives at `~/nixos`, single source of truth for system + user config. State version `25.11`.

## Commands

Recipes live in the `justfile` (`just` to list). Prefer them:

```bash
just switch        # build + switch through nh (resolved store path, root bypass)
just dry           # dry-activate laptop config (resolved nixos-rebuild)
just check-changed # checks selected from staged, unstaged, and untracked files; optional Git base argument
just check         # full validation: agent docs/workflows + local-bin + flake-update + fmt-check + shell/lid-close/wallpaper + qml-lint + quickshell-test + flake check (host evals + laptop-safety) + check-profiles + git diff --check
just fmt-check     # nix fmt --fail-on-change (mirrors CI; fails if anything is unformatted)
just quick         # laptop eval (~50s, skipped when no eval-relevant change) + git diff --check
just eval [target] # eval a host's toplevel drvPath (default laptop)
just build [target]# realize a host's toplevel closure (default laptop) — catches build failures eval misses
just build-iso     # build the live ISO
just fmt           # nix fmt — runs nixfmt + statix + deadnix (treefmt-nix)
just qml-lint      # qmllint for quickshell QML, with unresolved Quickshell/qmltypes noise disabled
just update        # nix flake update

nix develop ./shells[#c|#python|#cbe|#ml|#homelab]   # dev shells (ml default; separate shells/flake.nix)
```

## Agent Workflow

Before broad repo search, read `AGENT_MAP.md` (routing, edit rules, validation, closeout). SessionStart injects `just agent-context` via `hooks/session-start`. `hooks/before-shell` denies shotgun `git add`, rewrites `git diff` to `--no-ext-diff`, and denies raw activation; `hooks/before-mcp` denies nix-agent `switch()`. Activate only with `just switch`. Run `just check-changed` before handoff.

Commit history here is disposable: when asked to commit, commit freely (batching unrelated changes is fine). Relaxes the global commit rules for this repo only.

## Architecture

`flake.nix` defines `laptop` (full: NVIDIA, gaming, heavy apps, VPN, stasis, LUKS2 plus btrfs plus impermanence via `disko.nix`), `iso` (lighter live image, auto-clones repo on boot), and `agent-rupan` (headless development VM, `developer` user) via a `mkSystem` helper, using `flake-parts`. Each host has `hosts/<name>/configuration.nix` plus a home config under `home/rupan/`; the VM uses `agent-vm.nix` and shares the laptop's pinned CLI tools through `ai-tools.nix` with `ai-tools.desktop = false`. See `docs/agent-vm.md` for VM deployment. `laptop` also has `hardware-configuration.nix`, `base.nix` (nearly all config), `disko.nix`, and generated `resume-offset.nix`; `iso` has no `hardware-configuration.nix`.

**Modules** live in `modules/nixos/` (system) and `modules/home-manager/` (user). Most use the `lib.mkEnableOption` / `lib.mkIf config.<name>.enable` pattern, toggled per-host; profile modules in `modules/home-manager/profiles/` declare no options (they populate `desktopProfiles.profiles.<name>`). **Auto-discovered via `import-tree`**: dropping a new `.nix` file in either dir is enough to register it. Read the dir to see what exists; each module's option name matches its purpose.

**Desktop profiles** (`modules/home-manager/profiles/`): runtime theme switching without rebuild. `noctalia` (default, Material Design 3 via matugen) plus static schemes (`nord`, `catppuccin`, `gruvbox`, `rosepine`, `everforest`, `clean`, `sharp`) and wallpaper-driven `tinted` (opaque, palette regenerated from the current wallpaper) with dark/light variants. Each profile sets colors (GTK/Qt/kitty/fish/starship/rofi), cursor, wallpapers, niri visuals. Wallpaper theming picks an engine per profile via `colorEngine`, one of matugen (default), iris (used by `tinted`) or temperature. Managed at runtime by `home/scripts/`: `switch-profile <name>`, `toggle-variant`, `rofi-profile`. The active profile and variant are plain files holding a name: `.config/desktop-profiles/{active,active-variant}`.

**Out-of-store symlinks** (`mkOutOfStoreSymlink`), so **edits take effect without rebuild**:
- `home/configs/` → real KDL/CSS/TOML/conf files in the home dir.
- `home/scripts/` → `~/.local/bin/` (laptop only; iso uses a recursive store copy). Scripts resolve `repoPath` back via `readlink -f`.

The `repoPath` option (default `$HOME/nixos`) drives these paths — keep it consistent.

## Gotchas

- Activation, sudo, deploys, GC, and publication: read `docs/deployment.md` first. Short version: `just switch` is the only activation path (flock against auto-update OOM, cascade guard, comin pause); only exact-ref `nixos-rebuild`/`nh` sudo is passwordless and agents have no interactive sudo; comin replaces commits that exist only locally; no `nix.gc`/`system.autoUpgrade`.
- `just eval` takes about 50s (toplevel `drvPath` is never eval-cached, and this Nix has no parallel eval). `just quick` and `just check-changed` skip it when no changed file can affect evaluation (docs, QML, most `home/scripts/`); run them once per batch of edits.
- home-manager uses `backupFileExtension = "backup"`: activation renames conflicting existing files to `*.backup` instead of failing.
- Some packages pull from `nixpkgs-stable` (26.05): grep `pkgs-stable` before adding similar ones.
- Overlays live in `overlays/` (imported by `flake.nix`): `local-packages`, `nix-vscode-extensions`, `orca-slicer`.
- Quickshell bar work lives in `home/configs/quickshell*/`. `nix fmt` includes `qmlformat`; use `just qml-lint` for agent/manual checks. It intentionally disables unresolved import/type/property categories until Quickshell qmltypes/import metadata is wired up.
- GPU: Intel iGPU + NVIDIA Prime offload, with a `performance` specialisation for sync mode (`modules/nixos/nvidia.nix`).
- For NixOS/nixpkgs questions use the `mcp-nixos` MCP tools; training data lags nixpkgs.
- Agent PDF reads need `pdftoppm` from `poppler-utils` and `file` for MIME checks. Ad-hoc: `nix-shell -p poppler-utils file`; permanent: `ai-tools.enable` includes both.
- `.gitignore` excludes local tool state (`.claude`, `.codex`, `.pi`, `.superpowers`, `.venv`, `.worktrees`, build artifacts); `.muse/worktrees/` is in `.git/info/exclude`. `.mcp.json` is tracked (`nix-agent` + `mcp-nixos`). The activation pin is `programs.nix-agent.flake` on the wrapped binary; `.mcp.json` also sets `NIX_AGENT_FLAKE` but the wrapper `--set` wins.
