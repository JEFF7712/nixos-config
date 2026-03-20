# Wayland Bar Alternatives to Waybar — Niri Suitability Research

**Date:** 2026-03-19  
**Scope:** Mature Wayland bars commonly suggested as alternatives to Waybar, evaluated for use with Niri (wayland-native IPC compositor). Focus on tray/status modules, custom commands, active window info, workspace support, and known limitations.

---

## TL;DR

| Bar | Tray | Custom Commands | Active Window | Niri Workspaces | Niri-Specific Support | Maturity |
|-----|------|---------------|---------------|-----------------|----------------------|-----------|
| **Yambar** | ❌ No native | ✅ `script` module | ❌ No dedicated module | 🔧 Community script workaround | ❌ No native niri module | High (C, stable) |
| **Ironbar** | ✅ Yes | ✅ Executors | ✅ `window` module | ⚠️ Partial (no IPC) | ❌ Not officially documented | High (Rust, active) |
| **Eww** | ❌ No native | ✅ Custom Rust widgets | ✅ Custom via IPC | 🔧 Via IPC scripts | ❌ No native niri support | High (Rust, very active) |
| **Quickshell** | ✅ Qt system tray | ✅ QML scripting | ✅ QML APIs | ✅ Via scripting | ❌ No native niri support | High (Qt/C++, active) |
| **nwg-panel** | ✅ Yes | ✅ Executors | ❌ No | ❌ Hyprland/Sway only | ❌ No niri support | High (Python, Hyprland/Sway only) |
| **Riftbar** | ❌ No (WIP) | ❌ Limited | ✅ Yes | ❌ Hyprland-focused | ❌ Hyprland only | Low (new, <2 months old) |

**Key Finding:** Waybar is currently the only bar with **native Niri support** (workspaces, focused window, language). All alternatives require workarounds, custom scripts, or IPC hacks. The Niri ecosystem is still young.

---

## 1. Waybar (Baseline)

**Repo:** https://github.com/Alexays/Waybar | ⭐ 10.9k stars | C++/GTK  
**Latest:** v0.15.0 (2026-02-06) | 1362 open issues | Actively maintained

### Native Niri Modules
Waybar ships with native niri support built-in:

- **`niri/workspaces`** — displays workspaces with index/name, supports `current-only`, `all-outputs`, click-to-focus, per-workspace taskbar (PR #4581 merged late 2025)
- **`niri/focused-window`** — shows active window title/class
- **`niri/language`** — shows keyboard layout

### General Features
- Tray via GTK system tray (SNITE protocol)
- Custom scripts via `custom/` modules
- 410 contributors, largest community by far
- NixOS/home-manager support via dedicated module

### Known Limitations (General)
- Rust compilation times can be long
- GTK3 dependency (heavy for a status bar)
- JSONC config can be verbose
- 1362 open issues (busy bug tracker)

**Evidence:** Project README — https://github.com/Alexays/Waybar

---

## 2. Yambar

**Repo:** https://codeberg.org/dnkl/yambar | C | MIT License  
**Latest:** Active development | No native tray

### Modules Available (per docs)
```
alsa, backlight, battery, clock, cpu, disk-io, dwl, foreign-toplevel,
i3/sway, label, mem, mpd, network, pulse, removables, river, script, sway-xkb
```

### Niri Support: ⚠️ WORKAROUND REQUIRED
**Source:** GitHub Discussion — https://github.com/YaLTeR/niri/discussions/1364

User `randoragon` created a **community shell-script module** for niri workspaces. The script reads niri's JSON IPC to get workspace state. This is NOT a native module — it's a workaround using the `script` module.

Key limitation from discussion:
> "Yambar is my status bar of choice, but unfortunately there is no native niri module, so I hacked my own with a shell script."

### Tray Support
**Yambar explicitly has NO tray support.** This is a fundamental design choice. The maintainer prioritizes minimalism and CPU efficiency over feature completeness.

**Evidence:** Project README — https://raw.githubusercontent.com/neonkore/yambar/master/README.md
> "There is **no** support for images or icons."

### Custom Commands / Scripting
✅ The `script` module can execute arbitrary shell commands and parse output. This is how community workarounds for missing compositor integrations are built.

### Active Window
❌ No dedicated active window module. The `foreign-toplevel` module can track windows managed by *other* compositors, but not niri windows natively.

### Known Limitations vs Waybar
1. No tray support (deal-breaker for many users)
2. No native niri module (must use IPC workaround scripts)
3. No active window module
4. No images/icons (use icon fonts only)
5. Smaller community (30 contributors vs Waybar's 410)

**Evidence:** Project docs (README), GitHub discussion #1364

---

## 3. Ironbar

**Repo:** https://github.com/Ironbar/ironbar | Rust | MIT License  
**Active as of 2026**

### Key Features
- Written in Rust (same language as Niri)
- GTK4-based
- System tray support
- Customizable via TOML config
- Executors for custom commands
- `window` module for active window info

### Niri Support
❌ **No official niri support.** Ironbar officially supports: **Hyprland, Sway, River, dwl, Qtile**. Niri is not listed.

**Source:** Project README — https://github.com/Ironbar/ironbar (based on search results)

### Tray Support
✅ Yes. Discussion confirms: "Ironbar's tray code is available as a crate."

### Custom Commands
✅ Executors support arbitrary shell commands.

### Active Window
✅ The `window` module provides active window info.

### Known Limitations vs Waybar
1. No niri compositor support (no workspaces, no focused window)
2. No official documentation for niri users
3. Smaller community than Waybar
4. GTK4 only (may have compatibility considerations)

**Evidence:** Reddit r/hyprland discussions (2026)

---

## 4. Eww (Elkowars Wacky Widgets)

**Repo:** https://github.com/elkowar/eww | ⭐ 3.4k stars | Rust | MIT License

### Architecture
Eww is a **widget system** rather than a traditional bar. You write custom Rust widgets and define them in a DSL. It doesn't ship with pre-built modules — you build everything yourself.

### Niri Support
❌ **No native niri support.** Eww is compositor-agnostic via generic window/window-name variables, but nothing specific to niri's IPC protocol.

### Tray Support
❌ **No built-in tray.** Eww's architecture doesn't include a system tray widget. You could potentially build one via custom commands, but it's not provided.

### Custom Commands
✅ **Extremely flexible.** Since everything is custom Rust widgets, you can run any command, parse any output, and display it however you want. This is both Eww's strength and weakness — it requires significant coding.

### Active Window
✅ Via `window` variable in the widget DSL.

### Workspace Support
⚠️ Via IPC scripting. You can write scripts to query niri's socket and display workspace info. No pre-built module.

### Known Limitations vs Waybar
1. No tray (requires building custom widget)
2. No niri-native workspace module
3. **High learning curve** — you code widgets in Rust DSL, not configure JSON
4. No NixOS/home-manager module in mainline
5. Documentation quality varies

**Evidence:** AlternativeTo listing, Eww project documentation

---

## 5. Quickshell

**Repo:** https://github.com/Quickshell/Quickshell | LGPL-3.0

### Architecture
QtQuick-based toolkit for building status bars, widgets, lockscreens. Targets both Wayland and X11.

### Niri Support
❌ No specific niri support. However, QtQuick provides lower-level access to Wayland protocols, so compositor-agnostic scripting is possible.

### Tray Support
✅ Qt system tray integration is available.

### Custom Commands / Scripting
✅ QML scripting with full JavaScript support. Very programmable.

### Active Window / Workspaces
✅ Via Qt APIs and scripting. Qt provides compositor-agnostic window management.

### Known Limitations vs Waybar
1. No niri-specific integration
2. Qt dependency (heavy)
3. Less community documentation than Waybar
4. NixOS support less mature

**Evidence:** AlternativeTo, SaaSHub competitor listing

---

## 6. nwg-panel

**Repo:** https://github.com/nwg-piotr/nwg-panel | ⭐ 768 stars | Python | MIT

### Key Features
- GTK3-based
- Graphical configuration tool (no manual config editing needed)
- Controls module (brightness, volume, battery)
- System tray support
- Executors for custom commands
- 139 releases, very mature

### Niri Support
❌ **Only supports Sway and Hyprland.** No niri support.

**Source:** Project README — https://github.com/nwg-piotr/nwg-panel
> "nwg-panel is a GTK3-based panel for sway and Hyprland Wayland compositors."

### Known Limitations vs Waybar
1. No niri support (fundamental)
2. Python-based (heavier than Rust/C alternatives)
3. Configuration via GUI tool (less reproducible for NixOS)

**Evidence:** Project README

---

## 7. Riftbar

**Repo:** Mentioned on Reddit r/hyprland (2026-02-20)

### Key Info
- Rust + GTK4
- Very new (~2 months old as of 2026-02)
- Written specifically for Hyprland

### Niri Support
❌ No. Hyprland-only.

### Tray Support
❌ No. The author explicitly stated:
> "without system tray not good. Tray is very important"

**Source:** Reddit r/hyprland discussion — https://www.reddit.com/r/hyprland/comments/1qkx1wm/riftbar_waybar_replacement_written_with_rust_and/

**Evidence:** Reddit discussion (community feedback)

---

## 8. Hyprpanel

**Mentioned in Reddit r/hyprland (2026-03-06)**

Not a standalone project — it's part of the hyprland ecosystem. Comments suggest it "just works" out of the box but offers less customization than Waybar.

**Evidence:** Reddit r/hyprland discussion — https://www.reddit.com/r/hyprland/comments/1rltqbw/any_alternatives_to_waybar_that_dont_actually_suck/

---

## Niri-Specific Ecosystem (Waybar Add-ons)

Since no alternative bar has native niri support, the community has built Waybar extensions:

### waybar-niri-workspaces-enhanced
**Repo:** https://github.com/justbuchanan/waybar-niri-workspaces-enhanced | ⭐ 14 stars | MIT

Shows icons for running programs in each workspace. Uses niri's IPC. NixOS/home-manager integration provided.

### waybar-niri-taskbar (LawnGnome)
**Repo:** https://github.com/LawnGnome/niri-taskbar | ⭐ 125 stars | MIT

Per-workspace taskbar for Waybar. Windows ordered by workspace index. Requires:
- Waybar 0.12.0+
- Niri 25.05+
- Rust 1.87.0+

**Evidence:** Project README

### waybar-niri-taskbar (cookiekop PR)
**PR:** https://github.com/Alexays/Waybar/pull/4581

Per-workspace taskbar feature merged into Waybar itself (late 2025). This brings Waybar's niri workspace module closer to Hyprland's taskbar functionality.

---

## Summary & Recommendations for Niri Users

### If you use Niri:
1. **Waybar is your best and only practical option** with native niri module support (workspaces, focused window, language, taskbar).
2. **Yambar** is a solid bar but requires a community shell-script workaround for workspaces, has no tray, and no active window module. Best for minimalism-focused users who can live without tray.
3. **Ironbar/Eww** are great general-purpose bars but offer zero niri-specific functionality. You'd lose workspace and active window support entirely.
4. The **niri-taskbar** Waybar plugins fill the remaining gaps (per-workspace taskbars, enhanced workspace icons).

### Key Pain Points of Alternatives (vs Waybar):
| Issue | Waybar | Alternatives |
|-------|--------|---------------|
| Native Niri workspaces | ✅ | ❌ All |
| Native Niri focused window | ✅ | ❌ All |
| System tray | ✅ | ❌ Yambar, Eww; ✅ Ironbar, Quickshell, nwg-panel |
| Niri taskbar | ✅ (via plugins) | ❌ All |
| Maturity & community | 10.9k stars | Ironbar (3k), Eww (3.4k), Yambar (33 stars) |

### Limitations Relative to Waybar (all alternatives):
1. **No native niri support** — this is the biggest gap. Niri's IPC protocol isn't widely supported.
2. **Smaller communities** — fewer contributors, less documentation, fewer third-party plugins.
3. **Yambar has no tray** — fundamental limitation, no roadmap to add it.
4. **Eww requires coding** — not a config file; you write Rust widgets.
5. **nwg-panel is Hyprland/Sway only** — explicitly incompatible with niri.

---

## Sources

### Project Documentation
- Waybar README: https://github.com/Alexays/Waybar
- Yambar README: https://raw.githubusercontent.com/neonkore/yambar/master/README.md
- nwg-panel README: https://github.com/nwg-piotr/nwg-panel
- waybar-niri-taskbar (LawnGnome): https://github.com/LawnGnome/niri-taskbar
- waybar-niri-workspaces-enhanced: https://github.com/justbuchanan/waybar-niri-workspaces-enhanced

### Discussions & Issues
- Yambar niri workspaces discussion: https://github.com/YaLTeR/niri/discussions/1364
- Waybar niri taskbar PR: https://github.com/Alexays/Waybar/pull/4581
- Waybar alternatives (Reddit): https://www.reddit.com/r/hyprland/comments/1rltqbw/any_alternatives_to_waybar_that_dont_actually_suck/
- Riftbar (Reddit): https://www.reddit.com/r/hyprland/comments/1qkx1wm/riftbar_waybar_replacement_written_with_rust_and/

### Listings & Comparisons
- AlternativeTo Waybar: https://alternativeto.net/software/waybar/
- nwg-panel alternatives: https://www.saashub.com/nwg-panel-alternatives
- Arch manual waybar-niri-workspaces: https://man.archlinux.org/man/extra/waybar/waybar-niri-workspaces.5.en
