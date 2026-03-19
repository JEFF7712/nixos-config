{ pkgs, ... }:

# waybar is required by this profile.
# nordzy cursor/icon themes are used when available.

let
  nord0  = "#2e3440";
  nord1  = "#3b4252";
  nord2  = "#434c5e";
  nord3  = "#4c566a";
  nord4  = "#d8dee9";
  nord5  = "#e5e9f0";
  nord6  = "#eceff4";
  nord7  = "#8fbcbb";
  nord8  = "#88c0d0";
  nord9  = "#81a1c1";
  nord10 = "#5e81ac";
  nord11 = "#bf616a";
  nord12 = "#d08770";
  nord13 = "#ebcb8b";
  nord14 = "#a3be8c";
  nord15 = "#b48ead";
in {
  home.packages = [ pkgs.waybar ];

  desktopProfiles.profiles.nord = {
    bar = "waybar";

    cursor = {
      theme   = "Nordzy-cursors";
      size    = 24;
      package = pkgs.nordzy-cursor-theme;
    };

    wallpaperDir = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/nord";

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
      tabIndicatorActiveColor   = nord8;
      tabIndicatorInactiveColor = nord3;
      focusRingOff       = true;
      borderOff          = true;
      windowOpacity      = 0.95;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        /* GTK3 Nord Theme */
        @define-color accent_color ${nord8};
        @define-color accent_bg_color ${nord8};
        @define-color accent_fg_color ${nord0};
        @define-color destructive_bg_color ${nord11};
        @define-color destructive_fg_color ${nord6};
        @define-color error_bg_color ${nord11};
        @define-color error_fg_color ${nord6};
        @define-color window_bg_color ${nord0};
        @define-color window_fg_color ${nord4};
        @define-color view_bg_color ${nord0};
        @define-color view_fg_color ${nord4};
        @define-color headerbar_bg_color ${nord1};
        @define-color headerbar_fg_color ${nord4};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${nord1};
        @define-color popover_fg_color ${nord4};
        @define-color card_bg_color ${nord1};
        @define-color card_fg_color ${nord4};
        @define-color dialog_bg_color ${nord0};
        @define-color dialog_fg_color ${nord4};
        @define-color sidebar_bg_color ${nord1};
        @define-color sidebar_fg_color ${nord4};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color @window_bg_color;
        @define-color secondary_sidebar_bg_color ${nord0};
        @define-color secondary_sidebar_fg_color ${nord4};
        @define-color theme_unfocused_fg_color @window_fg_color;
        @define-color theme_unfocused_text_color @view_fg_color;
        @define-color theme_unfocused_bg_color @window_bg_color;
        @define-color theme_unfocused_base_color @window_bg_color;
        @define-color theme_unfocused_selected_bg_color @accent_bg_color;
        @define-color theme_unfocused_selected_fg_color @accent_fg_color;
      '';

      gtk4 = ''
        /* GTK4 Nord Theme */
        @define-color accent_color ${nord8};
        @define-color accent_bg_color ${nord8};
        @define-color accent_fg_color ${nord0};
        @define-color destructive_bg_color ${nord11};
        @define-color destructive_fg_color ${nord6};
        @define-color error_bg_color ${nord11};
        @define-color error_fg_color ${nord6};
        @define-color window_bg_color ${nord0};
        @define-color window_fg_color ${nord4};
        @define-color view_bg_color ${nord0};
        @define-color view_fg_color ${nord4};
        @define-color headerbar_bg_color ${nord1};
        @define-color headerbar_fg_color ${nord4};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${nord1};
        @define-color popover_fg_color ${nord4};
        @define-color card_bg_color ${nord1};
        @define-color card_fg_color ${nord4};
        @define-color dialog_bg_color ${nord0};
        @define-color dialog_fg_color ${nord4};
        @define-color sidebar_bg_color ${nord1};
        @define-color sidebar_fg_color ${nord4};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color @window_bg_color;
        @define-color secondary_sidebar_bg_color ${nord0};
        @define-color secondary_sidebar_fg_color ${nord4};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${nord4}, ${nord1}, #ffffff, ${nord3}, ${nord2}, ${nord2}, ${nord4}, #ffffff, ${nord4}, ${nord0}, ${nord0}, #000000, ${nord10}, ${nord6}, ${nord9}, ${nord8}, ${nord3}, ${nord0}, ${nord3}, ${nord4}, ${nord4}, ${nord8}
        disabled_colors=${nord3}, ${nord1}, #ffffff, ${nord3}, ${nord2}, ${nord2}, ${nord3}, #ffffff, ${nord3}, ${nord0}, ${nord0}, #000000, ${nord10}, ${nord6}, ${nord9}, ${nord8}, ${nord3}, ${nord0}, ${nord3}, ${nord3}, ${nord3}, ${nord8}
        inactive_colors=${nord4}, ${nord1}, #ffffff, ${nord3}, ${nord2}, ${nord2}, ${nord4}, #ffffff, ${nord4}, ${nord0}, ${nord0}, #000000, ${nord10}, ${nord6}, ${nord9}, ${nord8}, ${nord3}, ${nord0}, ${nord3}, ${nord4}, ${nord4}, ${nord8}
      '';

      kitty = ''
        # Nord Kitty Theme
        cursor ${nord4}
        cursor_text_color ${nord0}
        foreground ${nord4}
        background ${nord0}
        selection_foreground ${nord0}
        selection_background ${nord8}
        color0  ${nord1}
        color8  ${nord3}
        color1  ${nord11}
        color9  ${nord11}
        color2  ${nord14}
        color10 ${nord14}
        color3  ${nord13}
        color11 ${nord13}
        color4  ${nord9}
        color12 ${nord9}
        color5  ${nord15}
        color13 ${nord15}
        color6  ${nord7}
        color14 ${nord7}
        color7  ${nord5}
        color15 ${nord6}
      '';

      fish = ''
        set -g fish_color_normal ${nord4}
        set -g fish_color_command ${nord8}
        set -g fish_color_keyword ${nord9}
        set -g fish_color_quote ${nord14}
        set -g fish_color_redirection ${nord4}
        set -g fish_color_end ${nord3}
        set -g fish_color_error ${nord11}
        set -g fish_color_param ${nord4}
        set -g fish_color_comment ${nord3}
        set -g fish_color_selection --background=${nord2}
        set -g fish_color_search_match --background=${nord2}
        set -g fish_color_operator ${nord8}
        set -g fish_color_escape ${nord13}
        set -g fish_color_autosuggestion ${nord3}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${nord8})"
        error_symbol = "[❯](${nord11})"

        [directory]
        style = "bold ${nord9}"

        [git_branch]
        style = "bold ${nord10}"

        [cmd_duration]
        style = "bold ${nord3}"
      '';
    };

    waybar = {
      config = ''
        {
          "layer": "top",
          "height": 28,
          "modules-left": [
            "niri/workspaces"
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
            "niri/language",
            "pulseaudio",
            "bluetooth",
            "network",
            "battery"
          ],
          "niri/window": {
            "max-length": 30
          },
          "niri/language": {
            "format-en": "En",
            "format-ru": "Ru"
          },
          "tray": {
            "icon-size": 20,
            "spacing": 8
          },
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
            "format-icons": [
              "󰁺",
              "󰁻",
              "󰁼",
              "󰁽",
              "󰁾",
              "󰁿",
              "󰂀",
              "󰂁",
              "󰂂",
              "󰁹"
            ],
            "format-discharging": "{icon} {capacity}% ({time})",
            "format-charging": "󰂄 {capacity}%",
            "format": ""
          },
          "niri/workspaces": {
            "format": "{icon}",
            "on-click": "activate",
            "format-icons": {
              "1": "⼀",
              "2": "二",
              "3": "三",
              "4": "四",
              "5": "五",
              "6": "六",
              "7": "七",
              "8": "八",
              "9": "九",
              "10": "十"
            },
            "persistent-workspaces": {
              "1": [],
              "2": [],
              "3": [],
              "4": [],
              "5": [],
              "6": [],
              "7": [],
              "8": [],
              "9": [],
              "10": []
            },
            "sort-by-number": true
          }
        }
      '';

      style = ''
        * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-height: 0; }
        window#waybar { background-color: #2e3440; color: #d8dee9; }
        .modules-left, .modules-center, .modules-right { padding: 0 4px; }
        #workspaces button { padding: 0 8px; background: transparent; color: #4c566a; border-bottom: 2px solid transparent; }
        #workspaces button.active { color: #88c0d0; border-bottom: 2px solid #88c0d0; }
        #workspaces button:hover { background: rgba(255,255,255,0.05); color: #e5e9f0; }
        #clock { color: #88c0d0; font-weight: bold; }
        #battery, #bluetooth, #network, #pulseaudio, #tray { color: #d8dee9; padding: 0 8px; }
        #workspaces { padding: 0 4px; }
        #workspaces button { padding: 0 8px; background: transparent; color: #4c566a; border-bottom: 2px solid transparent; }
        #workspaces button.active { color: #88c0d0; border-bottom: 2px solid #88c0d0; }
        #workspaces button:hover { background: rgba(255,255,255,0.05); color: #e5e9f0; }
        #battery.critical { color: #bf616a; }
      '';
    };
  };
}
