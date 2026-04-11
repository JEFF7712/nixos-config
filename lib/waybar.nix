# Shared waybar configuration helpers for desktop profiles.
#
# Two visual styles:
#   - "floating" (catppuccin, rosepine): pill-shaped, semi-transparent, bordered
#   - "flat" (nord, gruvbox, everforest): transparent background, underline indicators
#
# Usage from a profile:
#   let waybar = import ../../../lib/waybar.nix;
#   in { waybar.config = waybar.mkConfig { floating = true; }; ... }

{
  # ── Shared JSON config (modules, formats, icons) ──────────────────────
  # The only layout difference is height + margins for floating style.
  mkConfig =
    {
      floating ? false,
    }:
    ''
      {
        "layer": "top",
        "height": ${if floating then "30" else "28"},
        ${
          if floating then
            ''
              "margin-top": 5,
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
          "on-click": "kitty sudo nmtui",
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
            "1": "󰝥","2": "󰝥","3": "󰝥","4": "󰝥","5": "󰝥",
            "6": "󰝥","7": "󰝥","8": "󰝥","9": "󰝥","10": "󰝥"
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
      #backlight, #battery, #bluetooth, #network, #pulseaudio, #tray { color: ${fg}; padding: 0 8px; }
      #cpu, #memory, #disk { color: ${fg}; padding: 0 8px; }
      #power-profiles-daemon { color: ${fg}; padding: 0 8px; }
      #power-profiles-daemon.performance { color: ${performanceColor}; }
      #power-profiles-daemon.balanced { color: ${balancedColor}; }
      #power-profiles-daemon.power-saver { color: ${powerSaverColor}; }
      #battery.warning { color: ${warningColor}; }
      #battery.critical { color: ${criticalColor}; }
    '';

  # ── Floating style (pill-shaped, semi-transparent, bordered) ──────────
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
      * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-height: 0; }
      window#waybar {
        background-color: ${windowBg};
        color: ${primary};
        border: 1px solid ${borderColor};
        border-radius: 50px;
        box-shadow: 0 10px 30px ${shadowColor};
      }
      .modules-left, .modules-center, .modules-right { padding: 0 10px; }
      #workspaces { padding: 0px 2px; }
      #workspaces button {
        padding: 0 10px;
        margin: 0px 2px;
        background: transparent;
        color: ${primary};
        border-radius: 10px;
        border-bottom: 2px solid transparent;
      }
      #workspaces button.active {
        color: ${primary};
        background: ${activeBg};
      }
      #workspaces button:hover { background: ${activeBg}; color: ${hoverColor}; }
      #clock { color: ${clockColor}; font-weight: bold; padding: 0 10px; }
      #backlight, #pulseaudio, #bluetooth, #network, #battery, #tray, #cpu, #memory, #disk, #language {
        color: ${textColor};
        padding: 0 10px;
      }
      #power-profiles-daemon { color: ${textColor}; padding: 0 10px; }
      #power-profiles-daemon.performance { color: ${performanceColor}; }
      #power-profiles-daemon.balanced { color: ${balancedColor}; }
      #power-profiles-daemon.power-saver { color: ${powerSaverColor}; }
      #battery.warning { color: ${warningColor}; }
      #battery.critical { color: ${criticalColor}; }
    '';
}
