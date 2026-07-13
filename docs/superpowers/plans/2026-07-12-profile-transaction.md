# Desktop Profile Transaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route profile switches, variant changes, startup, and reapply through one core transaction with locking and rollback while keeping application theming best-effort.

**Architecture:** A Bash transaction module owns target resolution, snapshots, core file installation, Niri and bar changes, commit, and rollback. Existing integration functions remain in `profile-common`; public commands become thin delegates after compatibility tests lock their interfaces.

**Tech Stack:** Bash, Home Manager generated profile artifacts, `flock`, systemd user units, fixture command adapters, ShellCheck

---

## File Structure

- Create `home/scripts/profile-transition`: single transition command and transaction owner.
- Create `checks/profile-transition.bash`: temporary-home integration fixture with fake desktop commands.
- Modify `home/scripts/switch-profile`: preserve list/status interface and delegate mutations.
- Modify `home/scripts/toggle-variant`: delegate explicit and implicit variant changes.
- Modify `home/scripts/profile-common`: retain adapters, add only focused snapshot/install helpers that are shared outside the transaction.
- Modify `justfile`: register the focused test in the wallpaper/script gate.

### Task 1: Lock the public command interfaces

**Files:**
- Create: `checks/profile-transition.bash`
- Modify: `justfile:12-16`

- [ ] **Step 1: Create the fixture profile home**

Build `$tmpdir/home/.config/desktop-profiles/{old,new}` with minimal `meta.json`, `runtime.json`, dark/light color files, Niri overrides, Waybar files, and wallpaper directories. Seed:

```text
active = old
active-variant = dark
variant-old = dark
active-niri-overrides.kdl -> old/niri-overrides.kdl
```

Put fake `systemctl`, `niri`, `pgrep`, `pkill`, `quickshell`, `waybar`, `gsettings`, `notify-send`, `busctl`, and `jq` adapters in `$tmpdir/bin`. Real `jq` may be forwarded after logging.

- [ ] **Step 2: Write failing delegation assertions**

Invoke the future engine directly:

```bash
HOME="$home" \
XDG_CONFIG_HOME="$home/.config" \
PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" \
COMMAND_LOG="$log" \
PATH="$bin_dir:$PATH" \
home/scripts/profile-transition switch new
```

Assert active becomes `new`, the variant becomes the stored target preference, the Niri link points to `new/niri-overrides.kdl`, and the target bar is verified before the active file changes. Also assert these compatibility commands eventually map to the engine:

```text
switch-profile new        profile-transition switch new
switch-profile --reapply  profile-transition reapply
switch-profile --startup  profile-transition startup
toggle-variant light      profile-transition variant light
toggle-variant            profile-transition variant toggle
```

- [ ] **Step 3: Run the fixture to verify it fails**

Run: `bash checks/profile-transition.bash`

Expected: FAIL because `home/scripts/profile-transition` does not exist.

- [ ] **Step 4: Register the fixture**

Add `bash checks/profile-transition.bash` to `wallpaper-script-check` after the existing focused scripts.

- [ ] **Step 5: Commit the failing test**

```bash
git add checks/profile-transition.bash justfile
git commit -m "test(profiles): define transition contract"
```

### Task 2: Implement resolution, locking, and atomic preference commits

**Files:**
- Create: `home/scripts/profile-transition`
- Test: `checks/profile-transition.bash`

- [ ] **Step 1: Implement the command interface**

Start with:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/profile-common"

mode=${1:-}
argument=${2:-}
lock_path=${PROFILE_TRANSITION_LOCK:-"$HOME/.local/state/desktop-profiles/transition.lock"}
mkdir -p "$(dirname "$lock_path")"
exec {transition_fd}>"$lock_path"
flock -n "$transition_fd" || {
  printf 'desktop profile transition already running: %s\n' "$lock_path" >&2
  exit 1
}
```

Accept only `switch NAME`, `variant dark|light|toggle`, `reapply`, and `startup [NAME]`. Resolve the target and reject an explicit light variant unless `.hasLightVariant` is true.

- [ ] **Step 2: Add atomic text and symlink helpers**

Keep them private to this module:

```bash
write_atomic() {
  local destination=$1 value=$2 temporary
  temporary=$(mktemp "$(dirname "$destination")/.transition.XXXXXX")
  printf '%s\n' "$value" > "$temporary"
  mv -f "$temporary" "$destination"
}

link_atomic() {
  local destination=$1 target=$2 temporary
  temporary=$(mktemp -u "$(dirname "$destination")/.transition-link.XXXXXX")
  ln -s "$target" "$temporary"
  mv -Tf "$temporary" "$destination"
}
```

- [ ] **Step 3: Implement the minimal successful transaction**

For this task only, snapshot active text values and the Niri link, install the target Niri link, require `niri msg action load-config-file`, call bar stop/start/verify helpers, then atomically write preference files. Do not move application adapters yet.

- [ ] **Step 4: Run focused tests and ShellCheck**

Run: `bash checks/profile-transition.bash && just shell-check`

Expected: PASS for successful switch, variant resolution, and lock contention cases implemented so far.

- [ ] **Step 5: Commit**

```bash
git add home/scripts/profile-transition checks/profile-transition.bash
git commit -m "feat(profiles): add core transition engine"
```

### Task 3: Add snapshot and rollback for core files

**Files:**
- Modify: `home/scripts/profile-transition`
- Modify: `checks/profile-transition.bash`

- [ ] **Step 1: Add failure injection tests**

Parameterize adapters with `FAIL_COMMAND`. Run separate cases failing:

```text
installing staged core files
niri msg action load-config-file
starting target bar
verifying target bar
```

For every case, assert the previous active/variant files, Niri symlink, live Waybar/Mako files, live color files, and previous bar are restored. Add a case where restarting the previous bar also fails and assert all remaining restoration steps still run.

- [ ] **Step 2: Run tests to verify rollback is absent**

Run: `bash checks/profile-transition.bash`

Expected: rollback cases FAIL with target state left behind.

- [ ] **Step 3: Implement a manifest-based snapshot**

Create a temporary transaction directory under `${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}`. Store one manifest row per path with type `missing`, `file`, or `symlink`. Snapshot exactly the paths selected for the target transition, including Waybar, Mako, GTK, Qt, Kitty, cursor/font/appearance outputs, the active Niri link, and runtime Niri override.

Use functions with these interfaces:

```bash
snapshot_path PATH
restore_snapshot
rollback ORIGINAL_STATUS
commit_transaction
```

Install `trap 'rollback $?' ERR INT TERM` only after the snapshot is complete. `commit_transaction` clears the trap and removes the transaction directory.

- [ ] **Step 4: Restore in reverse and accumulate errors**

`restore_snapshot` reads the manifest in reverse, attempts every restore, records failures in `$transaction_dir/rollback-errors`, reloads Niri, and restarts the previous bar. `rollback` prints both the original failed phase and every rollback error, then exits with the original nonzero status.

- [ ] **Step 5: Verify and commit**

Run: `bash checks/profile-transition.bash && just shell-check`

Expected: all rollback cases PASS.

```bash
git add home/scripts/profile-transition checks/profile-transition.bash
git commit -m "feat(profiles): roll back failed core transitions"
```

### Task 4: Consolidate bar and core-file sequencing

**Files:**
- Modify: `home/scripts/profile-transition`
- Modify: `home/scripts/profile-common`
- Modify: `checks/profile-transition.bash`

- [ ] **Step 1: Add bar matrix tests**

Cover previous and target combinations for Noctalia, Waybar, and Quickshell. Assert:

```text
Noctalia verification uses systemctl --user is-active noctalia-shell
Waybar verification uses pgrep -f waybar
Quickshell verification uses its exact shell.qml process pattern
Waybar installs writable config/style and starts Mako
Quickshell and Noctalia stop Mako
Noctalia stops awww; other bars start it
focus-mode DND is rearmed only for Waybar
```

- [ ] **Step 2: Run tests to identify sequencing gaps**

Run: `bash checks/profile-transition.bash`

Expected: new bar cases FAIL before the complete helpers exist.

- [ ] **Step 3: Move bar policy behind four internal functions**

Implement:

```bash
stop_bar BAR
stage_bar_files BAR PROFILE_DIR VARIANT STAGE_DIR
start_bar BAR
verify_bar BAR
```

Keep Mako and awww operations inside these functions. Poll verification for up to two seconds in 100 ms intervals. A failed verification returns nonzero and triggers rollback.

- [ ] **Step 4: Stage core files before stopping the old bar**

Build all writable target files under the transaction directory first. Only after every stage operation succeeds should the old bar stop. Install staged files atomically with same-filesystem temporary files in each destination directory.

- [ ] **Step 5: Verify and commit**

Run: `bash checks/profile-transition.bash && just wallpaper-script-check && just shell-check`

Expected: all PASS.

```bash
git add home/scripts/profile-transition home/scripts/profile-common checks/profile-transition.bash
git commit -m "refactor(profiles): centralize core transition sequencing"
```

### Task 5: Migrate public commands and post-commit adapters

**Files:**
- Modify: `home/scripts/switch-profile`
- Modify: `home/scripts/toggle-variant`
- Modify: `home/scripts/profile-transition`
- Modify: `checks/profile-transition.bash`

- [ ] **Step 1: Add compatibility and adapter-isolation tests**

Run each public command from the fixture and assert its engine arguments. Make one application adapter fail after core commit and assert the command reports the adapter failure while active profile, variant, Niri, and bar remain on the new state.

- [ ] **Step 2: Run tests before migration**

Run: `bash checks/profile-transition.bash`

Expected: delegation cases FAIL because mutation logic remains duplicated.

- [ ] **Step 3: Reduce public commands to their stable interfaces**

Keep `switch-profile --status` and profile listing in `switch-profile`. Replace mutation paths with:

```bash
exec "$SCRIPT_DIR/profile-transition" switch "$target"
exec "$SCRIPT_DIR/profile-transition" reapply
exec "$SCRIPT_DIR/profile-transition" startup "${target:-}"
```

Replace `toggle-variant` with validation plus:

```bash
exec "$SCRIPT_DIR/profile-transition" variant "${1:-toggle}"
```

- [ ] **Step 4: Move best-effort dispatch after commit**

After `commit_transaction`, dispatch wallpaper and application adapters. Wrap each adapter so one failure does not prevent later adapters. Record failures in a temporary log, emit one warning summary, and return success because the core transaction committed successfully.

- [ ] **Step 5: Verify and commit**

Run:

```bash
just wallpaper-script-check
just shell-check
```

Expected: all PASS.

```bash
git add home/scripts/profile-transition home/scripts/switch-profile home/scripts/toggle-variant checks/profile-transition.bash
git commit -m "refactor(profiles): route changes through one transaction"
```

### Task 6: Preserve startup, focus, and wallpaper behavior

**Files:**
- Modify: `home/scripts/profile-transition`
- Modify: `checks/profile-transition.bash`
- Modify only if proven necessary: `home/scripts/profile-common`

- [ ] **Step 1: Add regression cases**

Cover invalid startup fallback to Noctalia, startup preference preservation, reapply with a bar override, focus-mode Niri override selection, self-themed Noctalia wallpaper dispatch, static wallpaper selection, wallpaper-themed adapter dispatch, and the profile switcher popup.

- [ ] **Step 2: Run tests to reveal behavioral drift**

Run: `bash checks/profile-transition.bash`

Expected: any unported legacy behavior FAILS with an exact missing command or state assertion.

- [ ] **Step 3: Port only demonstrated missing behavior**

Place core behavior before commit and wallpaper/application behavior after commit. Keep startup from rewriting valid preference files. Keep focus selection as:

```bash
if [ "$(cat "$FOCUS_FILE" 2>/dev/null)" = on ] && [ "$target" != noctalia ]; then
  niri_override="$target_dir/niri-overrides-focus.kdl"
else
  niri_override="$target_dir/niri-overrides.kdl"
fi
```

- [ ] **Step 4: Verify focused and declarative checks**

Run:

```bash
just wallpaper-script-check
just shell-check
just check-profiles
just fmt-check
just eval laptop
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add home/scripts/profile-transition home/scripts/profile-common checks/profile-transition.bash
git commit -m "test(profiles): preserve transition runtime behavior"
```

### Task 7: Final profile-transition verification

**Files:**
- Modify only if a verification failure proves it necessary.

- [ ] **Step 1: Run the full relevant gate**

Run:

```bash
just wallpaper-script-check
just shell-check
just check-profiles
just fmt-check
just eval laptop
git diff --check
```

Expected: all PASS and no uncommitted changes.

- [ ] **Step 2: Inspect the final interface**

Run:

```bash
rg -n 'profile-transition' home/scripts/switch-profile home/scripts/toggle-variant
rg -n '^apply_|^set_|^write_|^copy_' home/scripts/profile-common
```

Expected: all mutation entry points delegate to `profile-transition`; application adapters remain in `profile-common` and no second core transition sequence remains.
