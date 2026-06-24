# CLAUDE.md

Guidance for Claude Code working in this repo.

## What This Is

NixOS flake-based system config for multiple hosts (`laptop`, `iso`) with home-manager. Lives at `~/nixos`, single source of truth for system + user config. State version `25.11`.

## Commands

Recipes live in the `justfile` (`just` to list). Prefer them:

```bash
just switch        # build + switch (nh os switch . -H laptop)
just dry           # dry-activate laptop config (sudo nixos-rebuild)
just check         # full validation: fmt-check + shell-check + wallpaper-scripts + flake check + eval laptop&iso + check-profiles + git diff --check
just fmt-check     # nix fmt --fail-on-change (mirrors CI; fails if anything is unformatted)
just quick         # fast pre-commit: eval laptop + git diff --check
just eval [target] # eval a host's toplevel drvPath (default laptop)
just build [target]# realize a host's toplevel closure (default laptop) — catches build failures eval misses
just build-iso     # build the live ISO
just fmt           # nix fmt — runs nixfmt + statix + deadnix (treefmt-nix)
just qml-lint      # qmllint for quickshell QML, with unresolved Quickshell/qmltypes noise disabled
just update        # nix flake update

nix develop ./shells[#python|#cbe|#ml|#homelab]   # dev shells (ml default; separate shells/flake.nix)
```

## Agent Workflow

Before broad repo search, read `AGENT_MAP.md` and run `just agent-context`.

At closeout for coding-agent sessions that changed files, investigated behavior, or made a recommendation in this repo, run `agent-self-improve --check` (`home/scripts/agent-self-improve --check` if `~/.local/bin` is not on PATH). If durable friction appeared, update the smallest relevant agent-facing doc, check, script, or `just` recipe; otherwise say the self-improvement check found nothing worth changing.

## Architecture

`flake.nix` defines `laptop` (full: NVIDIA, gaming, heavy apps, VPN, stasis) and `iso` (lighter live image, auto-clones repo on boot) via a `mkSystem` helper, using `flake-parts`. Each host = `hosts/<name>/{configuration,hardware-configuration}.nix` + home config `home/rupan/<name>.nix` (base: `home/rupan/home.nix`).

**Modules** live in `modules/nixos/` (system) and `modules/home-manager/` (user). All use the `lib.mkEnableOption` / `lib.mkIf config.<name>.enable` pattern, toggled per-host. **Auto-discovered via `import-tree`** — dropping a new `.nix` file in either dir is enough to register it. Read the dir to see what exists; each module's option name matches its purpose.

**Desktop profiles** (`modules/home-manager/profiles/`): runtime theme switching without rebuild. `noctalia` (default, Material Design 3 via matugen) plus static schemes (`nord`, `catppuccin`, `gruvbox`, `rosepine`, `everforest`, `clean`, `minimal`) with dark/light variants. Each profile sets colors (GTK/Qt/kitty/fish/starship/rofi), cursor, wallpapers, niri visuals. Managed at runtime by `home/scripts/`: `switch-profile <name>`, `toggle-variant`, `rofi-profile`. Active profile is the symlink `.config/desktop-profiles/active → <name>/`.

**Out-of-store symlinks** (`mkOutOfStoreSymlink`), so **edits take effect without rebuild**:
- `home/configs/` → real KDL/CSS/TOML/conf files in the home dir.
- `home/scripts/` → `~/.local/bin/` (laptop only; iso uses a recursive store copy). Scripts resolve `repoPath` back via `readlink -f`.

The `repoPath` option (default `$HOME/nixos`) drives these paths — keep it consistent.

## Gotchas

- **Rebuilds run through `nh`** (`nh os switch`); `just switch` runs `nh os switch . -H laptop`. Passwordless sudo is **pinned to exact flake refs** — `switch`/`test` only work for `.#laptop`, `/home/rupan/nixos#laptop`, or `path:/home/rupan/nixos#laptop` (from the repo root); any other ref prompts for a password. `dry-activate` is globbed (for nix-agent headless runs).
- GC and upgrades are automatic: `nh clean` daily (`--keep-since 7d --keep 3`) and the custom `auto-update` module — no `nix.gc`/`system.autoUpgrade`.
- home-manager uses `backupFileExtension = "backup"` — activation renames conflicting existing files to `*.backup` instead of failing.
- Some packages pull from `nixpkgs-stable` (25.11) — grep `pkgs-stable` before adding similar ones.
- Overlays live in `overlays/` (imported by `flake.nix`): `local-packages`, `ctranslate2-cuda`, `python-fixes`, `nix-vscode-extensions`.
- Quickshell bar work lives in `home/configs/quickshell*/`. `nix fmt` includes `qmlformat`; use `just qml-lint` for agent/manual checks. It intentionally disables unresolved import/type/property categories until Quickshell qmltypes/import metadata is wired up.
- GPU: Intel iGPU + NVIDIA Prime offload, with a `performance` specialisation for sync mode (`modules/nixos/nvidia.nix`).
- CI: `build-iso.yml` on `v*` tags; `check.yml` on push/PR runs `nix flake check` + `nix fmt --fail-on-change`.
- For NixOS/nixpkgs questions use the `mcp-nixos` MCP tools — training data lags nixpkgs.
- Agent PDF reads need `pdftoppm` from `poppler-utils`; without it, fetched PDFs may have valid bytes but Read/render tools cannot inspect them in-session. `file` is also expected for MIME/type checks. Ad-hoc: `nix-shell -p poppler-utils file`; permanent: `ai-tools.enable` includes both.
- `.gitignore` excludes `.mcp.json` and local tool state.
