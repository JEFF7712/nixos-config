# Profile Transaction and Update Pipeline Design

## Scope

This change deepens two existing modules without changing their user-facing behavior:

1. Desktop profile and variant transitions gain one transactional orchestration path with rollback for core desktop state.
2. Weekly and AI-tool flake updates share one standalone, testable update pipeline.

Application-specific theme integrations remain best-effort. Update schedules remain weekly for the full flake and hourly for AI-tool inputs.

## Desktop Profile Transaction

### Interface

One `profile-transition` command owns all core transitions:

- Switch to a named profile, restoring that profile's last variant.
- Switch the active profile to an explicit `dark` or `light` variant.
- Toggle the active profile's variant.
- Reapply current state.
- Reapply startup state.

The existing `switch-profile` and `toggle-variant` commands remain user-facing entry points, but delegate to this interface. Existing callers do not need to change.

### Ownership

The transition module owns:

- Target resolution and validation.
- Per-user transition locking.
- Core-state snapshots.
- Generated-file staging and installation.
- Niri override selection and reload.
- Bar shutdown, configuration, startup, and verification.
- Active profile and variant persistence.
- Rollback before commit.
- Post-commit dispatch of best-effort application adapters.

`profile-common` retains integration adapters for wallpaper engines, GTK, Kitty, Firefox, Vicinae, Zed, Vesktop, Obsidian, Spotify, notification daemons, and similar external programs. It no longer determines the overall transition order.

### Transaction State Flow

1. Resolve and validate the target profile and variant.
2. Acquire an exclusive per-user `flock` without waiting indefinitely.
3. Snapshot the previous active profile, variant, Niri override, bar identity, and every live generated file that the transition may replace.
4. Stage target generated files in the destination filesystem.
5. Stop the old bar and its associated notification process where required.
6. Atomically install the staged files and Niri override.
7. Reload Niri and require a successful command result.
8. Start the target bar and verify its process or user unit is active.
9. Atomically commit the active profile, active variant, and per-profile variant preference.
10. Disable rollback and release the lock.
11. Launch wallpaper work and application-specific theme adapters as best-effort post-commit work.

Startup reapply uses the same transaction but preserves the current preference files unless recovery requires correcting an invalid profile.

### Core State

Rollback covers only state controlled directly by the transition:

- Active profile file.
- Active variant file.
- Per-profile variant preference file when changed.
- Active Niri override symlink and any transition-generated runtime override.
- Target bar process or user unit.
- Waybar and Mako generated configuration.
- Live color, font, appearance, and cursor files installed by the core transition.

Wallpaper selection and application-specific themes are post-commit adapters. Their failure is logged and reported but does not roll back a successful core transition.

### Failure Semantics

Any failure before commit triggers a trap that restores the snapshot in reverse order, reloads Niri, and restarts the previous bar. Rollback attempts every restoration step even when one step fails, records each failure, and exits nonzero with the original failure plus rollback diagnostics.

Lock contention exits nonzero with a concise message naming the active transition lock. It does not wait and does not alter state.

The transaction commits only after Niri reload succeeds and the target bar passes verification:

- Noctalia: its user unit is active.
- Waybar: a matching process exists.
- Quickshell: the configured topbar process exists.

### Adapter Behavior

Post-commit adapters run asynchronously where they already do so. Each adapter failure is isolated from the others and reported without changing the committed profile state. The refactor preserves the existing self-themed, wallpaper-themed, startup, focus-mode, and bar-specific behavior.

## Standalone Flake Update Pipeline

### Interface

A packaged `nixos-flake-update` command accepts declarative job metadata:

- Job label.
- Zero or more flake input names.
- Commit message.
- Repository path and target flake reference, with the current repo and laptop target supplied by the Nix module.

No input names means a full `nix flake update`. Named inputs restrict the update to those inputs.

### Ownership

The script owns:

- The shared rebuild lock.
- DNS readiness retry.
- Flake lock update as `rupan`.
- Laptop evaluation before commit.
- Unchanged-lock detection.
- Cascade-guard execution.
- Lockfile restoration on pre-commit failure or deferral.
- Intentional lockfile commit.
- Laptop rebuild and switch.
- Consistent status and error reporting.

The Nix module owns packaging, runtime dependencies, systemd resource controls, schedules, and job-specific arguments.

### Update Flow

1. Acquire `/run/nixos-auto-update.lock` without waiting.
2. Wait for DNS readiness using the existing bounded retry policy.
3. Snapshot `flake.lock` and run the requested update as `rupan`.
4. Evaluate the laptop system.
5. Exit successfully without rebuilding if the lock is unchanged.
6. Run `nix-cascade-guard`.
7. Restore the lock and exit successfully when the guard requests deferral.
8. Restore the lock and fail for evaluation or cascade-guard errors.
9. Commit only `flake.lock` with the configured message.
10. Rebuild and switch the laptop using the existing job and core limits.

A rebuild failure occurs after the lockfile commit and is not automatically reverted. This preserves the current audit trail and avoids rewriting Git history after a valid evaluated update. The systemd job fails visibly so the existing health notifier reports it.

### Jobs

- `nixos-auto-update`: weekly, all inputs, commit message `flake.lock: weekly auto-update`.
- `nixos-ai-tools-auto-update`: hourly, inputs `claude-code-nix`, `codex-cli-nix`, and `code-cursor-nix`, commit message `flake.lock: ai tools auto-update`.

Both retain `Persistent`, randomized delay, current CPU and memory controls, and the shared lock with manual `just switch`.

## Testing

### Profile Transaction Tests

Tests use a temporary home, fixture profile bundles, and command adapters placed first in `PATH`. They cover:

- Successful profile switch.
- Successful explicit and toggled variant switch.
- Startup and manual reapply.
- Invalid target and unsupported light variant.
- Lock contention.
- Failure during staging, Niri reload, and target bar startup.
- Restoration of files, symlinks, preference state, and previous bar.
- Rollback that encounters a secondary restoration failure.
- Post-commit application-adapter failure without core rollback.

### Update Pipeline Tests

Fixture commands and a temporary Git repository cover:

- Full and input-restricted update arguments.
- Lock contention.
- DNS timeout.
- Unchanged lockfile.
- Evaluation failure and restoration.
- Cascade deferral and restoration.
- Cascade error and restoration.
- Successful commit and rebuild invocation.
- Rebuild failure after commit.

### Regression Gates

The implementation must pass the new focused tests plus:

- `just shell-check`
- `just wallpaper-script-check`
- `just check-profiles`
- `just fmt-check`
- `just eval laptop`

## Migration Strategy

Implementation proceeds in two independently verifiable changes:

1. Add and test `nixos-flake-update`, then replace duplicated systemd script bodies with calls to it.
2. Add profile transaction tests and the centralized transition module, then reduce `switch-profile` and `toggle-variant` to delegating entry points while keeping existing application adapters intact.

No Python rewrite, profile-schema redesign, application-adapter rewrite, or host-role consolidation is included.
