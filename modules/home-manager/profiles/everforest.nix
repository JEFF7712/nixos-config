{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  # ── Everforest Dark Hard ─────────────────────────────────────────────────────
  bg0 = "#272e33";
  bg1 = "#2e383c";
  bg2 = "#374145";
  bg3 = "#414b50";
  bg4 = "#495156";
  bg5 = "#4f5b58";
  fg = "#d3c6aa";
  red = "#e67e80";
  orange = "#e69875";
  yellow = "#dbbc7f";
  green = "#a7c080";
  aqua = "#83c092";
  blue = "#7fbbb3";
  purple = "#d699b6";
  grey0 = "#7a8478";
  grey1 = "#859289";
  grey2 = "#9da9a0";

  # ── Everforest Light Hard ────────────────────────────────────────────────────
  l_bg0 = "#fff9e8";
  l_bg1 = "#f4f0d9";
  l_bg2 = "#efebd4";
  l_bg3 = "#e6e2cc";
  l_bg4 = "#e0dcc7";
  l_bg5 = "#bec5b2";
  l_fg = "#5c6a72";
  l_red = "#f85552";
  l_orange = "#f57d26";
  l_yellow = "#dfa000";
  l_green = "#8da101";
  l_aqua = "#35a77c";
  l_blue = "#3a94c5";
  l_purple = "#df69ba";
  l_grey0 = "#a6b0a0";
  l_grey1 = "#939f91";
  l_grey2 = "#829181";
in
{
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
      size = 24;
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/everforest";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/everforest-light";

    niri = {
      gaps = 18;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 20;
      shadowSpread = 3;
      shadowOffsetX = 0;
      shadowOffsetY = 4;
      shadowColor = "#00000080";
      shadowInactiveColor = "#00000040";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = green;
      tabIndicatorInactiveColor = bg3;
      windowOpacity = 0.96;
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
      config = waybar.mkConfig { };
      style = waybar.mkFlatStyle {
        fg = fg;
        activeText = green;
        activeUnderline = green;
        clockColor = yellow;
        performanceColor = red;
        balancedColor = green;
        powerSaverColor = aqua;
        criticalColor = red;
      };
    };

    colorsLight = {
      gtk3 = ''
        /* Everforest Light Hard */
        @define-color accent_color ${l_green};
        @define-color accent_bg_color ${l_green};
        @define-color accent_fg_color ${l_bg0};
        @define-color destructive_bg_color ${l_red};
        @define-color destructive_fg_color ${l_fg};
        @define-color error_bg_color ${l_red};
        @define-color error_fg_color ${l_fg};
        @define-color window_bg_color ${l_bg0};
        @define-color window_fg_color ${l_fg};
        @define-color view_bg_color ${l_bg0};
        @define-color view_fg_color ${l_fg};
        @define-color headerbar_bg_color ${l_bg1};
        @define-color headerbar_fg_color ${l_fg};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${l_bg1};
        @define-color popover_fg_color ${l_fg};
        @define-color card_bg_color ${l_bg1};
        @define-color card_fg_color ${l_fg};
        @define-color dialog_bg_color ${l_bg0};
        @define-color dialog_fg_color ${l_fg};
        @define-color sidebar_bg_color ${l_bg1};
        @define-color sidebar_fg_color ${l_fg};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${l_bg2};
        @define-color secondary_sidebar_bg_color ${l_bg0};
        @define-color secondary_sidebar_fg_color ${l_grey2};
        @define-color theme_unfocused_fg_color ${l_grey2};
        @define-color theme_unfocused_text_color ${l_grey1};
        @define-color theme_unfocused_bg_color ${l_bg0};
        @define-color theme_unfocused_base_color ${l_bg0};
        @define-color theme_unfocused_selected_bg_color ${l_bg2};
        @define-color theme_unfocused_selected_fg_color ${l_fg};
      '';

      gtk4 = ''
        /* Everforest Light Hard */
        @define-color accent_color ${l_green};
        @define-color accent_bg_color ${l_green};
        @define-color accent_fg_color ${l_bg0};
        @define-color destructive_bg_color ${l_red};
        @define-color destructive_fg_color ${l_fg};
        @define-color error_bg_color ${l_red};
        @define-color error_fg_color ${l_fg};
        @define-color window_bg_color ${l_bg0};
        @define-color window_fg_color ${l_fg};
        @define-color view_bg_color ${l_bg0};
        @define-color view_fg_color ${l_bg0};
        @define-color headerbar_bg_color ${l_bg1};
        @define-color headerbar_fg_color ${l_fg};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${l_bg1};
        @define-color popover_fg_color ${l_fg};
        @define-color card_bg_color ${l_bg1};
        @define-color card_fg_color ${l_fg};
        @define-color dialog_bg_color ${l_bg0};
        @define-color dialog_fg_color ${l_fg};
        @define-color sidebar_bg_color ${l_bg1};
        @define-color sidebar_fg_color ${l_fg};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${l_bg2};
        @define-color secondary_sidebar_bg_color ${l_bg0};
        @define-color secondary_sidebar_fg_color ${l_grey2};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${l_fg}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg}, #ffffff, ${l_fg}, ${l_bg0}, ${l_bg0}, #000000, ${l_green}, ${l_bg0}, ${l_green}, ${l_blue}, ${l_bg1}, ${l_bg0}, ${l_bg1}, ${l_fg}, ${l_grey1}, ${l_green}
        disabled_colors=${l_grey1}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_grey1}, #ffffff, ${l_grey1}, ${l_bg0}, ${l_bg0}, #000000, ${l_bg3}, ${l_bg2}, ${l_bg3}, ${l_blue}, ${l_bg1}, ${l_bg0}, ${l_bg1}, ${l_grey1}, ${l_grey0}, ${l_bg3}
        inactive_colors=${l_grey2}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_grey2}, #ffffff, ${l_grey2}, ${l_bg0}, ${l_bg0}, #000000, ${l_green}, ${l_bg0}, ${l_green}, ${l_blue}, ${l_bg1}, ${l_bg0}, ${l_bg1}, ${l_grey2}, ${l_grey1}, ${l_green}
      '';

      kitty = ''
        # Everforest Light Hard Kitty
        cursor ${l_fg}
        cursor_text_color ${l_bg0}
        foreground ${l_fg}
        background ${l_bg0}
        selection_foreground ${l_bg0}
        selection_background ${l_green}
        color0  ${l_bg3}
        color8  ${l_bg5}
        color1  ${l_red}
        color9  ${l_red}
        color2  ${l_green}
        color10 ${l_green}
        color3  ${l_yellow}
        color11 ${l_yellow}
        color4  ${l_blue}
        color12 ${l_blue}
        color5  ${l_purple}
        color13 ${l_purple}
        color6  ${l_aqua}
        color14 ${l_aqua}
        color7  ${l_grey2}
        color15 ${l_fg}
      '';

      fish = ''
        set -g fish_color_normal ${l_fg}
        set -g fish_color_command ${l_green}
        set -g fish_color_keyword ${l_aqua}
        set -g fish_color_quote ${l_yellow}
        set -g fish_color_redirection ${l_blue}
        set -g fish_color_end ${l_grey1}
        set -g fish_color_error ${l_red}
        set -g fish_color_param ${l_fg}
        set -g fish_color_comment ${l_grey0}
        set -g fish_color_selection --background=${l_bg2}
        set -g fish_color_search_match --background=${l_bg1}
        set -g fish_color_operator ${l_aqua}
        set -g fish_color_escape ${l_orange}
        set -g fish_color_autosuggestion ${l_grey0}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${l_green})"
        error_symbol = "[❯](${l_red})"

        [directory]
        style = "bold ${l_aqua}"

        [git_branch]
        style = "bold ${l_yellow}"

        [cmd_duration]
        style = "bold ${l_grey1}"
      '';

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${l_bg0};
            text-color:                  ${l_fg};
            border-color:                ${l_bg2};
            selected-normal-background:  ${l_bg1};
            selected-normal-foreground:  ${l_green};
            normal-background:           ${l_bg0};
            normal-foreground:           ${l_fg};
        }
        window { width: 900px; border: 2px solid; border-color: ${l_bg2}; border-radius: 8px; padding: 12px; background-color: ${l_bg0}; }
        mainbox { spacing: 0; children: [ inputbar, listview ]; }
        inputbar {
            padding: 8px 12px; margin: 0 0 10px 0;
            background-color: ${l_bg1}; border-radius: 6px; children: [ prompt, entry ];
        }
        prompt { text-color: ${l_green}; padding: 0 8px 0 0; }
        entry { text-color: ${l_fg}; placeholder: "Switch profile…"; placeholder-color: ${l_bg3}; }
        listview { columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }
        element {
            orientation: vertical; padding: 10px; spacing: 8px;
            border-radius: 6px; background-color: ${l_bg1}; cursor: pointer;
        }
        element selected { background-color: ${l_bg2}; border: 2px solid; border-color: ${l_green}; }
        element-icon { size: 160px; border-radius: 4px; horizontal-align: 0.5; }
        element-text { horizontal-align: 0.5; vertical-align: 0.5; text-color: inherit; font: "JetBrainsMono Nerd Font 12"; }
      '';
    };

    waybarLight.style = waybar.mkFlatStyle {
      fg = l_fg;
      activeText = l_green;
      activeUnderline = l_green;
      clockColor = l_yellow;
      performanceColor = l_red;
      balancedColor = l_green;
      powerSaverColor = l_aqua;
      criticalColor = l_red;
      hoverBg = "rgba(0,0,0,0.05)";
    };
  };
}
