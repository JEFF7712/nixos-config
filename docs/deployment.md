# Deployment, Activation, and Updates

Detail behind the short Gotchas in `CLAUDE.md`. Read this before touching `just switch`, sudoers, comin, auto-update, or publication.

## Activation (`just switch`)

- `just switch` runs `nh os switch -R . -H laptop -- --max-jobs 2 --cores 8` through the resolved `nh` store path so the `nh` UI is preserved while sudoers stays pinned to that exact command (root ignores `~/.config/nix/nix.conf`).
- It is the only activation path for agents: `hooks/before-shell` denies `nixos-rebuild switch|boot|test` and `nh os switch|boot|test`, and `hooks/before-mcp` denies nix-agent `switch()`, because only `just switch` does the three steps below.
  1. Takes the `flock` on `/run/nixos-auto-update.lock` shared with the auto-update service, so two full builds never run concurrently (two at once OOM the ~31G box). If auto-update holds it, `just switch` bails with a hint; if a manual switch holds it, auto-update skips that run. To preempt a mid-build auto-update: `sudo systemctl stop nixos-auto-update.service`, then rerun.
  2. Runs the cascade guard (below).
  3. Pauses comin (below) so the next deploy does not replace the local switch.
- Passwordless `nixos-rebuild switch`/`test`/`dry-activate` is pinned to exact flake refs: `/home/rupan/nixos`, `/home/rupan/nixos#laptop`, or `path:/home/rupan/nixos#laptop` (from the repo root); any other ref prompts for a password. The same rules cover nix-agent's `sudo -n` argv. `programs.nix-agent.privilegedAutomation` stays off: its `--flake /home/rupan/nixos*` glob is looser (fnmatch `*` matches `/` and `#`). Rollback, `nix-env --switch-generation`, and the profile `switch-to-configuration` are also NOPASSWD.
- Agents have no interactive sudo, and `! sudo ...` also fails (no TTY for the password prompt): any non-pinned `sudo` is unusable in-session. Read root-only paths another way (many secrets are owned by rupan) or ask the user to run the command in a real terminal and paste the output.

## Cascade guard

`home/scripts/nix-cascade-guard`: a fresh nixpkgs tip (unstable right after a staging-next merge) evals fine but its binaries may not be cached yet, so a switch rebuilds stdenv/glibc and everything downstream from source (3000+ derivations, hours). `nix eval` cannot see this; a `--dry-run` reports the build count. A normal switch here is about 150 (config delta plus unfree CUDA overlay packages, which never hit the public cache); the default threshold is 800.

- The auto-update service runs it after the eval gate and, on cascade (exit 10), reverts `flake.lock` and defers to the next run.
- `just switch` / `njs` run it too: in a terminal they offer to pin nixpkgs back to the running revision (y/n) and continue; non-interactive runs refuse with a hint. Override with `FORCE=1 just switch`.
- Manual pin: `nix flake lock --override-input nixpkgs github:nixos/nixpkgs/<cached-rev>` (the running system's rev is in `nixos-version --json`).

## GC, upgrades, and resource caps

- `nh clean` runs daily (`--keep-since 7d --keep 3`); upgrades come from comin. There is no `nix.gc` or `system.autoUpgrade`, and the old local `auto-update` module is disabled.
- Laptop Nix builds are capped for the i9-13900H / ~31G (`max-jobs = 2`, `cores = 8`). The weekly auto-update skips rebuild when `flake.lock` is unchanged.
- `hosts/laptop/base.nix` opts the system and user slices into systemd-oomd (stock NixOS monitors nothing), so a runaway build is killed on swap/pressure instead of thrashing.

## comin

`modules/nixos/comin-deploy.nix` follows `deploy/laptop` on Forgejo, which homelab CI fast-forwards only after publishing that commit's closure to Attic (weekly `nixos-lock-update` PR, nightly `nixos-deploy`; see homelab `docs/runbooks/nixos-publication.md`).

- comin runs with `max-jobs = 0`, so a path missing from the cache fails the deploy and keeps the running system. It authenticates with the host SSH key as a read-only deploy key.
- Forgejo `main` is truth: commits that only exist locally are replaced at the next deploy.
- `just switch` pauses comin (`nixos-deploy pause|resume|status`, polkit-allowed). Resuming does not revert; it switches at the next new `deploy/laptop` commit.
- Out-of-store links in `home/` still follow the local checkout.

## Landing changes on protected main

`main` on Forgejo is protected: every change lands through a pull request.
Direct pushes to `main` are rejected. The delivery path is:

```sh
just ship
```

It runs preflight (refuses `main`, a dirty tree, or a branch with nothing beyond `origin/main`), `just check-changed origin/main`, pushes the branch, opens (or reuses) the PR, waits for the `ci/woodpecker/application-validation` status to go green, re-verifies the PR still targets `main` from the same branch and SHA, merges, syncs local `main`, and deletes the branch locally and on `origin`. Flags: `--no-checks`, `--no-merge` (stop once the PR is green), `--timeout-mins N` (default 45), `--title TEXT` (default: single-commit subject, else branch name). History uses merge commits (`Merge pull request '...' (#N) from <branch> into main`).

Prerequisites: `tea` on PATH with an `nixos-agent` login that can write `JEFF7712/nixos-config` (one-time human setup in the Forgejo UI, same pattern as homelab's agent access: machine user, token, `tea login add --url http://git.internal:3000`). This machine also carries the `homelab-agent` login on the same URL and tea always uses the default, so `ship` derives `~/.config/tea-nixos` (same logins, `nixos-agent` as default) from the main tea config on each run and points tea at it; the machine default is left alone for homelab flows. After rotating the token, re-run `tea login add`; the scoped copy regenerates automatically. `ship` fails closed without a usable login.

Manual fallback (no `tea`, or a PR needing a human in the UI):

1. Start from current main: `git checkout main && git pull --ff-only && git checkout -b <type>/<short-name>` (`feat/`, `fix/`, `chore/`, `style/`, matching existing history). Keep local `main` clean and tracking `origin/main`.
2. Edit, then validate: `just check-changed` (or `just check-changed origin/main` once the branch has commits), escalating to `just quick` / `just check` per `AGENT_MAP.md`. Stage specific files only, never `git add .`.
3. Push the branch: `git push -u origin <type>/<short-name>`. Pushing alone publishes nothing (see below).
4. Open a pull request in Forgejo (`https://git.internal/JEFF7712/nixos-config`), from the branch into `main`. Woodpecker validates every push and PR; GitHub checks are mirror-only.
5. After green validation, merge via the Forgejo UI. Agents: ad-hoc pushes, PRs, and merges outside `just ship` need user confirmation first; local commits do not.
6. Sync back: `git checkout main && git pull --ff-only`, optionally deleting the feature branch locally and remotely.

Merging to `main` does not switch the running system. Either wait for comin to follow `deploy/laptop` once homelab CI publishes that commit's closure to Attic, or apply immediately with `just switch` after syncing. Commits that exist only locally are replaced at the next deploy, so land the PR before switching to it.

## CI and publication

- Forgejo `JEFF7712/nixos-config` is source authority. Server-owned Woodpecker validation checks every push and PR in a retained local image. GitHub `check.yml` supplies optional mirror checks on disposable runners and has no artifact publishing authority.
- The protected `nixos-publish` operation in Forgejo `JEFF7712/homelab` resolves and verifies this repository's main tip, then builds and publishes laptop and installer ISO artifacts to local Attic. It is manually triggered from successful validation of current homelab main; pushing this repository alone publishes nothing. No host activation or USB flashing is part of publication. See `docs/sovereign-publication.md`.
