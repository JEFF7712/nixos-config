{ config, ... }:

let
  waybar = import ../../../lib/waybar.nix;

  # Dark — neutral greys only
  bg0 = "#141414";
  bg1 = "#1c1c1c";
  bg2 = "#262626";
  bg3 = "#3a3a3a";
  fg0 = "#f2f2f2";
  fg1 = "#c8c8c8";
  fg2 = "#8a8a8a";
  accent = "#e0e0e0";
  err = "#5c5c5c";

  # Light
  l_bg0 = "#fafafa";
  l_bg1 = "#f0f0f0";
  l_bg2 = "#e2e2e2";
  l_bg3 = "#c8c8c8";
  l_fg0 = "#141414";
  l_fg1 = "#2e2e2e";
  l_fg2 = "#5a5a5a";
  l_accent = "#1a1a1a";
  l_err = "#a3a3a3";

  rofiBlock = bg: surface: border: fg: subtle: selBorder: selFg: selBg: ''
    * {
        font:                        "JetBrainsMono Nerd Font 11";
        background-color:            ${bg};
        text-color:                  ${fg};
        border-color:                ${border};
        selected-normal-background:  ${surface};
        selected-normal-foreground:  ${selFg};
        normal-background:           ${bg};
        normal-foreground:           ${fg};
    }

    window {
        width:              900px;
        border:             1px solid;
        border-color:       ${border};
        border-radius:      4px;
        padding:            12px;
        background-color:   ${bg};
    }

    mainbox {
        spacing:            0;
        children:           [ inputbar, listview ];
    }

    inputbar {
        padding:            8px 12px;
        margin:             0 0 10px 0;
        background-color:   ${surface};
        border-radius:      4px;
        children:           [ prompt, entry ];
    }

    prompt {
        text-color:         ${fg};
        padding:            0 8px 0 0;
    }

    entry {
        text-color:         ${fg};
        placeholder:        "Switch profile…";
        placeholder-color:  ${subtle};
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
        border-radius:      4px;
        background-color:   ${surface};
        cursor:             pointer;
    }

      element selected {
          background-color:   ${selBg};
          border:             1px solid;
          border-color:       ${selBorder};
      }

    element-icon {
        size:               160px;
        border-radius:      2px;
        horizontal-align:   0.5;
    }

    element-text {
        horizontal-align:   0.5;
        vertical-align:     0.5;
        text-color:         inherit;
        font:               "JetBrainsMono Nerd Font 12";
    }
  '';
in
{
  xdg.configFile."mako/config".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color=${bg0}
    text-color=${fg1}
    border-color=${bg3}
    border-size=1
    border-radius=4
    width=320
    padding=12
    margin=10
    default-timeout=5000
    icons=1
    max-icon-size=48
    layer=overlay

    [urgency=low]
    border-color=${bg2}
    default-timeout=3000

    [urgency=high]
    background-color=${bg1}
    border-color=${err}
    text-color=${fg0}
    default-timeout=0
  '';

  desktopProfiles.profiles.minimal = {
    bar = "waybar";

    cursor = {
      theme = "Adwaita";
      size = 24;
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/minimal";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/minimal-light";

    niri = {
      gaps = 12;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 12;
      shadowSpread = 2;
      shadowOffsetX = 0;
      shadowOffsetY = 2;
      shadowColor = "#00000055";
      shadowInactiveColor = "#00000033";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = fg1;
      tabIndicatorInactiveColor = bg3;
      windowOpacity = 1.0;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        /* Minimal dark */
        @define-color accent_color ${accent};
        @define-color accent_bg_color ${bg3};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${err};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${err};
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
        @define-color theme_unfocused_fg_color ${fg2};
        @define-color theme_unfocused_text_color ${fg2};
        @define-color theme_unfocused_bg_color ${bg0};
        @define-color theme_unfocused_base_color ${bg0};
        @define-color theme_unfocused_selected_bg_color ${bg2};
        @define-color theme_unfocused_selected_fg_color ${fg0};
      '';

      gtk4 = ''
        /* Minimal dark */
        @define-color accent_color ${accent};
        @define-color accent_bg_color ${bg3};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${err};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${err};
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
        active_colors=${fg1}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg1}, #ffffff, ${fg1}, ${bg0}, ${bg0}, #000000, ${accent}, ${bg2}, ${accent}, ${fg2}, ${bg1}, ${bg0}, ${bg1}, ${fg1}, ${fg2}, ${accent}
        disabled_colors=${fg2}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg2}, #ffffff, ${fg2}, ${bg0}, ${bg0}, #000000, ${bg3}, ${bg2}, ${bg3}, ${fg2}, ${bg1}, ${bg0}, ${bg1}, ${fg2}, ${fg2}, ${bg3}
        inactive_colors=${fg2}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg2}, #ffffff, ${fg2}, ${bg0}, ${bg0}, #000000, ${accent}, ${bg2}, ${accent}, ${fg2}, ${bg1}, ${bg0}, ${bg1}, ${fg2}, ${fg2}, ${accent}
      '';

      kitty = ''
        # Minimal dark
        cursor ${fg1}
        cursor_text_color ${bg0}
        foreground ${fg1}
        background ${bg0}
        selection_foreground ${bg0}
        selection_background ${bg3}
        color0  ${bg1}
        color8  ${bg3}
        color1  ${err}
        color9  ${err}
        color2  ${fg2}
        color10 ${fg1}
        color3  ${fg2}
        color11 ${fg1}
        color4  ${fg2}
        color12 ${fg1}
        color5  ${fg2}
        color13 ${fg1}
        color6  ${fg2}
        color14 ${fg1}
        color7  ${fg1}
        color15 ${fg0}
      '';

      fish = ''
        set -g fish_color_normal ${fg1}
        set -g fish_color_command ${fg0}
        set -g fish_color_keyword ${fg0}
        set -g fish_color_quote ${fg2}
        set -g fish_color_redirection ${fg2}
        set -g fish_color_end ${fg2}
        set -g fish_color_error ${fg0}
        set -g fish_color_param ${fg1}
        set -g fish_color_comment ${fg2}
        set -g fish_color_selection --background=${bg2}
        set -g fish_color_search_match --background=${bg1}
        set -g fish_color_operator ${fg1}
        set -g fish_color_escape ${fg2}
        set -g fish_color_autosuggestion ${fg2}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${fg1})"
        error_symbol = "[❯](${fg0})"

        [directory]
        style = "bold ${fg0}"

        [git_branch]
        style = "bold ${fg2}"

        [cmd_duration]
        style = "bold ${fg2}"
      '';

      rofi = rofiBlock bg0 bg1 bg3 fg1 fg2 accent accent bg2;
    };

    waybar = {
      config = waybar.mkConfig { };
      style = waybar.mkFlatStyle {
        fg = fg1;
        activeText = fg0;
        activeUnderline = fg0;
        clockColor = fg1;
        performanceColor = fg2;
        balancedColor = fg1;
        powerSaverColor = fg2;
        criticalColor = fg0;
        hoverBg = "rgba(255,255,255,0.06)";
      };
    };

    colorsLight = {
      gtk3 = ''
        /* Minimal light */
        @define-color accent_color ${l_accent};
        @define-color accent_bg_color ${l_bg3};
        @define-color accent_fg_color ${l_bg0};
        @define-color destructive_bg_color ${l_err};
        @define-color destructive_fg_color ${l_fg0};
        @define-color error_bg_color ${l_err};
        @define-color error_fg_color ${l_fg0};
        @define-color window_bg_color ${l_bg0};
        @define-color window_fg_color ${l_fg1};
        @define-color view_bg_color ${l_bg0};
        @define-color view_fg_color ${l_fg1};
        @define-color headerbar_bg_color ${l_bg1};
        @define-color headerbar_fg_color ${l_fg1};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${l_bg1};
        @define-color popover_fg_color ${l_fg1};
        @define-color card_bg_color ${l_bg1};
        @define-color card_fg_color ${l_fg1};
        @define-color dialog_bg_color ${l_bg0};
        @define-color dialog_fg_color ${l_fg1};
        @define-color sidebar_bg_color ${l_bg1};
        @define-color sidebar_fg_color ${l_fg1};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${l_bg2};
        @define-color secondary_sidebar_bg_color ${l_bg0};
        @define-color secondary_sidebar_fg_color ${l_fg2};
        @define-color theme_unfocused_fg_color ${l_fg2};
        @define-color theme_unfocused_text_color ${l_fg2};
        @define-color theme_unfocused_bg_color ${l_bg0};
        @define-color theme_unfocused_base_color ${l_bg0};
        @define-color theme_unfocused_selected_bg_color ${l_bg2};
        @define-color theme_unfocused_selected_fg_color ${l_fg0};
      '';

      gtk4 = ''
        /* Minimal light */
        @define-color accent_color ${l_accent};
        @define-color accent_bg_color ${l_bg3};
        @define-color accent_fg_color ${l_bg0};
        @define-color destructive_bg_color ${l_err};
        @define-color destructive_fg_color ${l_fg0};
        @define-color error_bg_color ${l_err};
        @define-color error_fg_color ${l_fg0};
        @define-color window_bg_color ${l_bg0};
        @define-color window_fg_color ${l_fg1};
        @define-color view_bg_color ${l_bg0};
        @define-color view_fg_color ${l_fg1};
        @define-color headerbar_bg_color ${l_bg1};
        @define-color headerbar_fg_color ${l_fg1};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${l_bg1};
        @define-color popover_fg_color ${l_fg1};
        @define-color card_bg_color ${l_bg1};
        @define-color card_fg_color ${l_fg1};
        @define-color dialog_bg_color ${l_bg0};
        @define-color dialog_fg_color ${l_fg1};
        @define-color sidebar_bg_color ${l_bg1};
        @define-color sidebar_fg_color ${l_fg1};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${l_bg2};
        @define-color secondary_sidebar_bg_color ${l_bg0};
        @define-color secondary_sidebar_fg_color ${l_fg2};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${l_fg1}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg1}, #ffffff, ${l_fg1}, ${l_bg0}, ${l_bg0}, #000000, ${l_accent}, ${l_bg2}, ${l_accent}, ${l_fg2}, ${l_bg1}, ${l_bg0}, ${l_bg1}, ${l_fg1}, ${l_fg2}, ${l_accent}
        disabled_colors=${l_fg2}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg2}, #ffffff, ${l_fg2}, ${l_bg0}, ${l_bg0}, #000000, ${l_bg3}, ${l_bg2}, ${l_bg3}, ${l_fg2}, ${l_bg1}, ${l_bg0}, ${l_bg1}, ${l_fg2}, ${l_fg2}, ${l_bg3}
        inactive_colors=${l_fg2}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg2}, #ffffff, ${l_fg2}, ${l_bg0}, ${l_bg0}, #000000, ${l_accent}, ${l_bg2}, ${l_accent}, ${l_fg2}, ${l_bg1}, ${l_bg0}, ${l_bg1}, ${l_fg2}, ${l_fg2}, ${l_accent}
      '';

      kitty = ''
        # Minimal light
        cursor ${l_fg1}
        cursor_text_color ${l_bg0}
        foreground ${l_fg1}
        background ${l_bg0}
        selection_foreground ${l_bg0}
        selection_background ${l_bg3}
        color0  ${l_bg1}
        color8  ${l_bg3}
        color1  ${l_err}
        color9  ${l_err}
        color2  ${l_fg2}
        color10 ${l_fg1}
        color3  ${l_fg2}
        color11 ${l_fg1}
        color4  ${l_fg2}
        color12 ${l_fg1}
        color5  ${l_fg2}
        color13 ${l_fg1}
        color6  ${l_fg2}
        color14 ${l_fg1}
        color7  ${l_fg1}
        color15 ${l_fg0}
      '';

      fish = ''
        set -g fish_color_normal ${l_fg1}
        set -g fish_color_command ${l_fg0}
        set -g fish_color_keyword ${l_fg0}
        set -g fish_color_quote ${l_fg2}
        set -g fish_color_redirection ${l_fg2}
        set -g fish_color_end ${l_fg2}
        set -g fish_color_error ${l_fg0}
        set -g fish_color_param ${l_fg1}
        set -g fish_color_comment ${l_fg2}
        set -g fish_color_selection --background=${l_bg2}
        set -g fish_color_search_match --background=${l_bg1}
        set -g fish_color_operator ${l_fg1}
        set -g fish_color_escape ${l_fg2}
        set -g fish_color_autosuggestion ${l_fg2}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${l_fg1})"
        error_symbol = "[❯](${l_fg0})"

        [directory]
        style = "bold ${l_fg0}"

        [git_branch]
        style = "bold ${l_fg2}"

        [cmd_duration]
        style = "bold ${l_fg2}"
      '';

      rofi = rofiBlock l_bg0 l_bg1 l_bg3 l_fg0 l_fg2 l_accent l_accent l_bg2;
    };

    waybarLight.style = waybar.mkFlatStyle {
      fg = l_fg1;
      activeText = l_fg0;
      activeUnderline = l_fg0;
      clockColor = l_fg1;
      performanceColor = l_fg2;
      balancedColor = l_fg1;
      powerSaverColor = l_fg2;
      criticalColor = l_fg0;
      hoverBg = "rgba(0,0,0,0.06)";
    };
  };
}
