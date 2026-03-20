# Modern Waybar Alternatives (Wayland, daily-driver focus)

Date: 2026-03-20

Scope: Active projects that can realistically replace Waybar for a daily Linux Wayland desktop. I prioritized projects with recent releases/commits, docs, and practical module coverage.

## 1) Ironbar

- Project: Ironbar
- Stack/tech: Rust + GTK4 + `gtk-layer-shell`
- Config style: Declarative config (multiple supported formats) + CSS styling + optional Lua/custom widgets
- Maturity/activity: Active, large codebase and contributor set; GitHub shows ~1.2k stars, 2k+ commits, latest release `v0.18.0` (2025-12-17)
- Strengths:
  - Designed as a full-featured panel, not just a thin bar
  - Explicit Hyprland/Sway support and documented partial Niri support
  - Rich module ecosystem, popups, script integration, hot-loaded CSS
  - Good Nix/Home Manager integration path shown in upstream docs
- Weaknesses:
  - Upstream labels project as alpha (breaking changes possible)
  - More moving parts than lightweight bars
  - Migration from Waybar modules requires remapping and testing
- Source URLs:
  - https://github.com/JakeStanger/ironbar
  - https://github.com/JakeStanger/ironbar/wiki/configuration-guide

## 2) Quickshell

- Project: Quickshell
- Stack/tech: Qt/QtQuick (QML) toolkit, C++ core, Wayland/X11 support
- Config style: QML code-based shell config, live reload, LSP support
- Maturity/activity: Active and fast-moving; GitHub mirror shows ~2.2k stars, latest release `0.2.1` (2025-10-12), hundreds of commits
- Strengths:
  - Very modern architecture for full shell components (bar/widgets/lockscreen)
  - Excellent for highly custom setups and reusable UI components
  - Strong integration story for Hyprland/Wayland ecosystems
- Weaknesses:
  - Higher complexity than Waybar (you are building with QML, not only toggling modules)
  - Bigger migration effort for existing Waybar JSON/CSS setups
  - Better for users who want a shell toolkit, not only a quick bar swap
- Source URLs:
  - https://quickshell.outfoxxed.me/
  - https://github.com/quickshell-mirror/quickshell

## 3) AGS (Aylur's GTK Shell)

- Project: AGS (v2 ecosystem)
- Stack/tech: JavaScript/TypeScript shell tooling around GTK/GJS ecosystem (Astal/Gnim based workflow in current upstream)
- Config style: Code-driven (JS/TS) widgets + CSS styling
- Maturity/activity: Active community and releases; GitHub shows ~3k stars, latest release `v3.1.1` (2025-12-14)
- Strengths:
  - Popular in custom Wayland desktop setups
  - Highly flexible: can replace bar plus other desktop UI pieces
  - Strong examples ecosystem for advanced visual customization
- Weaknesses:
  - Bigger conceptual jump from Waybar module config
  - Requires comfort with coding shell UI rather than simple config edits
  - Version shifts can require adapting configs
- Source URLs:
  - https://github.com/Aylur/ags
  - https://aylur.github.io/ags/

## 4) Eww (ElKowars Wacky Widgets)

- Project: Eww
- Stack/tech: Rust engine + GTK widgets
- Config style: Yuck DSL + CSS
- Maturity/activity: Mature and widely used; GitHub shows ~12k stars, active commits through 2026, latest tagged release `v0.6.0` (2024-04-21)
- Strengths:
  - Huge user base and many real-world examples
  - Very flexible for handcrafted bars/widgets
  - Good fit if you want custom visuals and control
- Weaknesses:
  - Not a drop-in Waybar equivalent; you build many pieces yourself
  - Can become script-heavy and harder to maintain over time
  - Some examples rely on legacy syntax; config quality varies across dotfiles
- Source URLs:
  - https://github.com/elkowar/eww
  - https://elkowar.github.io/eww/

## 5) nwg-panel

- Project: nwg-panel
- Stack/tech: Python + GTK3 (part of nwg-shell ecosystem)
- Config style: GUI configurator + JSON-style config files; many built-in modules
- Maturity/activity: Active and practical; GitHub shows ~768 stars, 1.6k+ commits, latest release `0.10.13` (2025-11-27)
- Strengths:
  - Very practical daily-driver panel for Sway/Hyprland users
  - Includes tray, workspaces, taskbar, weather, media, custom executors
  - Lower effort than full shell toolkits for users who want results quickly
- Weaknesses:
  - More opinionated than Waybar and less minimal
  - GTK3 stack may feel less future-facing than newer GTK4/QtQuick projects
  - Ecosystem is centered on nwg-shell conventions
- Source URLs:
  - https://github.com/nwg-piotr/nwg-panel
  - https://nwg-piotr.github.io/nwg-shell

---

## Practical takeaway (replacement realism)

- Closest "daily panel" replacement with modern momentum: **Ironbar**
- Most future-facing toolkit if you want to build a shell, not just a bar: **Quickshell**
- Best for highly customized code-first shells in GTK/GJS world: **AGS**
- Most established widget framework with giant community examples: **Eww**
- Fastest practical migration for feature-rich panel behavior: **nwg-panel**

## Excluded from recommended active set

- **Yambar** was historically strong, but upstream README now says it is no longer developed; this makes it a risky new adoption for a long-term daily setup.
- Source: https://codeberg.org/dnkl/yambar
