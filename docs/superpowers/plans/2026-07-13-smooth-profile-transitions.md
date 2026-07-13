# Smooth Profile Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Quickshell alive across same-bar profile/variant/wallpaper theme changes by hot-reloading theme JSON, and ensure bar-type changes do a single stop→start with no second kill from wallpaper theming.

**Architecture:** Add a stamp-file nudge (`quickshell-theme-reload`) that Quickshell watches via `FileView` to re-run `select-quickshell-theme` and `applyTheme()`. `profile-transition` skips stop/start when already on Quickshell; `apply_wallpaper_theme` nudges instead of `pkill`. Script/check work lands first; `shell.qml` is a minimal additive hook after (or coordinated with) other agents’ Quickshell service edits.

**Tech Stack:** Bash, Quickshell/QML (`FileView`, `Process`), repository fixture harness in `checks/profile-transition.bash`, `just shell-check` / `just wallpaper-script-check`

**Spec:** `docs/superpowers/specs/2026-07-13-smooth-profile-transitions-design.md`

---

## File Structure

- Modify `home/scripts/profile-common`: add `nudge_quickshell_theme_reload`; replace Quickshell `pkill`/relaunch in `apply_wallpaper_theme` with the nudge.
- Modify `home/scripts/profile-transition`: same-bar Quickshell skip path + verify fallback + post-commit nudge.
- Modify `home/configs/quickshell/shell.qml`: watch stamp and re-run theme loader (additive only; do not touch PowerService / other services).
- Modify `checks/profile-transition.bash`: same-bar no-pkill, wallpaper-themed no second launch, qs→qs pairing exceptions, stamp assertions.
- Do **not** edit: `PowerService.qml`, `PowerModel.qml`, `PowerParser.js`, `power-probe`, or power-related tests.

### Task 1: Add `nudge_quickshell_theme_reload` (TDD via wallpaper-themed fixture)

**Files:**
- Modify: `home/scripts/profile-common`
- Modify: `checks/profile-transition.bash` (wallpaper-themed expectations around lines 600–613)

- [ ] **Step 1: Change the wallpaper-themed fixture to expect a stamp, not a relaunch**

In `checks/profile-transition.bash`, replace the post-matugen Quickshell relaunch assertion in the `wallpaper-themed` scenario with:

```bash
  run_legacy_transition wallpaper-themed switch new
  assert_log_contains_eventually \
    "matugen color hex #6c7a89 --mode light --type scheme-tonal-spot -c $home/.config/matugen/config-new.toml active=new" \
    "wallpaper-themed profile dispatches its runtime palette adapter after commit"
  assert_log_not_contains \
    "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml active=new" \
    "wallpaper theme does not kill Quickshell to repaint"
  # After switch from waybar→quickshell there is exactly one topbar launch from start_bar;
  # wallpaper theming must not launch shell.qml again.
  launch_count=$(grep -c "quickshell -p $REPO_ROOT/home/configs/quickshell/shell.qml " "$log" || true)
  assert_eq "1" "$launch_count" \
    "wallpaper theme does not relaunch Quickshell after start_bar"
  [ -s "$profiles/quickshell-theme-reload" ] \
    || { printf 'FAIL: missing quickshell-theme-reload stamp after wallpaper theme\n' >&2; exit 1; }
```

Keep the matugen assertion. Remove the old assertion that required:

`"quickshell -p .../quickshell/shell.qml active=new"` / `"wallpaper theme waits for its post-commit Quickshell relaunch"`.

- [ ] **Step 2: Run the transition check and verify RED**

Run: `bash checks/profile-transition.bash`

Expected: FAIL on missing stamp and/or unexpected second launch / still-present pkill from `apply_wallpaper_theme`.

- [ ] **Step 3: Add the nudge helper and wire it into `apply_wallpaper_theme`**

In `home/scripts/profile-common`, near `write_profile_value_atomic` / wallpaper helpers, add:

```bash
# nudge_quickshell_theme_reload
# Bump a stamp FileView'd by Quickshell so it re-runs select-quickshell-theme
# and applyTheme() without killing the process.
nudge_quickshell_theme_reload() {
  local stamp="$PROFILES_DIR/quickshell-theme-reload"
  mkdir -p "$PROFILES_DIR"
  write_profile_value_atomic "$stamp" "$(date +%s%N 2>/dev/null || date +%s)"
}
```

In `apply_wallpaper_theme`, **delete** the block that stops mako / `pkill`s quickshell / relaunches it (the block beginning with the comment `The topbar reads its theme JSON only at startup`). Replace with:

```bash
  # Quickshell watches quickshell-theme-reload and hot-applies select-quickshell-theme.
  if [ "$(profile_bar "$profile")" = "quickshell" ]; then
    nudge_quickshell_theme_reload
  fi
```

Keep kitty/tmux/gtk/spicetify/niri accent behavior unchanged. Update the comment above the old restart so it no longer claims restart is required.

- [ ] **Step 4: Re-run the transition check**

Run: `bash checks/profile-transition.bash`

Expected: wallpaper-themed scenario PASS. Other scenarios still pass (or only fail later tasks’ new assertions — none yet).

- [ ] **Step 5: Commit**

```bash
git add home/scripts/profile-common checks/profile-transition.bash
git commit -m "$(cat <<'EOF'
Nudge Quickshell theme reload instead of killing the bar

Wallpaper theming for tinted/sharp no longer pkill/relaunches Quickshell; it bumps a stamp for in-process theme apply.
EOF
)"
```

### Task 2: Same-bar Quickshell skip in `profile-transition`

**Files:**
- Modify: `home/scripts/profile-transition` (bar stop/start around lines 717–730; post-commit around `dispatch_post_commit_adapters`)
- Modify: `checks/profile-transition.bash` (pairing loop ~1297–1350; add a dedicated same-bar case)

- [ ] **Step 1: Write failing fixture coverage for qs→qs and two Quickshell profiles**

**A. Pairing loop:** In the `for previous in old qs noc; do … for target in old qs noc` block, change the stop/start assertions so same-bar Quickshell does not expect a kill/start:

```bash
    case "$previous" in
      old) assert_log_contains 'pkill -f waybar' "Waybar is stopped from $previous to $target" ;;
      qs)
        if [ "$target" = qs ]; then
          assert_log_not_contains "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
            "same-bar Quickshell switch leaves the topbar process running"
        else
          assert_log_contains "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
            "Quickshell exact topbar is stopped from $previous to $target"
        fi
        ;;
      noc) assert_log_contains 'systemctl --user stop noctalia-shell' \
        "Noctalia is stopped from $previous to $target" ;;
    esac
    case "$target" in
      old)
        assert_log_contains 'pgrep -f waybar' "Waybar readiness uses pgrep from $previous"
        assert_log_contains 'systemctl --user start awww' "Waybar starts awww from $previous"
        assert_log_contains_eventually 'mako ' "Waybar starts Mako from $previous"
        assert_log_contains 'makoctl mode -a dnd' "Waybar rearms focus DND from $previous"
        assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
          "Waybar verifies notification ownership from $previous"
        ;;
      qs)
        assert_log_contains "pgrep -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
          "Quickshell readiness uses the exact topbar from $previous"
        if [ "$previous" = qs ]; then
          assert_log_not_contains 'systemctl --user start awww' \
            "same-bar Quickshell does not re-run start_bar awww from $previous"
          assert_log_not_contains "pkill -x \\.?mako(-wrapped)?" \
            "same-bar Quickshell does not stop Mako via start_bar from $previous"
        else
          assert_log_contains 'systemctl --user start awww' "Quickshell starts awww from $previous"
          assert_log_contains "pkill -x \\.?mako(-wrapped)?" "Quickshell stops Mako from $previous"
          assert_log_not_contains 'makoctl mode -a dnd' "Quickshell does not rearm focus DND from $previous"
          assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
            "Quickshell verifies notification ownership from $previous"
        fi
        ;;
      noc)
        # keep the existing noctalia assertions unchanged
        ;;
    esac
```

**B. Dedicated same-bar profile switch + stamp:** After the pairing loop (or near other Quickshell scenarios), add a second Quickshell profile and assert a stamp nudge:

```bash
cp -a "$profiles/qs" "$profiles/qs2"
"$real_jq" '.name = "qs2"' "$profiles/qs2/manifest.json" \
  > "$profiles/qs2/manifest.json.tmp"
mv "$profiles/qs2/manifest.json.tmp" "$profiles/qs2/manifest.json"
printf 'qs\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs2"
ln -sfn "$profiles/qs/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell-started\n' > "$bar_state"
printf 'quickshell\n' > "$notification_state"
: > "$log"
rm -f "$profiles/quickshell-theme-reload"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" NOTIFICATION_STATE="$notification_state" \
  REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs2
assert_eq "qs2" "$(cat "$profiles/active")" "same-bar switch commits qs2"
assert_log_not_contains "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
  "qs→qs2 does not kill Quickshell"
[ -s "$profiles/quickshell-theme-reload" ] \
  || { printf 'FAIL: same-bar switch did not nudge quickshell-theme-reload\n' >&2; exit 1; }
```

Ensure `NOTIFICATION_STATE` is exported the same way other scenarios do (match existing env var names in the file).

- [ ] **Step 2: Run check — expect RED**

Run: `bash checks/profile-transition.bash`

Expected: FAIL — qs→qs still pkills; qs2 stamp missing.

- [ ] **Step 3: Implement same-bar skip + post-commit nudge**

In `home/scripts/profile-transition`, replace the stop/start sequence near the end with logic equivalent to:

```bash
SAME_QUICKSHELL=0
if [ "$MODE" != reapply ] \
  && [ "$CURRENT_BAR" = quickshell ] \
  && [ "$TARGET_BAR" = quickshell ] \
  && pgrep -f "quickshell.*$REPO_HOME/configs/quickshell/shell.qml" >/dev/null 2>&1; then
  SAME_QUICKSHELL=1
fi

if [ "$MODE" = reapply ]; then
  stop_all_bars
elif [ "$SAME_QUICKSHELL" -eq 0 ]; then
  stop_bar "$CURRENT_BAR"
fi

install_staged_files
NIRI_OVERRIDE=$(profile_manifest_artifact "$TARGET" "$TARGET_VARIANT" niri.default)
if [ "$(read_state "$FOCUS_FILE" "off")" = "on" ] && [ "$TARGET" != "noctalia" ]; then
  NIRI_OVERRIDE=$(profile_manifest_artifact "$TARGET" "$TARGET_VARIANT" niri.focus)
fi
link_atomic "$ACTIVE_LINK" "$NIRI_OVERRIDE"
niri msg action load-config-file >/dev/null 2>&1

if [ "$SAME_QUICKSHELL" -eq 1 ]; then
  if ! verify_bar quickshell; then
    start_bar quickshell "$TARGET" "$TARGET_VARIANT"
    verify_bar quickshell
  fi
else
  start_bar "$TARGET_BAR" "$TARGET" "$TARGET_VARIANT"
  verify_bar "$TARGET_BAR"
fi
```

After commit, at the end of `dispatch_post_commit_adapters` (when `TARGET_BAR` is quickshell and mode is not `startup`), call:

```bash
if [ "$TARGET_BAR" = quickshell ] && [ "$MODE" != startup ]; then
  nudge_quickshell_theme_reload
fi
```

Keep adapters after `commit_transaction` (today’s order). For wallpaper-theming targets the async theme job nudges again when matugen finishes; an early nudge that loads static/base theme is intended.

Do **not** change `--reapply` / `startup` hard-restart behavior.

- [ ] **Step 4: Run check — expect GREEN**

Run: `bash checks/profile-transition.bash`

Expected: PASS including qs→qs and qs→qs2.

- [ ] **Step 5: ShellCheck**

Run: `just shell-check`

Expected: PASS (no new shellcheck errors on touched scripts).

- [ ] **Step 6: Commit**

```bash
git add home/scripts/profile-transition checks/profile-transition.bash
git commit -m "$(cat <<'EOF'
Skip Quickshell restart on same-bar profile switches

Keep the topbar process when already on Quickshell, verify it stayed healthy, and nudge theme reload after commit.
EOF
)"
```

### Task 3: Quickshell `FileView` hot-reload hook

**Files:**
- Modify: `home/configs/quickshell/shell.qml` (theme loader ~148–164 only)
- Collision: If `shell.qml` or adjacent service files are dirty from another agent, **wait** until that work is committed/settled. Do not edit PowerService files. Re-read `shell.qml` immediately before editing.

- [ ] **Step 1: Confirm collision clear**

Run:

```bash
git status --short home/configs/quickshell/
```

Expected: clean (or only unrelated already-committed history). If dirty with power-service work, stop and wait.

- [ ] **Step 2: Add stamp watcher + reload**

Extend the existing `themeLoader` Process so a stamp change re-runs selection. Prefer matching whichever FileView signal `NotifService.qml` uses successfully in-tree (`onLoaded` after atomic replace). Concrete shape:

```qml
    function reloadTheme() {
        themeLoader.running = false;
        themeLoader.running = true;
    }

    Process {
        id: themeLoader
        running: true
        command: ["select-quickshell-theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim();
                if (!txt)
                    return;
                try {
                    root.applyTheme(JSON.parse(txt));
                } catch (e) {
                    console.warn("quickshell-theme.json parse failed:", e);
                }
            }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop-profiles/quickshell-theme-reload"
        watchChanges: true
        onLoaded: root.reloadTheme()
    }
```

If double-firing on first load is a problem (initial Process already loads theme), gate with a flag set after the first `themeLoader` finish, or only call `reloadTheme` when the stamp file is non-empty and mtime advanced — keep the guard minimal.

Do not change service instantiations, Topbar wiring, or theme property defaults beyond what `applyTheme` already sets.

- [ ] **Step 3: Lint QML**

Run: `just qml-lint`

Expected: PASS (or only pre-existing unresolved-import noise the recipe already disables).

- [ ] **Step 4: Commit**

```bash
git add home/configs/quickshell/shell.qml
git commit -m "$(cat <<'EOF'
Hot-reload Quickshell theme from profile stamp

Watch desktop-profiles/quickshell-theme-reload and re-run select-quickshell-theme into applyTheme without restarting the shell.
EOF
)"
```

### Task 4: Full validation + manual smoke

**Files:** none required unless checks reveal gaps

- [ ] **Step 1: Run script/profile gates**

Run:

```bash
just shell-check
just wallpaper-script-check
```

Expected: PASS (includes `checks/profile-transition.bash`).

- [ ] **Step 2: Manual smoke (on the live session)**

Only after Task 3 is active in the running Quickshell (restart Quickshell **once** manually or via a cross-bar switch so the FileView exists):

1. Quickshell ↔ Quickshell (e.g. nord ↔ sharp, or sharp ↔ tinted): bar stays visible; colors update.
2. On tinted or sharp: change wallpaper (waypaper / random): wallpaper fades; bar recolors without disappearing.
3. noctalia ↔ quickshell once: single restart, no second blink after wallpaper settles.

- [ ] **Step 3: Final commit only if Step 1 forced small fixture tweaks**

If no further code changes, skip. Otherwise commit the fixup with a message describing the check gap.

---

## Spec coverage self-check

| Spec requirement | Task |
| --- | --- |
| Hot-apply via `applyTheme` + stamp FileView | Task 3 |
| `nudge_quickshell_theme_reload` helper | Task 1 |
| Skip stop/start when same Quickshell bar | Task 2 |
| `apply_wallpaper_theme` no longer pkills | Task 1 |
| Cross-bar / reapply / startup keep hard restart | Task 2 (explicit non-change) |
| verify_bar failure → start_bar fallback | Task 2 |
| Leaving tinted: tag mismatch → static theme | covered by existing `select-quickshell-theme` + nudge |
| Tests: same-bar no pkill; wallpaper no second kill; cross-bar one restart | Tasks 1–2 |
| Collision plan / avoid PowerService | Task 3 gate + file list |
| Validation commands | Task 4 |

## Placeholder / consistency self-check

- Stamp path is consistently `~/.config/desktop-profiles/quickshell-theme-reload` (`$PROFILES_DIR/quickshell-theme-reload`).
- Helper name is consistently `nudge_quickshell_theme_reload`.
- No TBD/TODO placeholders remain in tasks.
