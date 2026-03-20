{ pkgs, ... }:

let
  # Gruvbox Dark Hard
  bg0h  = "#1d2021";
  bg0   = "#282828";
  bg1   = "#3c3836";
  bg2   = "#504945";
  bg3   = "#665c54";
  bg4   = "#7c6f64";
  fg0   = "#fbf1c7";
  fg1   = "#ebdbb2";
  fg2   = "#d5c4a1";
  fg3   = "#bdae93";
  fg4   = "#a89984";
  red   = "#fb4934";
  green = "#b8bb26";
  yellow = "#fabd2f";
  blue  = "#83a598";
  purple = "#d3869b";
  aqua  = "#8ec07c";
  orange = "#fe8019";
  gray  = "#928374";
in {
  home.packages = [ pkgs.waybar pkgs.waypaper pkgs.rofi pkgs.python3Packages.pywal pkgs.mako ];

  xdg.configFile."mako/config".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color=${bg0}
    text-color=${fg1}
    border-color=${yellow}
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
    border-color=${bg3}
    default-timeout=3000

    [urgency=high]
    background-color=${bg1}
    border-color=${red}
    text-color=${fg0}
    default-timeout=0
  '';

  desktopProfiles.profiles.gruvbox = {
    bar = "waybar";

    cursor = {
      theme = "Adwaita";
      size  = 24;
    };

    wallpaperDir = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/gruvbox";

    niri = {
      gaps               = 20;
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
      tabIndicatorActiveColor   = yellow;
      tabIndicatorInactiveColor = bg2;
      windowOpacity      = 0.96;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        /* Gruvbox Dark */
        @define-color accent_color ${yellow};
        @define-color accent_bg_color ${yellow};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${red};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${red};
        @define-color error_fg_color ${fg0};
        @define-color window_bg_color ${bg0};
        @define-color window_fg_color ${fg1};
        @define-color view_bg_color ${bg0};
        @define-color view_fg_color ${fg1};
        @define-color headerbar_bg_color ${bg1};
        @define-color headerbar_fg_color ${fg1};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${bg1};
        @define-color popover_fg_color ${fg1};
        @define-color card_bg_color ${bg1};
        @define-color card_fg_color ${fg1};
        @define-color dialog_bg_color ${bg0};
        @define-color dialog_fg_color ${fg1};
        @define-color sidebar_bg_color ${bg1};
        @define-color sidebar_fg_color ${fg1};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${bg2};
        @define-color secondary_sidebar_bg_color ${bg0};
        @define-color secondary_sidebar_fg_color ${fg2};
        @define-color theme_unfocused_fg_color ${fg3};
        @define-color theme_unfocused_text_color ${fg4};
        @define-color theme_unfocused_bg_color ${bg0};
        @define-color theme_unfocused_base_color ${bg0};
        @define-color theme_unfocused_selected_bg_color ${bg2};
        @define-color theme_unfocused_selected_fg_color ${fg1};
      '';

      gtk4 = ''
        /* Gruvbox Dark */
        @define-color accent_color ${yellow};
        @define-color accent_bg_color ${yellow};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${red};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${red};
        @define-color error_fg_color ${fg0};
        @define-color window_bg_color ${bg0};
        @define-color window_fg_color ${fg1};
        @define-color view_bg_color ${bg0};
        @define-color view_fg_color ${fg1};
        @define-color headerbar_bg_color ${bg1};
        @define-color headerbar_fg_color ${fg1};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${bg1};
        @define-color popover_fg_color ${fg1};
        @define-color card_bg_color ${bg1};
        @define-color card_fg_color ${fg1};
        @define-color dialog_bg_color ${bg0};
        @define-color dialog_fg_color ${fg1};
        @define-color sidebar_bg_color ${bg1};
        @define-color sidebar_fg_color ${fg1};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${bg2};
        @define-color secondary_sidebar_bg_color ${bg0};
        @define-color secondary_sidebar_fg_color ${fg2};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${fg1}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg1}, #ffffff, ${fg1}, ${bg0}, ${bg0}, #000000, ${yellow}, ${bg0}, ${yellow}, ${blue}, ${bg1}, ${bg0h}, ${bg1}, ${fg1}, ${fg4}, ${yellow}
        disabled_colors=${fg4}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg4}, #ffffff, ${fg4}, ${bg0}, ${bg0}, #000000, ${bg3}, ${bg2}, ${bg3}, ${blue}, ${bg1}, ${bg0h}, ${bg1}, ${fg4}, ${gray}, ${bg3}
        inactive_colors=${fg2}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg2}, #ffffff, ${fg2}, ${bg0}, ${bg0}, #000000, ${yellow}, ${bg0}, ${yellow}, ${blue}, ${bg1}, ${bg0h}, ${bg1}, ${fg2}, ${fg4}, ${yellow}
      '';

      kitty = ''
        # Gruvbox Dark Kitty
        cursor ${fg1}
        cursor_text_color ${bg0}
        foreground ${fg1}
        background ${bg0}
        selection_foreground ${bg0}
        selection_background ${yellow}
        color0  ${bg1}
        color8  ${bg3}
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
        color7  ${fg4}
        color15 ${fg1}
      '';

      fish = ''
        set -g fish_color_normal ${fg1}
        set -g fish_color_command ${yellow}
        set -g fish_color_keyword ${orange}
        set -g fish_color_quote ${green}
        set -g fish_color_redirection ${aqua}
        set -g fish_color_end ${fg4}
        set -g fish_color_error ${red}
        set -g fish_color_param ${fg2}
        set -g fish_color_comment ${bg4}
        set -g fish_color_selection --background=${bg2}
        set -g fish_color_search_match --background=${bg1}
        set -g fish_color_operator ${orange}
        set -g fish_color_escape ${purple}
        set -g fish_color_autosuggestion ${bg4}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${yellow})"
        error_symbol = "[❯](${red})"

        [directory]
        style = "bold ${blue}"

        [git_branch]
        style = "bold ${orange}"

        [cmd_duration]
        style = "bold ${fg4}"
      '';

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${bg0};
            text-color:                  ${fg1};
            border-color:                ${bg2};
            selected-normal-background:  ${bg1};
            selected-normal-foreground:  ${yellow};
            normal-background:           ${bg0};
            normal-foreground:           ${fg1};
        }

        window {
            width:              700px;
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
            text-color:         ${yellow};
            padding:            0 8px 0 0;
        }

        entry {
            text-color:         ${fg1};
            placeholder:        "Switch profile…";
            placeholder-color:  ${bg3};
        }

        listview {
            columns:            2;
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
            border-color:       ${yellow};
        }

        element-icon {
            size:               220px;
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
        window#waybar { background-color: transparent; color: ${fg1}; }
        .modules-left, .modules-center, .modules-right { padding: 0 4px; }
        #workspaces button { padding: 0 8px; background: transparent; color: ${fg1}; border-bottom: 2px solid transparent; }
        #workspaces button.active { color: ${yellow}; border-bottom: 2px solid ${yellow}; }
        #workspaces button:hover { background: rgba(255,255,255,0.05); color: ${fg1}; }
        #clock { color: ${yellow}; font-weight: bold; }
        #battery, #bluetooth, #network, #pulseaudio, #tray { color: ${fg1}; padding: 0 8px; }
        #cpu, #memory { color: ${fg1}; padding: 0 8px; }
        #power-profiles-daemon { color: ${fg1}; padding: 0 8px; }
        #power-profiles-daemon.performance { color: ${red}; }
        #power-profiles-daemon.balanced { color: ${yellow}; }
        #power-profiles-daemon.power-saver { color: ${green}; }
        #battery.critical { color: ${red}; }
      '';
    };
  };
}
