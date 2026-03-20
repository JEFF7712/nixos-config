{ pkgs, ... }:

let
  # ── Gruvbox Dark Hard ────────────────────────────────────────────────────────
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

  # ── Gruvbox Light Hard ───────────────────────────────────────────────────────
  l_bg0h   = "#f9f5d7";
  l_bg0    = "#fbf1c7";
  l_bg1    = "#ebdbb2";
  l_bg2    = "#d5c4a1";
  l_bg3    = "#bdae93";
  l_bg4    = "#a89984";
  l_fg0    = "#282828";
  l_fg1    = "#3c3836";
  l_fg2    = "#504945";
  l_fg3    = "#665c54";
  l_fg4    = "#7c6f64";
  l_red    = "#9d0006";
  l_green  = "#79740e";
  l_yellow = "#b57614";
  l_blue   = "#076678";
  l_purple = "#8f3f71";
  l_aqua   = "#427b58";
  l_orange = "#af3a03";
  l_gray   = "#928374";
in {
  home.packages = [ pkgs.waypaper pkgs.rofi pkgs.python3Packages.pywal pkgs.mako ];

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
    bar = "quickshell";

    quickshell.colors = builtins.toJSON {
      background     = bg0;
      surface        = bg1;
      surfaceVariant = bg2;
      border         = bg3;
      text           = fg1;
      textSubtle     = fg2;
      accent         = blue;
      accentText     = bg0;
      success        = green;
      warning        = yellow;
      error          = red;
    };

    quickshell.colorsLight = builtins.toJSON {
      background     = l_bg0;
      surface        = l_bg1;
      surfaceVariant = l_bg2;
      border         = l_bg3;
      text           = l_fg1;
      textSubtle     = l_fg2;
      accent         = l_blue;
      accentText     = l_bg0;
      success        = l_green;
      warning        = l_yellow;
      error          = l_red;
    };

    cursor = {
      theme   = "Capitaine Cursors (Gruvbox)";
      size    = 24;
      package = pkgs.capitaine-cursors-themed;
    };

    wallpaperDir      = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/gruvbox";
    wallpaperDirLight = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/gruvbox-light";

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
            text-color:         ${yellow};
            padding:            0 8px 0 0;
        }

        entry {
            text-color:         ${fg1};
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
            border-color:       ${yellow};
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

    colorsLight = {
      gtk3 = ''
        /* Gruvbox Light Hard */
        @define-color accent_color ${l_yellow};
        @define-color accent_bg_color ${l_yellow};
        @define-color accent_fg_color ${l_fg0};
        @define-color destructive_bg_color ${l_red};
        @define-color destructive_fg_color ${l_bg0};
        @define-color error_bg_color ${l_red};
        @define-color error_fg_color ${l_bg0};
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
        @define-color theme_unfocused_fg_color ${l_fg3};
        @define-color theme_unfocused_text_color ${l_fg4};
        @define-color theme_unfocused_bg_color ${l_bg0};
        @define-color theme_unfocused_base_color ${l_bg0};
        @define-color theme_unfocused_selected_bg_color ${l_bg2};
        @define-color theme_unfocused_selected_fg_color ${l_fg1};
      '';

      gtk4 = ''
        /* Gruvbox Light Hard */
        @define-color accent_color ${l_yellow};
        @define-color accent_bg_color ${l_yellow};
        @define-color accent_fg_color ${l_fg0};
        @define-color destructive_bg_color ${l_red};
        @define-color destructive_fg_color ${l_bg0};
        @define-color error_bg_color ${l_red};
        @define-color error_fg_color ${l_bg0};
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
        active_colors=${l_fg1}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg1}, #ffffff, ${l_fg1}, ${l_bg0}, ${l_bg0}, #000000, ${l_yellow}, ${l_bg0}, ${l_yellow}, ${l_blue}, ${l_bg1}, ${l_bg0h}, ${l_bg1}, ${l_fg1}, ${l_fg4}, ${l_yellow}
        disabled_colors=${l_fg4}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg4}, #ffffff, ${l_fg4}, ${l_bg0}, ${l_bg0}, #000000, ${l_bg3}, ${l_bg2}, ${l_bg3}, ${l_blue}, ${l_bg1}, ${l_bg0h}, ${l_bg1}, ${l_fg4}, ${l_gray}, ${l_bg3}
        inactive_colors=${l_fg2}, ${l_bg1}, #ffffff, ${l_bg3}, ${l_bg2}, ${l_bg2}, ${l_fg2}, #ffffff, ${l_fg2}, ${l_bg0}, ${l_bg0}, #000000, ${l_yellow}, ${l_bg0}, ${l_yellow}, ${l_blue}, ${l_bg1}, ${l_bg0h}, ${l_bg1}, ${l_fg2}, ${l_fg4}, ${l_yellow}
      '';

      kitty = ''
        # Gruvbox Light Hard Kitty
        cursor ${l_fg1}
        cursor_text_color ${l_bg0}
        foreground ${l_fg1}
        background ${l_bg0}
        selection_foreground ${l_bg0}
        selection_background ${l_yellow}
        color0  ${l_bg1}
        color8  ${l_bg3}
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
        color7  ${l_fg4}
        color15 ${l_fg1}
      '';

      fish = ''
        set -g fish_color_normal ${l_fg1}
        set -g fish_color_command ${l_yellow}
        set -g fish_color_keyword ${l_orange}
        set -g fish_color_quote ${l_green}
        set -g fish_color_redirection ${l_aqua}
        set -g fish_color_end ${l_fg4}
        set -g fish_color_error ${l_red}
        set -g fish_color_param ${l_fg2}
        set -g fish_color_comment ${l_bg4}
        set -g fish_color_selection --background=${l_bg2}
        set -g fish_color_search_match --background=${l_bg1}
        set -g fish_color_operator ${l_orange}
        set -g fish_color_escape ${l_purple}
        set -g fish_color_autosuggestion ${l_bg4}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${l_yellow})"
        error_symbol = "[❯](${l_red})"

        [directory]
        style = "bold ${l_blue}"

        [git_branch]
        style = "bold ${l_orange}"

        [cmd_duration]
        style = "bold ${l_fg4}"
      '';

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${l_bg0};
            text-color:                  ${l_fg1};
            border-color:                ${l_bg2};
            selected-normal-background:  ${l_bg1};
            selected-normal-foreground:  ${l_yellow};
            normal-background:           ${l_bg0};
            normal-foreground:           ${l_fg1};
        }

        window {
            width:              900px;
            border:             2px solid;
            border-color:       ${l_bg2};
            border-radius:      8px;
            padding:            12px;
            background-color:   ${l_bg0};
        }

        mainbox { spacing: 0; children: [ inputbar, listview ]; }

        inputbar {
            padding:            8px 12px;
            margin:             0 0 10px 0;
            background-color:   ${l_bg1};
            border-radius:      6px;
            children:           [ prompt, entry ];
        }

        prompt { text-color: ${l_yellow}; padding: 0 8px 0 0; }

        entry {
            text-color:         ${l_fg1};
            placeholder:        "Switch profile…";
            placeholder-color:  ${l_bg3};
        }

        listview { columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }

        element {
            orientation: vertical; padding: 10px; spacing: 8px;
            border-radius: 6px; background-color: ${l_bg1}; cursor: pointer;
        }

        element selected { background-color: ${l_bg2}; border: 2px solid; border-color: ${l_yellow}; }

        element-icon { size: 160px; border-radius: 4px; horizontal-align: 0.5; }

        element-text {
            horizontal-align: 0.5; vertical-align: 0.5;
            text-color: inherit; font: "JetBrainsMono Nerd Font 12";
        }
      '';
    };

  };
}
