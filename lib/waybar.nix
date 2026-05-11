# Shared waybar configuration helpers for desktop profiles.
#
# Three visual styles:
#   - "flat": transparent background with underline workspace indicators
#   - "floating": separated translucent module islands with dot workspaces
#   - "pill": one unified rounded bar with dot workspaces
#
# Current profile usage:
#   - Catppuccin, Rose Pine: pill
#   - Everforest, Gruvbox, Nord: floating islands
#   - Minimal: flat
#
# Usage from a profile:
#   let waybar = import ../../../lib/waybar.nix;
#   in {
#     waybar.config = waybar.mkConfig { floating = true; pill = true; };
#     waybar.style = waybar.mkPillStyle { ... };
#   }

{
  # ── Shared JSON config (modules, formats, icons) ──────────────────────
  # Set floating = true for both pill and island styles to use dot workspace
  # icons. Set pill = true for the thinner unified bar with screen margins.
  mkConfig =
    {
      floating ? false,
      pill ? false,
      scriptDir ? "/home/rupan/nixos/home/scripts",
    }:
    ''
      {
        "layer": "top",
        "height": ${
          if pill then
            "30"
          else if floating then
            "42"
          else
            "28"
        },
        ${
          if pill then
            ''
              "margin-top": 8,
                      "margin-left": 40,
                      "margin-right": 40,''
          else
            ""
        }
        "modules-left": [
          "niri/workspaces",
          "power-profiles-daemon",
          "cpu",
          "memory",
          "disk"
        ],
        "modules-center": [
          "clock"
        ],
        "custom/media": {
          "exec": "${scriptDir}/waybar-media",
          "return-type": "json",
          "interval": 5
        },
        "clock": {
          "interval": 30,
          "format": "{:%I:%M %p}",
          "tooltip-format": "{:%a, %d %b %G}"
        },
        "modules-right": [
          "backlight",
          "pulseaudio",
          "bluetooth",
          "network",
          "battery"
        ],
        "niri/window": { "max-length": 30 },
        "tray": { "icon-size": 20, "spacing": 8 },
        "backlight": {
          "format": "󰃠 {percent}%",
          "on-scroll-up": "brightnessctl set 5%+",
          "on-scroll-down": "brightnessctl set 5%-",
          "tooltip": false
        },
        "pulseaudio": {
          "format-source": "󰍬",
          "format-source-muted": "󰍭",
          "format": "{format_source} 󰕾 {volume}%",
          "format-bluetooth": "{format_source} 󰂰 {volume}%",
          "format-muted": "{format_source} 󰸈",
          "on-click": "pavucontrol",
          "max-volume": 150,
          "scroll-step": 1
        },
        "bluetooth": {
          "format": "",
          "format-disabled": "",
          "format-off": "",
          "format-on": "󰂯",
          "format-connected": "󰂱 {device_alias}",
          "on-click": "blueman-manager",
          "max-length": 16
        },
        "network": {
          "format": "{ifname}",
          "format-wifi": "󰖩 {essid}",
          "format-ethernet": "󰈀 {ipaddr}",
          "format-disconnected": "Disconnected",
          "on-click": "kitty -e sudo nmtui",
          "max-length": 32
        },
        "battery": {
          "interval": 60,
          "states": {
            "warning": 20,
            "critical": 10
          },
          "format-time": "{H}:{m}",
          "format-icons": ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"],
          "format-discharging": "{icon} {capacity}% ({time})",
          "format-charging": "󰂄 {capacity}%",
          "format": ""
        },
        "disk": {
          "interval": 30,
          "format": "󰋊 {percentage_used}%",
          "path": "/",
          "tooltip-format": "{used} / {total} ({percentage_used}%)"
        },
        "niri/workspaces": {
          "format": "{icon}",
          "on-click": "activate",
          "format-icons": {
            ${
              if floating then
                ''
                  "1": "","2": "","3": "","4": "","5": "",
                              "6": "","7": "","8": "","9": "","10": ""''
              else
                ''
                  "1": "󰝥","2": "󰝥","3": "󰝥","4": "󰝥","5": "󰝥",
                              "6": "󰝥","7": "󰝥","8": "󰝥","9": "󰝥","10": "󰝥"''
            }
          },
          "persistent-workspaces": {
            "1": [],"2": [],"3": [],"4": [],"5": [],
            "6": [],"7": [],"8": [],"9": [],"10": []
          },
          "sort-by-number": true
        },
        "power-profiles-daemon": {
          "format": "{icon}",
          "tooltip-format": "Power profile: {profile}\nDriver: {driver}",
          "format-icons": {
            "default": "󰾆",
            "performance": "󱐌",
            "balanced": "󰾆",
            "power-saver": "󰾄"
          }
        },
        "cpu": { "interval": 3, "format": "󰻠 {usage}%", "tooltip": false },
        "memory": {
          "interval": 3,
          "format": "󰍛 {percentage}%",
          "tooltip-format": "{used:0.1f}G / {total:0.1f}G"
        }
      }
    '';

  # ── Flat style (transparent bar, underline workspace indicators) ──────
  mkFlatStyle =
    {
      fg, # main text color
      activeText, # active workspace text color
      activeUnderline, # active workspace underline color
      clockColor, # clock text color
      performanceColor, # power-profiles performance
      balancedColor, # power-profiles balanced
      powerSaverColor, # power-profiles power-saver
      warningColor ? criticalColor, # battery warning
      criticalColor, # battery critical
      hoverBg ? "rgba(255,255,255,0.05)", # workspace hover background
    }:
    ''
      * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-height: 0; }
      window#waybar { background-color: transparent; color: ${fg}; }
      .modules-left, .modules-center, .modules-right { padding: 0 4px; }
      #workspaces { padding: 0 4px; }
      #workspaces button { padding: 0 8px; background: transparent; color: ${fg}; border-bottom: 2px solid transparent; }
      #workspaces button.active { color: ${activeText}; border-bottom: 2px solid ${activeUnderline}; }
      #workspaces button:hover { background: ${hoverBg}; color: ${fg}; }
      #clock { color: ${clockColor}; font-weight: bold; }
      #custom-media, #backlight, #battery, #bluetooth, #network, #pulseaudio, #tray { color: ${fg}; padding: 0 8px; }
      #cpu, #memory, #disk { color: ${fg}; padding: 0 8px; }
      #power-profiles-daemon { color: ${fg}; padding: 0 8px; }
      #power-profiles-daemon.performance { color: ${performanceColor}; }
      #power-profiles-daemon.balanced { color: ${balancedColor}; }
      #power-profiles-daemon.power-saver { color: ${powerSaverColor}; }
      #battery.warning { color: ${warningColor}; }
      #battery.critical { color: ${criticalColor}; }
    '';

  # ── Floating style (separated translucent module islands) ─────────────
  mkFloatingStyle =
    {
      windowBg, # window background (rgba string)
      primary, # primary accent color
      borderColor, # border color
      shadowColor, # box-shadow rgba string
      activeBg, # active workspace background
      hoverColor ? primary, # workspace hover text color
      clockColor ? primary, # clock text color
      textColor ? primary, # general element text color (pulseaudio, etc.)
      performanceColor, # power-profiles performance
      balancedColor, # power-profiles balanced
      powerSaverColor, # power-profiles power-saver
      warningColor ? criticalColor, # battery warning
      criticalColor, # battery critical
    }:
    ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        all: unset;
        background-color: transparent;
        color: ${primary};
      }

      .modules-left,
      .modules-center,
      .modules-right {
        padding: 7px;
        margin-top: 10px;
        margin-bottom: 5px;
        border-radius: 10px;
        background: ${windowBg};
        border: 1px solid ${borderColor};
        box-shadow: 0 0 2px ${shadowColor};
      }

      .modules-left { margin-left: 10px; }
      .modules-right { margin-right: 10px; }

      tooltip {
        background: ${windowBg};
        color: ${textColor};
        border: 1px solid ${borderColor};
        border-radius: 8px;
      }

      #workspaces { padding: 0 5px; }

      #workspaces button {
        all: unset;
        padding: 0 5px;
        background: transparent;
        color: ${activeBg};
        transition: all 0.2s ease;
      }

      #workspaces button.active {
        color: ${primary};
        text-shadow: 0 0 2px ${shadowColor};
      }

      #workspaces button.empty {
        color: transparent;
        text-shadow: 0 0 1.5px ${shadowColor};
      }

      #workspaces button:hover,
      #workspaces button.empty:hover {
        color: ${hoverColor};
        text-shadow: 0 0 2px ${shadowColor};
        transition: all 0.3s ease;
      }

      #clock {
        color: ${clockColor};
        font-weight: bold;
        padding: 0 5px;
        transition: all 0.3s ease;
      }

      #custom-media,
      #backlight,
      #pulseaudio,
      #bluetooth,
      #network,
      #battery,
      #tray,
      #cpu,
      #memory,
      #disk,
      #language {
        color: ${textColor};
        padding: 0 5px;
        transition: all 0.3s ease;
      }

      #clock:hover,
      #custom-media:hover,
      #backlight:hover,
      #pulseaudio:hover,
      #bluetooth:hover,
      #network:hover,
      #battery:hover,
      #tray:hover,
      #cpu:hover,
      #memory:hover,
      #disk:hover,
      #power-profiles-daemon:hover {
        color: ${hoverColor};
      }

      #power-profiles-daemon {
        color: ${textColor};
        padding: 0 5px;
        transition: all 0.3s ease;
      }

      #power-profiles-daemon.performance { color: ${performanceColor}; }
      #power-profiles-daemon.balanced { color: ${balancedColor}; }
      #power-profiles-daemon.power-saver { color: ${powerSaverColor}; }
      #battery.warning { color: ${warningColor}; }
      #battery.critical { color: ${criticalColor}; }
    '';

  # ── Pill style (single unified rounded bar) ───────────────────────────
  mkPillStyle =
    {
      windowBg, # window background (rgba string)
      primary, # primary accent color
      borderColor, # border color
      shadowColor, # box-shadow rgba string
      activeBg, # active workspace background
      hoverColor ? primary, # workspace hover text color
      clockColor ? primary, # clock text color
      textColor ? primary, # general element text color (pulseaudio, etc.)
      performanceColor, # power-profiles performance
      balancedColor, # power-profiles balanced
      powerSaverColor, # power-profiles power-saver
      warningColor ? criticalColor, # battery warning
      criticalColor, # battery critical
    }:
    ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: ${windowBg};
        color: ${primary};
        border: 1px solid ${borderColor};
        border-radius: 999px;
        box-shadow: 0 10px 30px ${shadowColor};
      }

      .modules-left,
      .modules-center,
      .modules-right {
        padding: 0 10px;
      }

      tooltip {
        background: ${windowBg};
        color: ${textColor};
        border: 1px solid ${borderColor};
        border-radius: 10px;
      }

      #workspaces { padding: 0 2px; }

      #workspaces button {
        padding: 0 10px;
        margin: 0 2px;
        background: transparent;
        color: ${primary};
        border-radius: 999px;
        border-bottom: 2px solid transparent;
        transition: all 0.2s ease;
      }

      #workspaces button.active {
        color: ${primary};
        background: ${activeBg};
      }

      #workspaces button:hover {
        background: ${activeBg};
        color: ${hoverColor};
      }

      #clock {
        color: ${clockColor};
        font-weight: bold;
        padding: 0 10px;
      }

      #custom-media,
      #backlight,
      #pulseaudio,
      #bluetooth,
      #network,
      #battery,
      #tray,
      #cpu,
      #memory,
      #disk,
      #language {
        color: ${textColor};
        padding: 0 10px;
      }

      #clock:hover,
      #custom-media:hover,
      #backlight:hover,
      #pulseaudio:hover,
      #bluetooth:hover,
      #network:hover,
      #battery:hover,
      #tray:hover,
      #cpu:hover,
      #memory:hover,
      #disk:hover,
      #power-profiles-daemon:hover {
        color: ${hoverColor};
      }

      #power-profiles-daemon {
        color: ${textColor};
        padding: 0 10px;
      }

      #power-profiles-daemon.performance { color: ${performanceColor}; }
      #power-profiles-daemon.balanced { color: ${balancedColor}; }
      #power-profiles-daemon.power-saver { color: ${powerSaverColor}; }
      #battery.warning { color: ${warningColor}; }
      #battery.critical { color: ${criticalColor}; }
    '';
}
