# Niri Wayland Bar Alternatives (2026 snapshot)

## Short answer

If "best integration with Niri" is the priority, **Waybar remains the reference point** right now because it has dedicated `niri/workspaces`, `niri/window`, and `niri/language` modules, plus mature custom-script support and a tray module.

Among modern alternatives, **Ironbar** is the strongest general-purpose contender but still advertises **partial Niri support**; **Eww** is highly flexible and can do almost anything through custom logic; **Yambar** is very light/efficient but currently lacks native Niri integration and relies on scripts.

## Ranked options for Niri

1. **Waybar (baseline / still strongest for Niri-specific features)**
2. **Ironbar (best modern alternative if you accept partial Niri support today)**
3. **Eww (most customizable, but more "build it yourself" than pre-integrated)**
4. **Yambar (lightweight and efficient, but weakest native Niri integration)**

## Feature comparison (requested focus areas)

| Bar | Workspaces (Niri) | Active window info | Tray/status modules | Custom commands/scripts | Key limitation vs Waybar |
|---|---|---|---|---|---|
| **Waybar** | Native `niri/workspaces` module | Native `niri/window` module | Native `tray` module (marked beta) + many status modules | Strong `custom/<name>` module with polling/JSON/click handlers | N/A (reference) |
| **Ironbar** | Has `Workspaces` module; Niri support exists but project says Niri is partial | Has `Focused` module; Niri behavior depends on partial support level | Has `Tray`, notifications, network, volume, etc. modules | Strong script/event model (`on_click_*`, script modules, dynamic values) | Niri integration breadth lags Waybar's dedicated Niri module set |
| **Eww** | No known native Niri workspaces module; implement via `deflisten`/`defpoll` + `niri msg` scripts | No native Niri window module; script-driven | Has `systray` widget | Very high flexibility (`defpoll`, `deflisten`, widget/event commands) | More engineering effort; less out-of-box compositor-specific integration |
| **Yambar** | No native Niri module documented; community scripts use `niri msg -j` | Script-based only | No dedicated tray module in listed built-ins | Has `script` module | Missing native Niri integration and broader built-in module ecosystem |

## Concrete findings

### 1) Waybar is currently best integrated with Niri

- Waybar has dedicated Niri modules (`niri/workspaces`, `niri/window`, `niri/language`) in official docs.
- `niri/workspaces` includes output scoping, icon mapping, click-to-switch, and `on-update` command hooks.
- `niri/window` exposes focused window title and app id formatting/rewrite support.
- Waybar's custom module supports polling, continuous scripts, JSON return, click/scroll hooks.
- Waybar tray exists, though wiki labels it "still in beta".

### 2) Known Niri limitations inside Waybar itself

- In the original Niri module implementation PR, maintainers note omitted features for Niri compared with Sway/Hyprland behavior (e.g., workspace module built-in window list omission; persistent workspaces/sorting omitted due Niri's dynamic model).
- There is an open PR for richer per-workspace taskbar-like behavior in Niri workspaces, indicating active but still-evolving parity work.

### 3) Ironbar is the most realistic "modern alternative" today

- Ironbar positions itself as feature-rich GTK4 panel with many built-in modules.
- README explicitly says: "First-class support for Sway and Hyprland, and partial support for Niri".
- Project issue tracking Niri support/workspaces is closed via linked PR, so Niri support has progressed beyond the earlier "not supported" state.
- Configuration docs show deep event/script hooks and monitor-aware composition, so custom integration work is feasible.

### 4) Eww is powerful but compositor integration is mostly DIY

- Eww is WM-independent and excellent for custom interfaces.
- It supports polling and listening variables (`defpoll`, `deflisten`), which are ideal for wiring Niri IPC/event streams.
- It includes a `systray` widget and command hooks on interactive widgets.
- Trade-off: you implement Niri workspace/window behavior yourself instead of using dedicated built-in Niri modules.

### 5) Yambar remains lightweight but least native for Niri

- Yambar emphasizes lightweight/efficient design and has many built-ins, but listed modules do not include Niri.
- A Niri community discussion explicitly states there is no native Niri module and shows shell-script workaround using `niri msg -j workspaces/windows/focused-output/event-stream`.
- This confirms feasibility via scripts, but lower out-of-box Niri ergonomics than Waybar (and likely Ironbar).

## Practical recommendation

- If your goal is **best Niri integration right now**, keep Waybar as baseline.
- If you want a **modern alternative with richer panel UX** and can tolerate partial-Niri edges, test Ironbar first.
- Choose Eww only if you want to own custom widget logic; choose Yambar if minimal resource usage matters more than native Niri features.

## Sources (concrete URLs)

- Waybar Niri module wiki: https://github.com/Alexays/Waybar/wiki/Module:-Niri
- Waybar Niri workspaces man page (Arch): https://man.archlinux.org/man/extra/waybar/waybar-niri-workspaces.5.en
- Waybar tray module wiki: https://github.com/Alexays/Waybar/wiki/Module:-Tray
- Waybar custom module wiki: https://github.com/Alexays/Waybar/wiki/Module:-Custom
- Waybar PR adding Niri modules + noted omissions: https://github.com/Alexays/Waybar/pull/3551
- Waybar PR for Niri per-workspace taskbar feature (open): https://github.com/Alexays/Waybar/pull/4581
- Ironbar README (feature/support statement): https://github.com/JakeStanger/ironbar
- Ironbar Niri support issue (closed): https://github.com/JakeStanger/ironbar/issues/650
- Ironbar configuration guide (script/events/module model): https://github.com/JakeStanger/ironbar/wiki/Configuration-guide
- Eww docs home (WM-independent): https://elkowar.github.io/eww
- Eww configuration (`defpoll`, `deflisten`): https://elkowar.github.io/eww/configuration.html
- Eww widgets (`systray`, click hooks): https://elkowar.github.io/eww/widgets.html
- Yambar README/modules: https://github.com/neonkore/yambar
- Niri discussion showing Yambar script workaround: https://github.com/YaLTeR/niri/discussions/1364
