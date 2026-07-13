# Smooth profile & wallpaper transitions — design

Date: 2026-07-13
Status: approved, ready for implementation plan
Scope: Eliminate choppy bar disappear/reappear on Quickshell↔Quickshell profile
switches and on tinted/sharp wallpaper theme updates, without colliding with
in-flight Quickshell service work.

## Goal

- Wallpaper changes already fade via `awww`; keep that.
- When staying on Quickshell, the bar must **stay up** and recolor/restyle in
  place (no process death).
- When the bar *type* changes (e.g. noctalia ↔ quickshell), allow **one** clean
  stop→start with a short gap — no fancy opacity animation.
- Never restart the bar twice for a single user action (the current tinted/sharp
  path often does).

## Problem (current)

1. `profile-transition` always stops the current bar and starts the target bar,
   even when both are Quickshell.
2. For wallpaper-theming profiles (`wallpaperTheming`, e.g. tinted/sharp),
   `set_wallpaper` → `apply_wallpaper_theme` ends with `pkill` + relaunch of
   Quickshell so it re-reads theme JSON — a **second** blink after the switch’s
   first restart.
3. Quickshell already has `applyTheme()` but only loads theme once at startup
   via a `select-quickshell-theme` Process (`shell.qml`). Comments in
   `profile-common` assume restart is required to repaint.

## Decisions (locked)

| Topic | Choice |
| --- | --- |
| Same-bar Quickshell switches | Hot-reload theme in place; skip stop/start |
| Tinted/sharp wallpaper retheme | Write runtime JSON + nudge reload; no `pkill` |
| Bar-type changes | Single stop→start (good enough; no fade animation) |
| Approach | Hot-reload + skip same-bar restart (not orchestration-only or soft-restart) |
| Waybar same-bar hot-reload | Out of scope |
| Wallpaper fade duration/engine | Unchanged (`awww` fade 1s) |

## Architecture

### Contract

1. Quickshell can hot-apply theme JSON through existing `applyTheme()` without
   exiting the process.
2. Scripts request a reload by bumping a stamp file — not via `pkill`.
3. `profile-transition` skips `stop_bar` / `start_bar` when
   `CURRENT_BAR == TARGET_BAR == quickshell` and a matching Quickshell process
   is already running. It still installs staged files, updates niri overrides,
   commits active/variant, runs post-commit adapters, then nudges reload.
4. `apply_wallpaper_theme` writes `runtime-quickshell-theme.json` + profile/variant
   tags, then nudges reload. It does **not** kill Quickshell.
5. Cross-bar / `--reapply` / `startup` keep a single hard restart. Wallpaper
   theming after that must not kill the new bar again.

### Components

**Quickshell (`home/configs/quickshell/shell.qml`)**

- Keep the existing one-shot `themeLoader` Process for first paint.
- Add a `FileView` on
  `~/.config/desktop-profiles/quickshell-theme-reload` with `watchChanges: true`.
- On change: re-run `select-quickshell-theme`, parse JSON, call `applyTheme`.
- Parse failures: warn and keep the previous theme (same guard as today).
- No panel teardown — colors and layout flags morph in place.

**Reload helper (`home/scripts/profile-common`)**

- `nudge_quickshell_theme_reload`: atomically update the stamp file so the
  FileView fires.
- Shared by profile-switch post-commit and wallpaper theming.
- If Quickshell is not running and the active/target bar is quickshell, start it
  once (startup / crash recovery) — never “restart for theme.”

**`profile-transition`**

- **Same-bar Quickshell:** install staged files → niri reload → skip stop/start
  → `verify_bar` (process still healthy) → commit → post-commit adapters →
  `nudge_quickshell_theme_reload` (after active/variant commit so
  `select-quickshell-theme` resolves correctly).
- **Cross-bar / reapply:** existing single stop→start.
- If same-bar `verify_bar` fails (process died mid-switch), fall back to one
  `start_bar` so the desktop is not left barless.

**`apply_wallpaper_theme`**

- Remove the late `pkill` + relaunch block for Quickshell.
- After writing runtime theme + tags: `nudge_quickshell_theme_reload`.
- Standalone wallpaper change (waypaper) and switch-into-tinted/sharp both use
  this path → one in-place recolor when matugen/iris finishes. A brief base
  theme before the derived palette settles is acceptable.

### Sequencing (same-bar Quickshell switch)

```text
lock → stage/install profile files → niri load-config-file
  → (keep Quickshell alive) → verify_bar
  → commit active/variant → post-commit adapters
       (wallpaper fade via awww; theming async)
  → nudge_quickshell_theme_reload
  → (later) matugen/iris finishes → nudge again → in-place recolor
```

### Sequencing (cross-bar)

```text
stop old bar → install → niri → start new bar → verify → commit
  → post-commit (wallpaper / theming nudges only; no second kill)
```

## Edge cases

- **Leaving tinted/sharp:** runtime theme tags won’t match the new profile;
  `select-quickshell-theme` falls through to the static artifact after nudge.
  No requirement to delete the runtime JSON.
- **Entering tinted/sharp:** may briefly show static/base theme, then recolor
  when the engine finishes (still no blink).
- **Variant toggle** on the same Quickshell profile: same-bar path + nudge.
- **`--reapply` / `startup`:** full stop→start (recovery / cold start).
- **Stamp before watcher is ready:** initial `themeLoader` covers first paint;
  a redundant nudge after start is harmless.
- **Notification bus:** removing the wallpaper-theme `pkill` also removes the
  window where `notify-send` can dbus-activate mako while the bar is down.
  Cross-bar start path still stops mako before launching Quickshell as today.

## Collision plan (other agent)

Another agent has been editing Quickshell power-service files and `shell.qml`.

- Prefer landing script/check changes first (`profile-transition`,
  `profile-common`, `checks/profile-transition.bash`).
- Touch `shell.qml` only after that work has settled, or as a minimal additive
  FileView/reload hook that does not reshape services.
- Do not edit PowerService / PowerModel / PowerParser / power-probe / related
  tests as part of this work.

## Testing

Automated:

- Extend `checks/profile-transition.bash`:
  - Same-bar Quickshell switch: assert **no** quickshell `pkill`.
  - Wallpaper-themed path: assert stamp nudge / **no** second kill.
  - Cross-bar: assert exactly one stop/start.
- `just shell-check && just wallpaper-script-check`
- Existing profile-transition check recipe(s) must stay green.

Manual:

- Quickshell ↔ Quickshell profile switch (e.g. nord ↔ sharp): bar stays visible.
- Tinted/sharp wallpaper change: palette updates without bar blink.
- One noctalia ↔ quickshell switch: single clean restart.

## Out of scope

- Animated opacity crossfades between different bar implementations.
- Waybar in-process theme hot-reload.
- Changing wallpaper transition type/duration.
- Broader Quickshell system-model / service refactors.

## Success criteria

- Same-bar Quickshell profile/variant switch: zero Quickshell process restarts.
- Wallpaper theming on tinted/sharp: zero Quickshell process restarts for theme
  apply; bar recolors in place after runtime JSON is written.
- Bar-type change: at most one stop→start; wallpaper theming does not add a
  second restart.
- Profile-transition fixture checks updated and passing.
