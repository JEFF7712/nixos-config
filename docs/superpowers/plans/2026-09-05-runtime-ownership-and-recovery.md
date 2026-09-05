# Runtime Ownership and Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make update, theme, build, desktop-shell, GPU-container, metrics, and root-cleanup behavior converge under explicit runtime owners.

**Architecture:** Keep the existing flake and profile compiler boundaries. Introduce durable update state and immutable candidates, one generation-aware theme publication interface, systemd ownership for long-lived or scheduled work, and lower-cost Quickshell metric sampling. Validate each subsystem independently before a full host build and live unit inspection.

**Tech Stack:** Bash, NixOS modules, Home Manager, systemd, QML/JavaScript, Nix flake checks, shell fixture tests.

---

### Task 1: Convergent flake update state

**Files:**
- Modify: `home/scripts/nixos-flake-update`
- Modify: `checks/flake-update.bash`
- Modify: `modules/nixos/auto-update.nix`

- [ ] **Step 1: Write failing recovery and snapshot tests**

Add fixture cases that use a temporary `STATE_DIRECTORY` and assert: a failed rebuild leaves a pending candidate; a second run with an unchanged upstream lock activates the pending candidate; the successful run commits the candidate and removes pending state; and a checkout mutation after candidate creation does not change the flake reference passed to evaluation, cascade checking, or activation.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `just check-flake-update`

Expected: the new retry case reports that unchanged input skipped activation, and the immutable-reference assertion reports the editable repository path.

- [ ] **Step 3: Implement the candidate state machine**

Use `$STATE_DIRECTORY/pending-$safe_label` for durable metadata and a state-owned candidate directory. Copy the repository with Git semantics into a temporary candidate, update and evaluate its `flake.lock`, then atomically publish the candidate into the state directory. Persist enough metadata to retry activation after process restart. On each invocation, retry valid pending activation before treating an unchanged refresh as a no-op. Commit the candidate lock to the editable repository only after `nixos-rebuild switch` succeeds, then record successful deployment and clear pending state. Preserve pre-run dirty-lock restoration, defer accounting, cascade handling, signal cleanup, and the shared `flock`.

- [ ] **Step 4: Run focused and shell tests**

Run: `just check-flake-update && just shell-check`

Expected: all update cases pass and ShellCheck reports no new diagnostics.

- [ ] **Step 5: Commit**

Commit only the three task files with message `fix(update): retry pending flake activation`.

### Task 2: Generation-checked theme publication

**Files:**
- Create: `home/scripts/profile-publish`
- Modify: `home/scripts/profile-common`
- Modify: `home/scripts/profile-transition`
- Modify: `home/scripts/iris-render.py`
- Modify: `home/configs/matugen/config.toml`
- Modify: `home/configs/matugen/config-sharp.toml`
- Modify: `checks/profile-transition.bash`
- Modify: `checks/wallpaper-scripts.bash`

- [ ] **Step 1: Write failing interleaving tests**

Add fixtures that assign monotonic desired generations, stage complete artifact sets, deliberately finish generation A after generation B, and assert every live artifact remains from B. Cover both a normal profile transition and wallpaper-driven runtime theme generation. Assert slow renderer commands execute without holding the publication lock.

- [ ] **Step 2: Run the profile and wallpaper tests and verify failure**

Run: `just profile-transition-check && just wallpaper-script-check`

Expected: stale generation A overwrites at least one B artifact or no shared publish interface exists.

- [ ] **Step 3: Implement one publication interface**

Create `profile-publish` with operations to allocate/read the desired generation and publish a staged directory. Publishing must take the existing profile lock, compare the staged generation with the desired generation inside the lock, atomically replace declared live files, and reject stale work without error. Change transition adapters and wallpaper engines to render into generation-specific directories and call this interface. Keep renderer work outside the lock and preserve transition rollback semantics.

- [ ] **Step 4: Run focused profile validation**

Run: `just profile-transition-check && just wallpaper-script-check && just check-profiles && just shell-check`

Expected: adversarial tests pass, profile compilation passes, and shell validation is clean.

- [ ] **Step 5: Commit**

Commit the scoped files with message `refactor(profiles): serialize theme publication`.

### Task 3: Nix builder resource policy

**Files:**
- Create: `modules/nixos/build-resource-policy.nix`
- Modify: `hosts/laptop/base.nix`
- Modify: `checks/laptop-safety.bash`

- [ ] **Step 1: Write failing evaluated-policy assertions**

Extend the laptop safety check to evaluate `nix-daemon.service` and require explicit `CPUWeight`, `IOWeight`, `MemoryHigh`, `MemoryMax`, and `TasksMax`. Require `MemoryHigh` below `MemoryMax`, and preserve at least 6 GiB outside the daemon maximum on the 31 GiB host.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `just check-laptop-safety`

Expected: evaluated `nix-daemon.service` lacks the required controls.

- [ ] **Step 3: Add the cohesive policy module**

Create the auto-discovered `build-resource-policy` module with an enable option. Configure the daemon service with responsiveness-oriented CPU and I/O weights, `MemoryHigh = "22G"`, `MemoryMax = "25G"`, and an explicit task ceiling compatible with two builds and substitution workers. Enable it from the laptop host, leaving updater-client limits in `auto-update.nix`.

- [ ] **Step 4: Validate evaluation**

Run: `just check-laptop-safety && just fmt-check && just eval laptop`

Expected: policy assertions, formatting, and laptop evaluation pass.

- [ ] **Step 5: Commit**

Commit the three files with message `feat(nix): bound daemon build resources`.

### Task 4: Deferred NVIDIA CDI readiness

**Files:**
- Modify: `modules/nixos/nvidia.nix`
- Modify: `modules/nixos/docker.nix`
- Modify: `modules/nixos/podman.nix`
- Modify: `checks/laptop-safety.bash`

- [ ] **Step 1: Write failing boot-order assertions**

Add evaluated assertions that the CDI generator is not wanted by or ordered before `graphical.target`, does not run global `udevadm settle`, and is required before Docker or Podman GPU-consuming startup paths where the repository enables them.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `just check-laptop-safety`

Expected: the current generated service retains graphical boot ordering or global settle behavior.

- [ ] **Step 3: Override generator ordering and consumer dependencies**

In the NVIDIA module, override upstream unit dependencies so graphical startup does not wait for CDI generation. Replace broad device settlement with NVIDIA-specific device readiness if the generator requires it. Add explicit consumer ordering in the container modules so first GPU-container use sees a generated CDI specification. Do not disable toolkit generation.

- [ ] **Step 4: Validate unit graph and host evaluation**

Run: `just check-laptop-safety && just fmt-check && just eval laptop`

Expected: dependency assertions and evaluation pass.

- [ ] **Step 5: Commit**

Commit the task files with message `fix(nvidia): defer container discovery from boot`.

### Task 5: Systemd-supervised Quickshell

**Files:**
- Create: `modules/home-manager/quickshell.nix`
- Modify: `home/rupan/laptop.nix`
- Modify: `home/scripts/profile-transition`
- Modify: `home/scripts/toggle-bar`
- Modify: `checks/profile-transition.bash`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Write failing lifecycle tests**

Add fixtures requiring both scripts to use `systemctl --user` for `quickshell-bar.service`, never detached `quickshell ... >/dev/null 2>&1 &` or process-pattern kills. Evaluate the service and assert journal output, `Restart=on-failure`, a bounded restart delay, and an intentional stop that remains stopped. Cover transition restart, toggle hide/show, readiness, and notification ownership.

- [ ] **Step 2: Run focused tests and verify failure**

Run: `just profile-transition-check && just quickshell-test`

Expected: lifecycle ownership assertions fail against direct process management.

- [ ] **Step 3: Implement the Home Manager user service**

Create an auto-discovered Home Manager module with an enable option and `systemd.user.services.quickshell-bar`. Run the repository shell with its established environment and readiness behavior, log to the journal, and restart only on failure. Enable it for the laptop. Route transition and toggle operations through `systemctl --user start`, `stop`, `restart`, and `is-active`; keep intentional hidden state authoritative so stopping does not cause a restart loop.

- [ ] **Step 4: Validate scripts, QML, and evaluation**

Run: `just profile-transition-check && just quickshell-test && just shell-check && just eval laptop`

Expected: lifecycle tests, QML tests, shell checks, and evaluation pass.

- [ ] **Step 5: Commit**

Commit the scoped files with message `feat(quickshell): supervise bar with systemd`.

### Task 6: Home Manager dry-activation guard

**Files:**
- Modify: `modules/home-manager/desktop-profiles.nix`
- Modify: `checks/kitty-agent-colors.bash`

- [ ] **Step 1: Write a failing no-mutation test**

Create a temporary home fixture with sentinel Kitty, OpenCode, and desktop-profile state files. Exercise the activation snippet with `DRY_RUN_CMD` set and compare content, modes, and directory entries before and after. Require the helper not to execute.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `just kitty-agent-colors-check`

Expected: the unguarded helper changes at least one sentinel or invocation log.

- [ ] **Step 3: Guard the helper**

Wrap the `sync-kitty-agent-colors` activation invocation in the same Home Manager dry-run mechanism used by adjacent mutating commands, while preserving normal activation behavior.

- [ ] **Step 4: Run focused and evaluation checks**

Run: `just kitty-agent-colors-check && just fmt-check && just eval laptop`

Expected: dry activation leaves the fixture byte-for-byte unchanged and normal helper tests pass.

- [ ] **Step 5: Commit**

Commit the two files with message `fix(profiles): honor dry activation`.

### Task 7: Lower-cost Quickshell metrics

**Files:**
- Modify: `home/configs/quickshell/services/internal/SystemParser.js`
- Modify: `home/configs/quickshell/services/internal/SystemModel.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Write failing parser and cadence tests**

Add tests for first CPU sample initialization, utilization from two consecutive `/proc/stat` counter sets, reset or invalid counters, and stable memory parsing. Add source/model assertions that the command contains no `sleep`, disk collection is separate from the three-second CPU/memory poll, and disk refresh runs on a slower interval.

- [ ] **Step 2: Run the QML test and verify failure**

Run: `just quickshell-test`

Expected: delta APIs or split commands are absent and the existing metrics command still sleeps and runs `df` every poll.

- [ ] **Step 3: Split fast and slow sampling**

Make the normal command read `/proc/stat` once plus memory. Store the previous CPU counters in `SystemModel`, calculate interval utilization in `SystemParser`, and retain the last valid value during initialization or resets. Move `df` to a separate process on a slower timer while preserving current public model properties.

- [ ] **Step 4: Run QML validation**

Run: `just quickshell-test && just qml-lint && just eval laptop`

Expected: parser/model tests, QML lint, and host evaluation pass.

- [ ] **Step 5: Commit**

Commit the three files with message `perf(quickshell): reduce metrics polling work`.

### Task 8: Post-boot old-root pruning

**Files:**
- Create: `home/scripts/prune-old-roots`
- Modify: `modules/nixos/impermanence.nix`
- Create or modify: `checks/impermanence.bash`
- Modify: `justfile`

- [ ] **Step 1: Write failing cleanup tests**

Use a fake `btrfs` command and temporary tree to model nested subvolumes, retained recent roots, expired roots, a cleanup failure, and two concurrent invocations. Assert initrd source contains rename and blank-root creation but no retention traversal or recursive deletion.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `just impermanence-check`

Expected: the recipe is initially absent or initrd still contains pruning logic.

- [ ] **Step 3: Move retention to a locked service and timer**

Create `prune-old-roots` to enumerate expired roots, delete nested subvolumes deepest-first, and serialize with `flock`. Package it in `impermanence.nix` as a post-boot oneshot service and persistent timer. Keep initrd limited to renaming the current root and creating the blank snapshot. Cleanup failure must fail only the cleanup service.

- [ ] **Step 4: Run cleanup and host checks**

Run: `just impermanence-check && just shell-check && just fmt-check && just eval laptop`

Expected: fixture behavior, shell checks, formatting, and evaluation pass.

- [ ] **Step 5: Commit**

Commit the task files with message `refactor(impermanence): prune old roots after boot`.

### Task 9: CI coverage and integrated verification

**Files:**
- Modify: `.github/workflows/check.yml`
- Modify: `flake.nix` or the existing check aggregation only if needed

- [ ] **Step 1: Add failing workflow assertions where existing agent checks support them**

Require CI to invoke the dedicated flake-update and laptop-safety checks, either directly as named steps or through exported flake checks whose execution is visible in the workflow.

- [ ] **Step 2: Wire dedicated checks into CI**

Add named commands for `just check-flake-update` and `just check-laptop-safety` while preserving existing flake and format checks.

- [ ] **Step 3: Run repository validation**

Run: `just check-changed`

Expected: all checks selected for the complete diff pass.

- [ ] **Step 4: Run broad verification and build**

Run: `just check`

Then run: `just build laptop`

Expected: the full local gate and laptop closure build succeed.

- [ ] **Step 5: Inspect live-applicable unit definitions**

Evaluate and record effective unit properties for `nix-daemon`, `nvidia-container-toolkit-cdi-generator`, the old-root pruning unit/timer, and the Quickshell user service. If the built generation is switched, inspect cgroup placement during one manual and one automatic build. Do not claim cold-boot timing or GPU-container acceptance without a reboot and actual containers.

- [ ] **Step 6: Commit**

Commit CI changes with message `ci: cover update and laptop safety checks`.
