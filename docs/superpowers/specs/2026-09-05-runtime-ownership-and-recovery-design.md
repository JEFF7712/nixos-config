# Runtime Ownership and Recovery Design

## Scope

This change addresses the eight findings from the 2026-09-05 architecture review and adds the missing CI coverage that supports them. It preserves `mkSystem`, the shared package set, automatic module discovery, Home Manager integration, and the desktop profile manifest compiler. Policy is extracted from `hosts/laptop/base.nix` only where an implementation below produces a cohesive owner.

## Update convergence

The flake updater will represent candidate creation, pending activation, and successful deployment as separate states. Updating inputs creates an immutable candidate and durable pending record before any activation attempt. A successful activation records the deployed candidate and clears pending state. A failed activation leaves pending state intact, so a later run retries it even when refreshing inputs produces no lock-file change.

Candidate evaluation and activation must use a snapshot whose contents cannot change when the editable checkout changes. Existing cascade, evaluation, locking, and rollback behavior remains, but tests will stop treating commit-before-rebuild as success. Tests must cover a failed activation followed by an unchanged refresh, successful retry cleanup, and checkout edits during candidate processing.

## Theme publication

Profile transitions and wallpaper-driven jobs will render slow artifacts outside the publication lock. They will write complete results into generation-specific staging locations. One publication interface will acquire the lock, compare the staged generation with the current desired generation, and atomically install all applicable theme outputs only when it is still current.

Application adapters will publish through this interface rather than writing visible files after the transition lock is released. Stale generations become harmless discarded work. Tests will force adversarial ordering where an older render finishes after a newer transition and verify that all live files belong to the newest generation.

## Build resource policy

Client service limits remain as protection for updater orchestration. A separate policy will constrain or deprioritize the daemon-owned build workload, using systemd controls that apply to the actual Nix daemon and its builders. The initial policy will favor desktop responsiveness through CPU and I/O weights and set memory controls only with enough headroom for ordinary multi-job builds. It must account for both daemon-mediated user builds and automatic update builds.

Static tests will verify the unit configuration. Live validation will inspect cgroup placement and effective properties during manual and automatic builds when practical. Any behavior that needs sustained production-shaped load will be identified separately from configuration validation.

## NVIDIA container discovery

The NVIDIA CDI generator will no longer hold the graphical boot target behind global device settlement. CDI readiness will be attached to GPU-container consumption or narrowed to the relevant NVIDIA device readiness while retaining correct first-use behavior for rootless Docker and Podman.

Static dependency checks and host evaluation will verify boot ordering. A cold reboot and real GPU container runs are required to measure boot savings and confirm runtime behavior; these are live acceptance checks rather than claims made from evaluation alone.

## Quickshell supervision

A Home Manager systemd user service will own the repository Quickshell bar process, journal output, restart-on-crash behavior, and readiness. `profile-transition` and `toggle-bar` will call that service instead of launching or killing detached processes. The existing intentional hidden state will map to an intentional stopped or disabled runtime state that does not trigger a restart loop.

Tests will cover start, restart after failure, intentional stop, toggle behavior, and notification ownership. The theme-publication change lands first because both changes touch profile transition behavior.

## Dry activation

The desktop-profile activation block will guard `sync-kitty-agent-colors` with Home Manager's dry-run contract in the same way as adjacent mutating steps. A test using a temporary home will compare relevant Kitty, OpenCode, and state paths before and after dry activation and require no changes.

## Quickshell metrics

System metrics will retain the previous CPU counters in the model and calculate utilization from consecutive polling intervals. The polling command will no longer sleep for a second sample. Memory can remain on the normal interval, while disk usage moves to a slower timer or refreshes when its detailed UI is opened. Parser and model tests will cover initialization, counter deltas, counter resets, and the reduced disk cadence.

## Old-root pruning

Initrd logic will keep only the operations required to rename the previous root and create the fresh root snapshot. Recursive retention pruning will move to a post-boot systemd service and timer with explicit overlap protection. Cleanup failure must not prevent boot.

Tests will cover nested subvolume deletion, retention cutoff behavior, concurrent invocation protection, and configuration ordering. Space-pressure implications will be documented in the unit behavior rather than hidden in initrd.

## Validation and delivery

Dedicated update-pipeline and laptop-safety checks will run in CI or as flake checks alongside the existing suite. Each scoped change receives implementation, specification, and code-quality review. After integration, run `just check-changed`, then the broad `just check`; run `just build laptop` because system services and boot behavior change. Apply live service changes where safe, inspect resulting user and system units, and distinguish these checks from reboot, battery, and GPU-container validation that cannot be inferred from a build.
