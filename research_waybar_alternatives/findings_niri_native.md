# Wayland Bars with Niri Support — Research Findings

**Research scope:** Modern Linux Wayland status bars that integrate with [Niri](https://github.com/YaLTeR/niri) (scrollable-tiling Wayland compositor). Prioritizing explicit Niri support or credible community usage, with coverage of: workspaces, active window info, custom commands/scripts, and tray/status capabilities.

---

## 1. Waybar (⭐ Top Recommendation)

**Repository:** https://github.com/Alexays/Waybar | 11K stars | C++

### Native Niri Modules (Merged — Stable)

Waybar merged first-class Niri support in **September 2024** via a PR authored by **YaLTeR** (Niri's creator):

- **PR #3551** — `niri/workspaces`, `niri/window`, `niri/language` modules  
  https://github.com/Alexays/Waybar/pull/3551  
  *Evidence: Merged by Alexays (waybar owner), 1170-line PR, authored by Niri maintainer. **Highest confidence.***

- Official Arch manual page for `niri/workspaces`:  
  https://man.archlinux.org/man/extra/waybar/waybar-niri-workspaces.5.en  
  *Evidence: Arch wiki–level documentation. **Very high confidence.***

### Niri Taskbar (per-workspace window list)

- **LawnGnome/niri-taskbar** — Rust crate (125 stars, MIT) providing a Waybar taskbar for Niri with proper workspace+window ordering:  
  https://github.com/LawnGnome/niri-taskbar  
  https://lib.rs/crates/niri-taskbar (4 releases, active maintenance)  
  *Evidence: Blog post from author validating real-world use (see below), AUR package `waybar-niri-taskbar` exists, active releases. **High confidence.***

- **adelmonte/niri_workspaces** — Waybar module with pie chart icons, drag-and-drop, multi-monitor, window filtering (GPL v3):  
  https://github.com/adelmonte/niri_workspaces  
  *Evidence: Newer module (v0.1.0, Feb 2026), Arch AUR package. **Medium confidence — newer but actively developed.*

- **justbuchanan/waybar-niri-workspaces-enhanced** — Rust replacement module showing icons for running programs (14 stars, MIT):  
  https://github.com/justbuchanan/waybar-niri-workspaces-enhanced  
  Includes NixOS Home Manager flake integration.  
  *Evidence: Community tool, Nix flake support. **Medium confidence.***

- **adelmonte/niri_window_buttons** — Waybar module for window buttons with app icons, click actions, context menus, audio indicators (34 stars, GPL v3):  
  https://github.com/adelmonte/niri_window_buttons  
  *Evidence: Active development (v0.4.0 released March 2026). **Medium confidence.***

### Per-Workspace Taskbar (In Development)

- **Waybar PR #4581** — Per-workspace taskbar feature for Niri (open, active development):  
  https://github.com/Alexays/Waybar/pull/4581  
  Adds workspace class with Hyprland-style window taskbars, click-to-focus.  
  *Evidence: Open PR with commits, references issue #3745. **Medium confidence — in-progress but merging likely.***

### Features Checklist

| Feature | Status |
|---|---|
| Workspaces | ✅ Native, merged (Sept 2024) |
| Active window title | ✅ Native `niri/window` module |
| Custom commands/scripts | ✅ Via `on-click`, `on-update` in all modules |
| System tray | ✅ Built-in `tray` module (status notifier protocol) |
| Multiple monitors | ✅ `all-outputs` config option |
| Drag-to-reorder workspaces | Via custom modules (adelmonte/niri_workspaces) |
| Audio indicator per window | Via adelmonte/niri_window_buttons |
| Language indicator | ✅ Native `niri/language` module |

### Additional Evidence — Blog

- **LawnGnome blog** validates Waybar+Niri+Rust stack in production:  
  https://lawngno.me/blog/2025/03/06/niri.html  
  *Evidence: Real-world usage write-up from a Sway user migrating to Niri. **High confidence.***

- **Philip Molloy** notes Waybar wiki now includes Niri workspaces section:  
  https://philipmolloy.com/niri.html  
  *Evidence: Arch community documentation reference. **High confidence.***

---

## 2. Ironbar

**Repository:** https://github.com/JakeStanger/ironbar | 1.2K stars | Rust (GTK4)

### Niri Support Status

- **Issue #650** — Niri workspaces support request (closed as completed):  
  https://github.com/JakeStanger/ironbar/issues/650  
  Authored by community, closed by maintainer JakeStanger (June 2024).  
  *Evidence: Maintainer confirmation + implementation. **High confidence.***

- **v0.18.0 release** (Dec 2024) — workspaces rewrite merged:  
  https://github.com/JakeStanger/ironbar/releases  
  `3772f72 workspaces: impl niri client` — native Niri IPC client for workspaces.  
  *Evidence: Official release notes, v0.18 tag. **High confidence.***

- **Issue #1356** — Niri taskbar enhancement using official `niri-ipc` crate (open, Jan 2026):  
  https://github.com/JakeStanger/ironbar/issues/1356  
  Requests workspace-ordered taskbar via Niri IPC instead of wlr-foreign-toplevel.  
  *Evidence: Active feature request with maintainer engagement. **Medium confidence.***

- **Issue #1044** — Bug: workspace order not updating on Niri when rearranged (open):  
  https://github.com/JakeStanger/ironbar/issues/1044  
  *Evidence: Real bug report from Niri user with reproduction steps. **High confidence (bug exists).***

### Features Checklist

| Feature | Status |
|---|---|
| Workspaces | ✅ Native (v0.18+), Niri IPC client |
| Active window title | Via `clock`/`label` modules with custom scripts |
| Custom commands/scripts | ✅ Via `custom/menu` and `script` modules |
| System tray | ✅ `tray` module with click actions (v0.18) |
| GTK4 popups | ✅ (v0.18 breaking change) |

### Caveat

Ironbar switched from GTK3 to GTK4 in v0.18.0. Configuration may need style updates for popups. Popups now use native GTK popover widget.

---

## 3. Yambar

**Repository:** https://github.com/labiashiya/yambar | Tags: Yambar

### Niri Support Status

- **Discussion #1364** on Niri repo — Yambar workspaces module (community script):  
  https://github.com/YaLTeR/niri/discussions/1364  
  Community member `randoragon` wrote a shell script module for Yambar to display Niri workspaces with focus indicators.  
  *Evidence: Niri official repo discussion. **Medium confidence.***

### Features Checklist

| Feature | Status |
|---|---|
| Workspaces | ⚠️ Via community shell script (not native) |
| Active window title | Via shell script + Yambar text module |
| Custom commands/scripts | ✅ Shell script approach gives full flexibility |
| System tray | Via Yambar's `dbus` module (status notifier) |

### Caveat

Yambar has **no native Niri module**. All integration is via user-space shell scripts polling `niri msg` JSON output. This works but is polling-based rather than event-driven.

---

## 4. Eww (ElKowars Wacky Widgets)

**Repository:** https://github.com/elkowar/eww | Rust

### Niri Support Status

- **Reddit post** (r/niri, Sept 2025) — User `rashocean` asking about EWW setup for Niri bar + control center:  
  https://www.reddit.com/r/niri/comments/1nmie0v/help_me_with_eww_setup/  
  *Evidence: Community interest, no native integration. **Low confidence for native support.***

- **No official Eww Niri module** exists. Eww would need to use shell scripts polling `niri msg` (similar to Yambar approach) or IPC events if available.

### Features Checklist

| Feature | Status |
|---|---|
| Workspaces | ⚠️ Via shell script polling `niri msg -j workspaces` |
| Active window title | ⚠️ Via shell script polling |
| Custom commands/scripts | ✅ Eww's core strength — highly customizable |
| System tray | ⚠️ Via external scripts or dbus |

### Caveat

Eww is widget-focused and extremely flexible for custom UI, but **has no native Niri support**. All data must come from polling or custom IPC scripts. May be viable if you want a highly custom bar and are comfortable scripting.

---

## Summary Table

| Bar | Stars | Workspaces | Active Window | Custom Scripts | Tray | Niri Native? |
|---|---|---|---|---|---|---|
| **Waybar** | 11K | ✅ Merged | ✅ Merged | ✅ on-click/on-update | ✅ Built-in | ✅ Yes (maintainer-authored) |
| **Ironbar** | 1.2K | ✅ v0.18+ | ⚠️ Script | ✅ Script module | ✅ v0.18+ | ✅ Yes (IPC client) |
| **Yambar** | — | ⚠️ Shell script | ⚠️ Shell script | ✅ Shell script | ✅ dbus | ❌ No |
| **Eww** | — | ⚠️ Shell script | ⚠️ Shell script | ✅ Core feature | ⚠️ External | ❌ No |

---

## Recommendations

1. **Best overall: Waybar** — First-class Niri modules authored by Niri's own maintainer. The `niri/workspaces`, `niri/window`, and `niri/language` modules are in the core codebase. The `niri-taskbar` crate fills the per-workspace taskbar gap. Massive community (11K stars), extensive module ecosystem, system tray built-in, and the PR #4581 per-workspace taskbar is actively developing.

2. **Best GTK4 alternative: Ironbar** — Native Niri IPC client for workspaces landed in v0.18 (Dec 2024). GTK4-based, modern Rust codebase. Some bugs remain (workspace reorder, taskbar ordering) but active development. Good if you want a bar written entirely in Rust.

3. **For maximum customization: Eww** — If you want a fully custom bar with unusual layouts, Eww excels. But you'll be scripting all Niri data yourself with no native module support.

4. **Avoid for Niri: Yambar** — No native module; community workaround is shell-script polling. Viable but not as well-integrated as Waybar or Ironbar.

---

## Sources (chronological)

1. Waybar PR #3551 (merged Sept 2024) — YaLTeR adds native niri modules: https://github.com/Alexays/Waybar/pull/3551
2. Ironbar Issue #650 — Niri workspaces support request closed: https://github.com/JakeStanger/ironbar/issues/650
3. LawnGnome/niri-taskbar — Waybar taskbar for Niri: https://github.com/LawnGnome/niri-taskbar
4. LawnGnome blog — Niri + Waybar + Rust production use: https://lawngno.me/blog/2025/03/06/niri.html
5. Waybar PR #4581 — Per-workspace taskbar for Niri (open): https://github.com/Alexays/Waybar/pull/4581
6. Niri Discussion #1364 — Yambar workspaces module: https://github.com/YaLTeR/niri/discussions/1364
7. Ironbar v0.18.0 release notes: https://github.com/JakeStanger/ironbar/releases
8. Arch manual — waybar-niri-workspaces(5): https://man.archlinux.org/man/extra/waybar/waybar-niri-workspaces.5.en
9. justbuchanan/waybar-niri-workspaces-enhanced: https://github.com/justbuchanan/waybar-niri-workspaces-enhanced
10. adelmonte/niri_window_buttons: https://github.com/adelmonte/niri_window_buttons
11. adelmonte/niri_workspaces: https://github.com/adelmonte/niri_workspaces
12. Ironbar Issue #1356 — Niri taskbar enhancement: https://github.com/JakeStanger/ironbar/issues/1356
13. Ironbar Issue #1044 — Workspace reorder bug on Niri: https://github.com/JakeStanger/ironbar/issues/1044
14. r/niri Reddit — EWW setup question: https://www.reddit.com/r/niri/comments/1nmie0v/help_me_with_eww_setup/
15. Philip Molloy — Learning Niri: https://philipmolloy.com/niri.html
16. awesome-niri bars section: https://github.com/Vortriz/awesome-niri/blob/main/README.md
