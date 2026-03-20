{ pkgs, ... }:

let
  # Everforest Dark Hard
  bg0    = "#272e33";
  bg1    = "#2e383c";
  bg2    = "#374145";
  bg3    = "#414b50";
  bg4    = "#495156";
  bg5    = "#4f5b58";
  fg     = "#d3c6aa";
  red    = "#e67e80";
  orange = "#e69875";
  yellow = "#dbbc7f";
  green  = "#a7c080";
  aqua   = "#83c092";
  blue   = "#7fbbb3";
  purple = "#d699b6";
  grey0  = "#7a8478";
  grey1  = "#859289";
  grey2  = "#9da9a0";
in {
  home.packages = [ pkgs.waybar pkgs.waypaper pkgs.rofi pkgs.python3Packages.pywal pkgs.mako ];

  xdg.configFile."mako/config".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color=${bg0}
    text-color=${fg}
    border-color=${green}
    border-size=2
    border-radius=8
    width=320
    padding=12
    margin=10
    default-timeout=5000
    icons=1
    max-icon-size=48
    layer=overlay

    [urgency=low]
    border-color=${bg4}
    default-timeout=3000

    [urgency=high]
    background-color=${bg1}
    border-color=${red}
    text-color=${fg}
    default-timeout=0
  '';

  desktopProfiles.profiles.everforest = {
    bar = "waybar";

    cursor = {
      theme = "Adwaita";
      size  = 24;
    };

    wallpaperDir = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/everforest";

    niri = {
      gaps               = 18;
      borderOff          = true;
      focusRingOff       = true;
      shadowSoftness     = 20;
      shadowSpread       = 3;
      shadowOffsetX      = 0;
      shadowOffsetY      = 4;
      shadowColor        = "#00000080";
      shadowInactiveColor = "#00000040";
      shadowDrawBehindWindow = true;
      tabIndicatorOff    = false;
      tabIndicatorActiveColor   = green;
      tabIndicatorInactiveColor = bg3;
      windowOpacity      = 0.96;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        /* Everforest Dark Hard */
        @define-color accent_color ${green};
        @define-color accent_bg_color ${green};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${red};
        @define-color destructive_fg_color ${fg};
        @define-color error_bg_color ${red};
        @define-color error_fg_color ${fg};
        @define-color window_bg_color ${bg0};
        @define-color window_fg_color ${fg};
        @define-color view_bg_color ${bg0};
        @define-color view_fg_color ${fg};
        @define-color headerbar_bg_color ${bg1};
        @define-color headerbar_fg_color ${fg};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${bg1};
        @define-color popover_fg_color ${fg};
        @define-color card_bg_color ${bg1};
        @define-color card_fg_color ${fg};
        @define-color dialog_bg_color ${bg0};
        @define-color dialog_fg_color ${fg};
        @define-color sidebar_bg_color ${bg1};
        @define-color sidebar_fg_color ${fg};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${bg2};
        @define-color secondary_sidebar_bg_color ${bg0};
        @define-color secondary_sidebar_fg_color ${grey2};
        @define-color theme_unfocused_fg_color ${grey2};
        @define-color theme_unfocused_text_color ${grey1};
        @define-color theme_unfocused_bg_color ${bg0};
        @define-color theme_unfocused_base_color ${bg0};
        @define-color theme_unfocused_selected_bg_color ${bg2};
        @define-color theme_unfocused_selected_fg_color ${fg};
      '';

      gtk4 = ''
        /* Everforest Dark Hard */
        @define-color accent_color ${green};
        @define-color accent_bg_color ${green};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${red};
        @define-color destructive_fg_color ${fg};
        @define-color error_bg_color ${red};
        @define-color error_fg_color ${fg};
        @define-color window_bg_color ${bg0};
        @define-color window_fg_color ${fg};
        @define-color view_bg_color ${bg0};
        @define-color view_fg_color ${fg};
        @define-color headerbar_bg_color ${bg1};
        @define-color headerbar_fg_color ${fg};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${bg1};
        @define-color popover_fg_color ${fg};
        @define-color card_bg_color ${bg1};
        @define-color card_fg_color ${fg};
        @define-color dialog_bg_color ${bg0};
        @define-color dialog_fg_color ${fg};
        @define-color sidebar_bg_color ${bg1};
        @define-color sidebar_fg_color ${fg};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${bg2};
        @define-color secondary_sidebar_bg_color ${bg0};
        @define-color secondary_sidebar_fg_color ${grey2};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${fg}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg}, #ffffff, ${fg}, ${bg0}, ${bg0}, #000000, ${green}, ${bg0}, ${green}, ${blue}, ${bg1}, ${bg0}, ${bg1}, ${fg}, ${grey1}, ${green}
        disabled_colors=${grey1}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${grey1}, #ffffff, ${grey1}, ${bg0}, ${bg0}, #000000, ${bg3}, ${bg2}, ${bg3}, ${blue}, ${bg1}, ${bg0}, ${bg1}, ${grey1}, ${grey0}, ${bg3}
        inactive_colors=${grey2}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${grey2}, #ffffff, ${grey2}, ${bg0}, ${bg0}, #000000, ${green}, ${bg0}, ${green}, ${blue}, ${bg1}, ${bg0}, ${bg1}, ${grey2}, ${grey1}, ${green}
      '';

      kitty = ''
        # Everforest Dark Hard Kitty
        cursor ${fg}
        cursor_text_color ${bg0}
        foreground ${fg}
        background ${bg0}
        selection_foreground ${bg0}
        selection_background ${green}
        color0  ${bg3}
        color8  ${bg5}
        color1  ${red}
        color9  ${red}
        color2  ${green}
        color10 ${green}
        color3  ${yellow}
        color11 ${yellow}
        color4  ${blue}
        color12 ${blue}
        color5  ${purple}
        color13 ${purple}
        color6  ${aqua}
        color14 ${aqua}
        color7  ${grey2}
        color15 ${fg}
      '';

      fish = ''
        set -g fish_color_normal ${fg}
        set -g fish_color_command ${green}
        set -g fish_color_keyword ${aqua}
        set -g fish_color_quote ${yellow}
        set -g fish_color_redirection ${blue}
        set -g fish_color_end ${grey1}
        set -g fish_color_error ${red}
        set -g fish_color_param ${fg}
        set -g fish_color_comment ${grey0}
        set -g fish_color_selection --background=${bg2}
        set -g fish_color_search_match --background=${bg1}
        set -g fish_color_operator ${aqua}
        set -g fish_color_escape ${orange}
        set -g fish_color_autosuggestion ${grey0}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${green})"
        error_symbol = "[❯](${red})"

        [directory]
        style = "bold ${aqua}"

        [git_branch]
        style = "bold ${yellow}"

        [cmd_duration]
        style = "bold ${grey1}"
      '';

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${bg0};
            text-color:                  ${fg};
            border-color:                ${bg2};
            selected-normal-background:  ${bg1};
            selected-normal-foreground:  ${green};
            normal-background:           ${bg0};
            normal-foreground:           ${fg};
        }

        window {
            width:              900px;
            border:             2px solid;
            border-color:       ${bg2};
            border-radius:      8px;
            padding:            12px;
            background-color:   ${bg0};
        }

        mainbox {
            spacing:            0;
            children:           [ inputbar, listview ];
        }

        inputbar {
            padding:            8px 12px;
            margin:             0 0 10px 0;
            background-color:   ${bg1};
            border-radius:      6px;
            children:           [ prompt, entry ];
        }

        prompt {
            text-color:         ${green};
            padding:            0 8px 0 0;
        }

        entry {
            text-color:         ${fg};
            placeholder:        "Switch profile…";
            placeholder-color:  ${bg3};
        }

        listview {
            columns:            3;
            lines:              2;
            spacing:            10px;
            fixed-height:       false;
            scrollbar:          false;
        }

        element {
            orientation:        vertical;
            padding:            10px;
            spacing:            8px;
            border-radius:      6px;
            background-color:   ${bg1};
            cursor:             pointer;
        }

        element selected {
            background-color:   ${bg2};
            border:             2px solid;
            border-color:       ${green};
        }

        element-icon {
            size:               160px;
            border-radius:      4px;
            horizontal-align:   0.5;
        }

        element-text {
            horizontal-align:   0.5;
            vertical-align:     0.5;
            text-color:         inherit;
            font:               "JetBrainsMono Nerd Font 12";
        }
      '';
    };

    waybar = {
      config = ''
        {
          "layer": "top",
          "height": 28,
          "modules-left": [
            "niri/workspaces",
            "power-profiles-daemon",
            "cpu",
            "memory"
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
            "pulseaudio",
            "bluetooth",
            "network",
            "battery"
          ],
          "niri/window": { "max-length": 30 },
          "tray": { "icon-size": 20, "spacing": 8 },
          "pulseaudio": {
            "format-source": "󰍬",
            "format-source-muted": "󰍭",
            "format": "{format_source} 󰕾 {volume}%",
            "format-bluetooth": "{format_source} 󰂰 {volume}%",
            "format-muted": "{format_source} 󰸈",
            "on-click": "foot-popup pulsemixer",
            "max-volume": 150,
            "scroll-step": 1
          },
          "bluetooth": {
            "format": "",
            "format-disabled": "",
            "format-off": "",
            "format-on": "󰂯",
            "format-connected": "󰂱 {device_alias}",
            "max-length": 16
          },
          "network": {
            "format": "{ifname}",
            "format-wifi": "󰖩 {essid}",
            "format-ethernet": "󰈀 {ipaddr}",
            "format-disconnected": "Disconnected",
            "max-length": 32
          },
          "battery": {
            "interval": 60,
            "format-time": "{H}:{m}",
            "format-icons": ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"],
            "format-discharging": "{icon} {capacity}% ({time})",
            "format-charging": "󰂄 {capacity}%",
            "format": ""
          },
          "niri/workspaces": {
            "format": "{icon}",
            "on-click": "activate",
            "format-icons": {
              "1": "1","2": "2","3": "3","4": "4","5": "5",
              "6": "6","7": "7","8": "8","9": "9","10": "10"
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

      style = ''
        * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-height: 0; }
        window#waybar { background-color: transparent; color: ${fg}; }
        .modules-left, .modules-center, .modules-right { padding: 0 4px; }
        #workspaces button { padding: 0 8px; background: transparent; color: ${fg}; border-bottom: 2px solid transparent; }
        #workspaces button.active { color: ${green}; border-bottom: 2px solid ${green}; }
        #workspaces button:hover { background: rgba(255,255,255,0.05); color: ${fg}; }
        #clock { color: ${yellow}; font-weight: bold; }
        #battery, #bluetooth, #network, #pulseaudio, #tray { color: ${fg}; padding: 0 8px; }
        #cpu, #memory { color: ${fg}; padding: 0 8px; }
        #power-profiles-daemon { color: ${fg}; padding: 0 8px; }
        #power-profiles-daemon.performance { color: ${red}; }
        #power-profiles-daemon.balanced { color: ${green}; }
        #power-profiles-daemon.power-saver { color: ${aqua}; }
        #battery.critical { color: ${red}; }
      '';
    };
  };
}
