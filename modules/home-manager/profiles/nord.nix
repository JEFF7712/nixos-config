{ pkgs, ... }:

# quickshell is required by this profile.
# nordzy cursor/icon themes are used when available.
# mako handles notifications (noctalia manages its own when active).

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
  home.packages = [ pkgs.waypaper pkgs.rofi pkgs.python3Packages.pywal pkgs.mako ];

  xdg.configFile."mako/config".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color=#2e3440
    text-color=#d8dee9
    border-color=#88c0d0
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
    border-color=#4c566a
    default-timeout=3000

    [urgency=high]
    background-color=#3b4252
    border-color=#bf616a
    text-color=#eceff4
    default-timeout=0
  '';

  desktopProfiles.profiles.nord = {
    bar = "quickshell";

    quickshell.colors = builtins.toJSON {
      background     = nord0;
      surface        = nord1;
      surfaceVariant = nord2;
      border         = nord3;
      text           = nord6;
      textSubtle     = nord4;
      accent         = nord8;
      accentText     = nord0;
      success        = nord14;
      warning        = nord13;
      error          = nord11;
    };

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

      rofi = ''
        * {
            font:                        "JetBrainsMono Nerd Font 11";
            background-color:            ${nord0};
            text-color:                  ${nord4};
            border-color:                ${nord3};
            selected-normal-background:  ${nord1};
            selected-normal-foreground:  ${nord8};
            normal-background:           ${nord0};
            normal-foreground:           ${nord4};
        }

        window {
            width:              900px;
            border:             2px solid;
            border-color:       ${nord3};
            border-radius:      8px;
            padding:            12px;
            background-color:   ${nord0};
        }

        mainbox {
            spacing:            0;
            children:           [ inputbar, listview ];
        }

        inputbar {
            padding:            8px 12px;
            margin:             0 0 10px 0;
            background-color:   ${nord1};
            border-radius:      6px;
            children:           [ prompt, entry ];
        }

        prompt {
            text-color:         ${nord8};
            padding:            0 8px 0 0;
        }

        entry {
            text-color:         ${nord4};
            placeholder:        "Switch profile…";
            placeholder-color:  ${nord3};
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
            background-color:   ${nord1};
            cursor:             pointer;
        }

        element selected {
            background-color:   ${nord2};
            border:             2px solid;
            border-color:       ${nord8};
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

  };
}
