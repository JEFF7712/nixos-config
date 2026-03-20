{ pkgs, ... }:

# Catppuccin desktop profile for the Mocha palette.
let
  rosewater = "#f5e0dc";
  flamingo  = "#f2cdcd";
  pink      = "#f5c2e7";
  mauve     = "#cba6f7";
  red       = "#f38ba8";
  maroon    = "#eba0ac";
  peach     = "#fab387";
  yellow    = "#f9e2af";
  green     = "#a6e3a1";
  teal      = "#94e2d5";
  sky       = "#89dceb";
  sapphire  = "#74c7ec";
  blue      = "#89b4fa";
  lavender  = "#b4befe";
  text      = "#cdd6f4";
  subtext1  = "#bac2de";
  subtext0  = "#a6adc8";
  overlay2  = "#9399b2";
  overlay1  = "#7f849c";
  overlay0  = "#6c7086";
  surface2  = "#585b70";
  surface1  = "#45475a";
  surface0  = "#313244";
  base      = "#1e1e2e";
  mantle    = "#181825";
  crust     = "#11111b";
in {
  home.packages = [ pkgs.waybar pkgs.waypaper pkgs.rofi pkgs.python3Packages.pywal pkgs.mako ];

  desktopProfiles.profiles.catppuccin = {
    bar = "waybar";

    cursor = {
      theme = "Adwaita";
      size  = 28;
    };

    wallpaperDir = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/catppuccin";

    niri = {
      gaps               = 18;
      borderOff          = true;
      borderActiveColor  = mauve;
      borderInactiveColor = surface1;
      urgentColor        = red;
      focusRingOff       = true;
      focusRingActiveColor   = mauve;
      focusRingInactiveColor = surface1;
      shadowSoftness     = 22;
      shadowSpread       = 3;
      shadowOffsetX      = 0;
      shadowOffsetY      = 4;
      shadowColor        = "#00000088";
      shadowInactiveColor = "#00000055";
      shadowDrawBehindWindow = true;
      tabIndicatorOff    = false;
      tabIndicatorActiveColor   = mauve;
      tabIndicatorInactiveColor = surface1;
      windowOpacity      = 0.97;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        /* Catppuccin Mocha */
        @define-color accent_color ${mauve};
        @define-color accent_bg_color ${mauve};
        @define-color accent_fg_color ${base};
        @define-color destructive_bg_color ${red};
        @define-color destructive_fg_color ${base};
        @define-color error_bg_color ${red};
        @define-color error_fg_color ${base};
        @define-color window_bg_color ${base};
        @define-color window_fg_color ${text};
        @define-color view_bg_color ${base};
        @define-color view_fg_color ${text};
        @define-color headerbar_bg_color ${mantle};
        @define-color headerbar_fg_color ${text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${mantle};
        @define-color popover_fg_color ${text};
        @define-color card_bg_color ${surface0};
        @define-color card_fg_color ${text};
        @define-color dialog_bg_color ${mantle};
        @define-color dialog_fg_color ${text};
        @define-color sidebar_bg_color ${mantle};
        @define-color sidebar_fg_color ${text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${surface1};
        @define-color secondary_sidebar_bg_color ${base};
        @define-color secondary_sidebar_fg_color ${subtext1};
        @define-color theme_unfocused_fg_color ${subtext0};
        @define-color theme_unfocused_text_color ${overlay2};
        @define-color theme_unfocused_bg_color ${base};
        @define-color theme_unfocused_base_color ${base};
        @define-color theme_unfocused_selected_bg_color ${surface1};
        @define-color theme_unfocused_selected_fg_color ${base};
      '';

      gtk4 = ''
        /* Catppuccin Mocha */
        @define-color accent_color ${mauve};
        @define-color accent_bg_color ${mauve};
        @define-color accent_fg_color ${base};
        @define-color destructive_bg_color ${red};
        @define-color destructive_fg_color ${base};
        @define-color error_bg_color ${red};
        @define-color error_fg_color ${base};
        @define-color window_bg_color ${base};
        @define-color window_fg_color ${text};
        @define-color view_bg_color ${base};
        @define-color view_fg_color ${text};
        @define-color headerbar_bg_color ${mantle};
        @define-color headerbar_fg_color ${text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${mantle};
        @define-color popover_fg_color ${text};
        @define-color card_bg_color ${surface0};
        @define-color card_fg_color ${text};
        @define-color dialog_bg_color ${mantle};
        @define-color dialog_fg_color ${text};
        @define-color sidebar_bg_color ${mantle};
        @define-color sidebar_fg_color ${text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${surface1};
        @define-color secondary_sidebar_bg_color ${base};
        @define-color secondary_sidebar_fg_color ${subtext1};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${text}, ${mantle}, #ffffff, ${overlay1}, ${surface0}, ${surface0}, ${text}, #ffffff, ${text}, ${base}, ${base}, #000000, ${mauve}, ${surface1}, ${mauve}, ${blue}, ${surface0}, ${crust}, ${surface0}, ${text}, ${subtext1}, ${mauve}
        disabled_colors=${overlay0}, ${mantle}, #ffffff, ${overlay1}, ${surface0}, ${surface0}, ${overlay0}, #ffffff, ${overlay0}, ${base}, ${base}, #000000, ${surface2}, ${surface1}, ${surface2}, ${blue}, ${surface0}, ${crust}, ${surface0}, ${overlay0}, ${overlay1}, ${surface2}
        inactive_colors=${text}, ${mantle}, #ffffff, ${overlay1}, ${surface0}, ${surface0}, ${subtext1}, #ffffff, ${text}, ${base}, ${base}, #000000, ${mauve}, ${surface1}, ${mauve}, ${blue}, ${surface0}, ${crust}, ${surface0}, ${text}, ${subtext1}, ${mauve}
      '';

      kitty = ''
        # Catppuccin Kitty
        cursor ${text}
        cursor_text_color ${base}
        foreground ${text}
        background ${base}
        selection_foreground ${base}
        selection_background ${rosewater}
        color0  ${surface1}
        color8  ${surface2}
        color1  ${red}
        color9  ${red}
        color2  ${green}
        color10 ${green}
        color3  ${yellow}
        color11 ${yellow}
        color4  ${blue}
        color12 ${blue}
        color5  ${pink}
        color13 ${pink}
        color6  ${teal}
        color14 ${teal}
        color7  ${subtext1}
        color15 ${subtext0}
      '';

      fish = ''
        set -g fish_color_normal ${text}
        set -g fish_color_command ${blue}
        set -g fish_color_keyword ${mauve}
        set -g fish_color_quote ${green}
        set -g fish_color_redirection ${teal}
        set -g fish_color_end ${pink}
        set -g fish_color_error ${red}
        set -g fish_color_param ${text}
        set -g fish_color_comment ${overlay0}
        set -g fish_color_selection --background=${surface1}
        set -g fish_color_search_match --background=${surface0}
        set -g fish_color_operator ${sky}
        set -g fish_color_escape ${peach}
        set -g fish_color_autosuggestion ${overlay0}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${green})"
        error_symbol = "[❯](${red})"

        [directory]
        style = "bold ${blue}"

        [git_branch]
        style = "bold ${mauve}"

        [cmd_duration]
        style = "bold ${yellow}"
      '';
    };

    waybar = {
      config = ''
        {
          "layer": "top",
          "height": 28,
          "modules-left": [
            "niri/workspaces",
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
            "niri/language",
            "pulseaudio",
            "bluetooth",
            "network",
            "battery"
          ],
          "niri/window": { "max-length": 30 },
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
              "1": "1",
              "2": "2",
              "3": "3",
              "4": "4",
              "5": "5",
              "6": "6",
              "7": "7",
              "8": "8",
              "9": "9",
              "10": "10"
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
          },
          "cpu": {
            "interval": 3,
            "format": "󰻠 {usage}%",
            "tooltip": false
          },
          "memory": {
            "interval": 3,
            "format": "󰍛 {percentage}%",
            "tooltip-format": "{used:0.1f}G / {total:0.1f}G"
          }
        }
      '';

      style = ''
        * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-height: 0; }
        window#waybar { background-color: ${crust}; color: ${text}; }
        .modules-left, .modules-center, .modules-right { padding: 0 4px; }
        #workspaces button { padding: 0 8px; background: transparent; color: ${overlay0}; border-bottom: 2px solid transparent; }
        #workspaces button.active { color: ${mauve}; border-bottom: 2px solid ${mauve}; }
        #workspaces button:hover { background: ${surface0}; color: ${text}; }
        #clock { color: ${lavender}; font-weight: bold; }
        #pulseaudio { color: ${sky}; padding: 0 8px; }
        #bluetooth { color: ${blue}; padding: 0 8px; }
        #network { color: ${teal}; padding: 0 8px; }
        #battery { color: ${peach}; padding: 0 8px; }
        #tray { color: ${subtext1}; padding: 0 8px; }
        #cpu { color: ${green}; padding: 0 8px; }
        #memory { color: ${yellow}; padding: 0 8px; }
        #workspaces { padding: 0 4px; }
        #battery.critical { color: ${red}; }
      '';
    };
  };
}
