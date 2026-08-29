# CLAUDE.md

Guidance for Claude Code working in this repo.

## What This Is

NixOS flake-based system config for multiple hosts (`laptop`, `laptop-crypt`, `iso`) with home-manager. Lives at `~/nixos`, single source of truth for system + user config. State version `25.11`.

## Commands

Recipes live in the `justfile` (`just` to list). Prefer them:

```bash
just switch        # build + switch through nh (resolved store path, root bypass)
just dry           # dry-activate laptop config (resolved nixos-rebuild)
just check-changed # checks selected from staged, unstaged, and untracked files; optional Git base argument
just check         # full validation: agent docs/workflows + laptop-safety + local-bin + flake-update + fmt-check + shell/lid-close/wallpaper/xhisper + qml-lint + quickshell-test + flake check + eval-all + check-profiles + git diff --check
just fmt-check     # nix fmt --fail-on-change (mirrors CI; fails if anything is unformatted)
just quick         # fast pre-commit: eval laptop + git diff --check
just eval [target] # eval a host's toplevel drvPath (default laptop)
just build [target]# realize a host's toplevel closure (default laptop) — catches build failures eval misses
just build-iso     # build the live ISO
just fmt           # nix fmt — runs nixfmt + statix + deadnix (treefmt-nix)
just qml-lint      # qmllint for quickshell QML, with unresolved Quickshell/qmltypes noise disabled
just update        # nix flake update

nix develop ./shells[#c|#python|#cbe|#ml|#homelab]   # dev shells (ml default; separate shells/flake.nix)
```

## Agent Workflow

Before broad repo search, read `AGENT_MAP.md`. SessionStart injects `just agent-context` via `hooks/session-start`.

Run `agent-self-improve --check` when a session hits durable friction (validation you could not immediately explain, unclear ownership, missing or weak docs/checks, time spent hunting conventions), not as a per-session ritual (`home/scripts/agent-self-improve --check` if `~/.local/bin` is not on PATH). Shared repo hooks in `hooks/` (wired from `.cursor/hooks.json`, `.claude/settings.json`, and `.codex/hooks.json`) inject session context, rewrite agent `git diff` to `--no-ext-diff` and deny shotgun `git add` (`hooks/before-shell`), format/parse-check/stage new files after edits, and surface failed `just`/`nix` runs on Stop. If friction appeared, fix the smallest relevant agent-facing doc, check, script, or `just` recipe; a clean session needs no closeout note.

Commit history here is disposable — when asked to commit, commit freely (batching unrelated changes is fine); don't fuss over one-logical-change discipline. Relaxes the global commit rules for this repo only.

## Architecture

`flake.nix` defines `laptop` (full: NVIDIA, gaming, heavy apps, VPN, stasis), `laptop-crypt` (post-LUKS-reinstall variant of laptop: disko plus btrfs plus impermanence), and `iso` (lighter live image, auto-clones repo on boot) via a `mkSystem` helper, using `flake-parts`. Each host has `hosts/<name>/configuration.nix` plus home config `home/rupan/<name>.nix` (base: `home/rupan/home.nix`); `laptop` also has `hardware-configuration.nix`, `base.nix` (nearly all config, shared with `laptop-crypt`), and `disko.nix`; `iso` has no `hardware-configuration.nix`.

**Modules** live in `modules/nixos/` (system) and `modules/home-manager/` (user). Most use the `lib.mkEnableOption` / `lib.mkIf config.<name>.enable` pattern, toggled per-host; profile modules in `modules/home-manager/profiles/` declare no options (they populate `desktopProfiles.profiles.<name>`). **Auto-discovered via `import-tree`**: dropping a new `.nix` file in either dir is enough to register it. Read the dir to see what exists; each module's option name matches its purpose.

**Desktop profiles** (`modules/home-manager/profiles/`): runtime theme switching without rebuild. `noctalia` (default, Material Design 3 via matugen) plus static schemes (`nord`, `catppuccin`, `gruvbox`, `rosepine`, `everforest`, `clean`, `sharp`) and wallpaper-driven `tinted` (opaque, palette regenerated from the current wallpaper) with dark/light variants. Each profile sets colors (GTK/Qt/kitty/fish/starship/rofi), cursor, wallpapers, niri visuals. Wallpaper theming picks an engine per profile via `colorEngine`, one of matugen (default), iris (used by `tinted`) or temperature. Managed at runtime by `home/scripts/`: `switch-profile <name>`, `toggle-variant`, `rofi-profile`. The active profile and variant are plain files holding a name: `.config/desktop-profiles/{active,active-variant}`.

**Out-of-store symlinks** (`mkOutOfStoreSymlink`), so **edits take effect without rebuild**:
- `home/configs/` → real KDL/CSS/TOML/conf files in the home dir.
- `home/scripts/` → `~/.local/bin/` (laptop only; iso uses a recursive store copy). Scripts resolve `repoPath` back via `readlink -f`.

The `repoPath` option (default `$HOME/nixos`) drives these paths — keep it consistent.

## Gotchas

- `just switch` runs `nh os switch -R . -H laptop -- --max-jobs 2 --cores 8` through the resolved `nh` store path so the nice `nh` UI is preserved while sudoers stays pinned to that exact command (root ignores `~/.config/nix/nix.conf`). Passwordless `nixos-rebuild switch`/`test`/`dry-activate` is pinned to exact flake refs — `/home/rupan/nixos`, `/home/rupan/nixos#laptop`, or `path:/home/rupan/nixos#laptop` (from the repo root); any other ref prompts for a password. Those same exact rules cover nix-agent's `sudo -n` argv. `programs.nix-agent.privilegedAutomation` stays off: its `--flake /home/rupan/nixos*` glob is looser (fnmatch `*` matches `/` and `#`). Rollback, `nix-env --switch-generation`, and the profile `switch-to-configuration` are also NOPASSWD. Agents have no interactive sudo, and `! sudo ...` also fails (no TTY for the password prompt): any non-pinned `sudo` is unusable in-session. Read root-only paths another way (many secrets are owned by rupan) or ask the user to run the command in a real terminal and paste the output. `just switch` and both auto-update services share a `flock` on `/run/nixos-auto-update.lock` so two full builds never run concurrently (two at once OOM the ~31G box). If auto-update holds it, `just switch` bails with a hint; if a manual switch holds it, the hourly auto-update skips that run. To preempt a mid-build auto-update: `sudo systemctl stop nixos-ai-tools-auto-update.service nixos-auto-update.service`, then rerun.
- GC and upgrades are automatic: `nh clean` daily (`--keep-since 7d --keep 3`) and the custom `auto-update` module — no `nix.gc`/`system.autoUpgrade`. Laptop Nix builds are capped for the i9-13900H / ~31G (`max-jobs = 2`, `cores = 8`) so switches/auto-updates don't OOM the desktop; AI-tools auto-update is hourly, skips rebuild when `flake.lock` is unchanged, and soft-defers (exit 0 + lock revert) when an upstream AI flake fails eval — same idea as cascade-guard, so hourly timer noise stays quiet. `oom-protection.nix` opts the system+user slices into systemd-oomd (stock NixOS monitors nothing) so a runaway build is killed on swap/pressure instead of thrashing for hours.
- Cascade guard (`home/scripts/nix-cascade-guard`): a fresh nixpkgs tip (unstable right after a staging-next merge) evals fine but its binaries may not be cached yet, so a switch rebuilds stdenv/glibc + everything downstream from source — 3000+ derivations, hours. `nix eval` can't see this; a `--dry-run` reports the build count. Normal switch here ≈150 (config delta + unfree CUDA overlay pkgs, which never hit the public cache); cascade is 3000+, default threshold 800. Both `auto-update` services run it after the eval gate and, on cascade (exit 10), revert `flake.lock` and defer to the next run instead of grinding. `just switch` / `njs` run it too: in a terminal they offer to pin nixpkgs back to the running revision (y/n) and continue; non-interactive runs refuse with a hint. Override with `FORCE=1 just switch`. Manual pin: `nix flake lock --override-input nixpkgs github:nixos/nixpkgs/<cached-rev>` (the running system's rev is in `nixos-version --json`).
- home-manager uses `backupFileExtension = "backup"` — activation renames conflicting existing files to `*.backup` instead of failing.
- Some packages pull from `nixpkgs-stable` (25.11) — grep `pkgs-stable` before adding similar ones.
- Overlays live in `overlays/` (imported by `flake.nix`): `local-packages`, `ctranslate2-cuda`, `nix-vscode-extensions`.
- Quickshell bar work lives in `home/configs/quickshell*/`. `nix fmt` includes `qmlformat`; use `just qml-lint` for agent/manual checks. It intentionally disables unresolved import/type/property categories until Quickshell qmltypes/import metadata is wired up.
- GPU: Intel iGPU + NVIDIA Prime offload, with a `performance` specialisation for sync mode (`modules/nixos/nvidia.nix`).
- CI: `check.yml` on push/PR runs `nix flake check` + `nix fmt --fail-on-change`; `build-iso.yml` builds the ISO on `hosts/iso/**` or `home/rupan/iso.nix` changes, monthly, or on dispatch. It does not publish: GitHub caps release assets at 2 GiB and the ISO does not fit, so it is consumed locally via `just build-iso` + `writeUSB`. Its size check is an advisory tripwire (fails past 6 GiB), not a distribution limit.
- For NixOS/nixpkgs questions use the `mcp-nixos` MCP tools — training data lags nixpkgs.
- Agent PDF reads need `pdftoppm` from `poppler-utils`; without it, fetched PDFs may have valid bytes but Read/render tools cannot inspect them in-session. `file` is also expected for MIME/type checks. Ad-hoc: `nix-shell -p poppler-utils file`; permanent: `ai-tools.enable` includes both.
- `.gitignore` excludes local tool state (`.claude`, `.codex`, `.pi`, `.superpowers`, `.venv`, `.worktrees`, build artifacts). `.mcp.json` is tracked (`nix-agent` + `mcp-nixos`) and sets `NIX_AGENT_USAGE_LOG`. The activation pin is `programs.nix-agent.flake` on the wrapped binary; `.mcp.json` also sets `NIX_AGENT_FLAKE` but the wrapper `--set` wins.
