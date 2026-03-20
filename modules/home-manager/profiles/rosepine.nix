{ pkgs, ... }:

let
  # ── Rosé Pine Main (dark) ────────────────────────────────────────────────────
  base          = "#191724";
  surface       = "#1f1d2e";
  overlay       = "#26233a";
  muted         = "#6e6a86";
  subtle        = "#908caa";
  text          = "#e0def4";
  love          = "#eb6f92";  # red/pink
  gold          = "#f6c177";  # yellow/gold
  rose          = "#ebbcba";  # rose/pink
  pine          = "#31748f";  # teal/blue
  foam          = "#9ccfd8";  # cyan
  iris          = "#c4a7e7";  # purple — main accent
  highlightLow  = "#21202e";
  highlightMed  = "#403d52";
  highlightHigh = "#524f67";

  # ── Rosé Pine Dawn (light) ───────────────────────────────────────────────────
  d_base          = "#faf4ed";
  d_surface       = "#fffaf3";
  d_overlay       = "#f2e9e1";
  d_muted         = "#9893a5";
  d_subtle        = "#797593";
  d_text          = "#575279";
  d_love          = "#b4637a";
  d_gold          = "#ea9d34";
  d_rose          = "#d7827e";
  d_pine          = "#286983";
  d_foam          = "#56949f";
  d_iris          = "#907aa9";
  d_highlightLow  = "#f4ede8";
  d_highlightMed  = "#dfdad9";
  d_highlightHigh = "#cecacd";
in {
  home.packages = [ pkgs.waybar pkgs.waypaper pkgs.rofi pkgs.python3Packages.pywal pkgs.mako ];

  xdg.configFile."mako/config".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color=${base}
    text-color=${text}
    border-color=${iris}
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
    border-color=${highlightHigh}
    default-timeout=3000

    [urgency=high]
    background-color=${surface}
    border-color=${love}
    text-color=${text}
    default-timeout=0
  '';

  desktopProfiles.profiles.rosepine = {
    bar = "waybar";

    cursor = {
      theme   = "BreezeX-RosePine-Linux";
      size    = 24;
      package = pkgs.rose-pine-cursor;
    };

    wallpaperDir = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/rosepine";

    niri = {
      gaps               = 18;
      borderOff          = true;
      focusRingOff       = true;
      shadowSoftness     = 22;
      shadowSpread       = 3;
      shadowOffsetX      = 0;
      shadowOffsetY      = 4;
      shadowColor        = "#00000088";
      shadowInactiveColor = "#00000055";
      shadowDrawBehindWindow = true;
      tabIndicatorOff    = false;
      tabIndicatorActiveColor   = iris;
      tabIndicatorInactiveColor = highlightMed;
      windowOpacity      = 0.97;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        /* Rosé Pine */
        @define-color accent_color ${iris};
        @define-color accent_bg_color ${iris};
        @define-color accent_fg_color ${base};
        @define-color destructive_bg_color ${love};
        @define-color destructive_fg_color ${base};
        @define-color error_bg_color ${love};
        @define-color error_fg_color ${base};
        @define-color window_bg_color ${base};
        @define-color window_fg_color ${text};
        @define-color view_bg_color ${base};
        @define-color view_fg_color ${text};
        @define-color headerbar_bg_color ${surface};
        @define-color headerbar_fg_color ${text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${surface};
        @define-color popover_fg_color ${text};
        @define-color card_bg_color ${overlay};
        @define-color card_fg_color ${text};
        @define-color dialog_bg_color ${surface};
        @define-color dialog_fg_color ${text};
        @define-color sidebar_bg_color ${surface};
        @define-color sidebar_fg_color ${text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${highlightMed};
        @define-color secondary_sidebar_bg_color ${base};
        @define-color secondary_sidebar_fg_color ${subtle};
        @define-color theme_unfocused_fg_color ${subtle};
        @define-color theme_unfocused_text_color ${muted};
        @define-color theme_unfocused_bg_color ${base};
        @define-color theme_unfocused_base_color ${base};
        @define-color theme_unfocused_selected_bg_color ${highlightMed};
        @define-color theme_unfocused_selected_fg_color ${text};
      '';

      gtk4 = ''
        /* Rosé Pine */
        @define-color accent_color ${iris};
        @define-color accent_bg_color ${iris};
        @define-color accent_fg_color ${base};
        @define-color destructive_bg_color ${love};
        @define-color destructive_fg_color ${base};
        @define-color error_bg_color ${love};
        @define-color error_fg_color ${base};
        @define-color window_bg_color ${base};
        @define-color window_fg_color ${text};
        @define-color view_bg_color ${base};
        @define-color view_fg_color ${text};
        @define-color headerbar_bg_color ${surface};
        @define-color headerbar_fg_color ${text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${surface};
        @define-color popover_fg_color ${text};
        @define-color card_bg_color ${overlay};
        @define-color card_fg_color ${text};
        @define-color dialog_bg_color ${surface};
        @define-color dialog_fg_color ${text};
        @define-color sidebar_bg_color ${surface};
        @define-color sidebar_fg_color ${text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${highlightMed};
        @define-color secondary_sidebar_bg_color ${base};
        @define-color secondary_sidebar_fg_color ${subtle};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${text}, ${surface}, #ffffff, ${highlightHigh}, ${overlay}, ${overlay}, ${text}, #ffffff, ${text}, ${base}, ${base}, #000000, ${iris}, ${highlightMed}, ${iris}, ${pine}, ${overlay}, ${highlightLow}, ${overlay}, ${text}, ${subtle}, ${iris}
        disabled_colors=${muted}, ${surface}, #ffffff, ${highlightHigh}, ${overlay}, ${overlay}, ${muted}, #ffffff, ${muted}, ${base}, ${base}, #000000, ${highlightHigh}, ${highlightMed}, ${highlightHigh}, ${pine}, ${overlay}, ${highlightLow}, ${overlay}, ${muted}, ${muted}, ${highlightHigh}
        inactive_colors=${subtle}, ${surface}, #ffffff, ${highlightHigh}, ${overlay}, ${overlay}, ${subtle}, #ffffff, ${subtle}, ${base}, ${base}, #000000, ${iris}, ${highlightMed}, ${iris}, ${pine}, ${overlay}, ${highlightLow}, ${overlay}, ${subtle}, ${muted}, ${iris}
      '';

      kitty = ''
        # Rosé Pine Kitty
        cursor ${rose}
        cursor_text_color ${base}
        foreground ${text}
        background ${base}
        selection_foreground ${base}
        selection_background ${iris}
        color0  ${highlightMed}
        color8  ${highlightHigh}
        color1  ${love}
        color9  ${love}
        color2  ${pine}
        color10 ${foam}
        color3  ${gold}
        color11 ${gold}
        color4  ${pine}
        color12 ${pine}
        color5  ${iris}
        color13 ${iris}
        color6  ${foam}
        color14 ${foam}
        color7  ${subtle}
        color15 ${text}
      '';

      fish = ''
        set -g fish_color_normal ${text}
        set -g fish_color_command ${iris}
        set -g fish_color_keyword ${love}
        set -g fish_color_quote ${gold}
        set -g fish_color_redirection ${foam}
        set -g fish_color_end ${subtle}
        set -g fish_color_error ${love}
        set -g fish_color_param ${text}
        set -g fish_color_comment ${muted}
        set -g fish_color_selection --background=${highlightMed}
        set -g fish_color_search_match --background=${overlay}
        set -g fish_color_operator ${iris}
        set -g fish_color_escape ${rose}
        set -g fish_color_autosuggestion ${muted}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${iris})"
        error_symbol = "[❯](${love})"

        [directory]
        style = "bold ${foam}"

        [git_branch]
        style = "bold ${rose}"

        [cmd_duration]
        style = "bold ${subtle}"
      '';

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${base};
            text-color:                  ${text};
            border-color:                ${highlightMed};
            selected-normal-background:  ${overlay};
            selected-normal-foreground:  ${iris};
            normal-background:           ${base};
            normal-foreground:           ${text};
        }

        window {
            width:              900px;
            border:             2px solid;
            border-color:       ${highlightMed};
            border-radius:      8px;
            padding:            12px;
            background-color:   ${base};
        }

        mainbox {
            spacing:            0;
            children:           [ inputbar, listview ];
        }

        inputbar {
            padding:            8px 12px;
            margin:             0 0 10px 0;
            background-color:   ${surface};
            border-radius:      6px;
            children:           [ prompt, entry ];
        }

        prompt {
            text-color:         ${iris};
            padding:            0 8px 0 0;
        }

        entry {
            text-color:         ${text};
            placeholder:        "Switch profile…";
            placeholder-color:  ${highlightHigh};
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
            background-color:   ${surface};
            cursor:             pointer;
        }

        element selected {
            background-color:   ${overlay};
            border:             2px solid;
            border-color:       ${iris};
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
          "height": 30,
          "margin-top": 5,
          "margin-left": 40,
          "margin-right": 40,
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
        window#waybar {
          background-color: rgba(25, 23, 36, 0.6);
          color: ${iris};
          border: 1px solid ${highlightMed};
          border-radius: 50px;
          box-shadow: 0 10px 30px rgba(16, 14, 24, 0.45);
        }
        .modules-left, .modules-center, .modules-right { padding: 0 10px; }
        #workspaces { padding: 0px 2px; }
        #workspaces button {
          padding: 0 10px;
          margin: 0px 2px;
          background: transparent;
          color: ${iris};
          border-radius: 10px;
          border-bottom: 2px solid transparent;
        }
        #workspaces button.active {
          color: ${iris};
          background: ${overlay};
        }
        #workspaces button:hover { background: ${overlay}; color: ${rose}; }
        #clock { color: ${rose}; font-weight: bold; padding: 0 10px; }
        #pulseaudio, #bluetooth, #network, #battery, #tray, #cpu, #memory, #language {
          color: ${iris};
          padding: 0 10px;
        }
        #power-profiles-daemon { color: ${iris}; padding: 0 10px; }
        #power-profiles-daemon.performance { color: ${love}; }
        #power-profiles-daemon.balanced { color: ${iris}; }
        #power-profiles-daemon.power-saver { color: ${pine}; }
        #battery.critical { color: ${love}; }
      '';
    };

    colorsLight = {
      gtk3 = ''
        /* Rosé Pine Dawn */
        @define-color accent_color ${d_iris};
        @define-color accent_bg_color ${d_iris};
        @define-color accent_fg_color ${d_base};
        @define-color destructive_bg_color ${d_love};
        @define-color destructive_fg_color ${d_base};
        @define-color error_bg_color ${d_love};
        @define-color error_fg_color ${d_base};
        @define-color window_bg_color ${d_base};
        @define-color window_fg_color ${d_text};
        @define-color view_bg_color ${d_base};
        @define-color view_fg_color ${d_text};
        @define-color headerbar_bg_color ${d_surface};
        @define-color headerbar_fg_color ${d_text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${d_surface};
        @define-color popover_fg_color ${d_text};
        @define-color card_bg_color ${d_overlay};
        @define-color card_fg_color ${d_text};
        @define-color dialog_bg_color ${d_surface};
        @define-color dialog_fg_color ${d_text};
        @define-color sidebar_bg_color ${d_surface};
        @define-color sidebar_fg_color ${d_text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${d_highlightMed};
        @define-color secondary_sidebar_bg_color ${d_base};
        @define-color secondary_sidebar_fg_color ${d_subtle};
        @define-color theme_unfocused_fg_color ${d_subtle};
        @define-color theme_unfocused_text_color ${d_muted};
        @define-color theme_unfocused_bg_color ${d_base};
        @define-color theme_unfocused_base_color ${d_base};
        @define-color theme_unfocused_selected_bg_color ${d_highlightMed};
        @define-color theme_unfocused_selected_fg_color ${d_text};
      '';

      gtk4 = ''
        /* Rosé Pine Dawn */
        @define-color accent_color ${d_iris};
        @define-color accent_bg_color ${d_iris};
        @define-color accent_fg_color ${d_base};
        @define-color destructive_bg_color ${d_love};
        @define-color destructive_fg_color ${d_base};
        @define-color error_bg_color ${d_love};
        @define-color error_fg_color ${d_base};
        @define-color window_bg_color ${d_base};
        @define-color window_fg_color ${d_text};
        @define-color view_bg_color ${d_base};
        @define-color view_fg_color ${d_text};
        @define-color headerbar_bg_color ${d_surface};
        @define-color headerbar_fg_color ${d_text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${d_surface};
        @define-color popover_fg_color ${d_text};
        @define-color card_bg_color ${d_overlay};
        @define-color card_fg_color ${d_text};
        @define-color dialog_bg_color ${d_surface};
        @define-color dialog_fg_color ${d_text};
        @define-color sidebar_bg_color ${d_surface};
        @define-color sidebar_fg_color ${d_text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${d_highlightMed};
        @define-color secondary_sidebar_bg_color ${d_base};
        @define-color secondary_sidebar_fg_color ${d_subtle};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${d_text}, ${d_surface}, #ffffff, ${d_highlightHigh}, ${d_overlay}, ${d_overlay}, ${d_text}, #ffffff, ${d_text}, ${d_base}, ${d_base}, #000000, ${d_iris}, ${d_highlightMed}, ${d_iris}, ${d_pine}, ${d_overlay}, ${d_highlightLow}, ${d_overlay}, ${d_text}, ${d_subtle}, ${d_iris}
        disabled_colors=${d_muted}, ${d_surface}, #ffffff, ${d_highlightHigh}, ${d_overlay}, ${d_overlay}, ${d_muted}, #ffffff, ${d_muted}, ${d_base}, ${d_base}, #000000, ${d_highlightHigh}, ${d_highlightMed}, ${d_highlightHigh}, ${d_pine}, ${d_overlay}, ${d_highlightLow}, ${d_overlay}, ${d_muted}, ${d_muted}, ${d_highlightHigh}
        inactive_colors=${d_subtle}, ${d_surface}, #ffffff, ${d_highlightHigh}, ${d_overlay}, ${d_overlay}, ${d_subtle}, #ffffff, ${d_subtle}, ${d_base}, ${d_base}, #000000, ${d_iris}, ${d_highlightMed}, ${d_iris}, ${d_pine}, ${d_overlay}, ${d_highlightLow}, ${d_overlay}, ${d_subtle}, ${d_muted}, ${d_iris}
      '';

      kitty = ''
        # Rosé Pine Dawn Kitty
        cursor ${d_rose}
        cursor_text_color ${d_base}
        foreground ${d_text}
        background ${d_base}
        selection_foreground ${d_base}
        selection_background ${d_iris}
        color0  ${d_highlightMed}
        color8  ${d_highlightHigh}
        color1  ${d_love}
        color9  ${d_love}
        color2  ${d_pine}
        color10 ${d_foam}
        color3  ${d_gold}
        color11 ${d_gold}
        color4  ${d_pine}
        color12 ${d_pine}
        color5  ${d_iris}
        color13 ${d_iris}
        color6  ${d_foam}
        color14 ${d_foam}
        color7  ${d_subtle}
        color15 ${d_text}
      '';

      fish = ''
        set -g fish_color_normal ${d_text}
        set -g fish_color_command ${d_iris}
        set -g fish_color_keyword ${d_love}
        set -g fish_color_quote ${d_gold}
        set -g fish_color_redirection ${d_foam}
        set -g fish_color_end ${d_subtle}
        set -g fish_color_error ${d_love}
        set -g fish_color_param ${d_text}
        set -g fish_color_comment ${d_muted}
        set -g fish_color_selection --background=${d_highlightMed}
        set -g fish_color_search_match --background=${d_overlay}
        set -g fish_color_operator ${d_iris}
        set -g fish_color_escape ${d_rose}
        set -g fish_color_autosuggestion ${d_muted}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${d_iris})"
        error_symbol = "[❯](${d_love})"

        [directory]
        style = "bold ${d_foam}"

        [git_branch]
        style = "bold ${d_rose}"

        [cmd_duration]
        style = "bold ${d_subtle}"
      '';

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${d_base};
            text-color:                  ${d_text};
            border-color:                ${d_highlightMed};
            selected-normal-background:  ${d_overlay};
            selected-normal-foreground:  ${d_iris};
            normal-background:           ${d_base};
            normal-foreground:           ${d_text};
        }
        window {
            width: 900px; border: 2px solid; border-color: ${d_highlightMed};
            border-radius: 8px; padding: 12px; background-color: ${d_base};
        }
        mainbox { spacing: 0; children: [ inputbar, listview ]; }
        inputbar {
            padding: 8px 12px; margin: 0 0 10px 0;
            background-color: ${d_surface}; border-radius: 6px;
            children: [ prompt, entry ];
        }
        prompt { text-color: ${d_iris}; padding: 0 8px 0 0; }
        entry { text-color: ${d_text}; placeholder: "Switch profile…"; placeholder-color: ${d_highlightHigh}; }
        listview { columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }
        element {
            orientation: vertical; padding: 10px; spacing: 8px;
            border-radius: 6px; background-color: ${d_surface}; cursor: pointer;
        }
        element selected { background-color: ${d_overlay}; border: 2px solid; border-color: ${d_iris}; }
        element-icon { size: 160px; border-radius: 4px; horizontal-align: 0.5; }
        element-text { horizontal-align: 0.5; vertical-align: 0.5; text-color: inherit; font: "JetBrainsMono Nerd Font 12"; }
      '';
    };

    waybarLight.style = ''
      * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-height: 0; }
      window#waybar {
        background-color: rgba(250, 244, 237, 0.85);
        color: ${d_iris};
        border: 1px solid ${d_highlightMed};
        border-radius: 50px;
        box-shadow: 0 10px 30px rgba(223, 218, 217, 0.5);
      }
      .modules-left, .modules-center, .modules-right { padding: 0 10px; }
      #workspaces { padding: 0px 2px; }
      #workspaces button {
        padding: 0 10px; margin: 0px 2px; background: transparent;
        color: ${d_iris}; border-radius: 10px; border-bottom: 2px solid transparent;
      }
      #workspaces button.active { color: ${d_iris}; background: ${d_overlay}; }
      #workspaces button:hover { background: ${d_overlay}; color: ${d_rose}; }
      #clock { color: ${d_rose}; font-weight: bold; padding: 0 10px; }
      #pulseaudio, #bluetooth, #network, #battery, #tray, #cpu, #memory, #language {
        color: ${d_text}; padding: 0 10px;
      }
      #power-profiles-daemon { color: ${d_text}; padding: 0 10px; }
      #power-profiles-daemon.performance { color: ${d_love}; }
      #power-profiles-daemon.balanced { color: ${d_iris}; }
      #power-profiles-daemon.power-saver { color: ${d_pine}; }
      #battery.critical { color: ${d_love}; }
    '';
  };
}
