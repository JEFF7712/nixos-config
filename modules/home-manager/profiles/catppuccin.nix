{ pkgs, config, ... }:

# Catppuccin desktop profile — Mocha (dark) + Latte (light).
let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  # ── Mocha (dark) ────────────────────────────────────────────────────────────
  rosewater = "#f5e0dc";
  flamingo = "#f2cdcd";
  pink = "#f5c2e7";
  mauve = "#cba6f7";
  red = "#f38ba8";
  maroon = "#eba0ac";
  peach = "#fab387";
  yellow = "#f9e2af";
  green = "#a6e3a1";
  teal = "#94e2d5";
  sky = "#89dceb";
  sapphire = "#74c7ec";
  blue = "#89b4fa";
  lavender = "#b4befe";
  text = "#cdd6f4";
  subtext1 = "#bac2de";
  subtext0 = "#a6adc8";
  overlay2 = "#9399b2";
  overlay1 = "#7f849c";
  overlay0 = "#6c7086";
  surface2 = "#585b70";
  surface1 = "#45475a";
  surface0 = "#313244";
  base = "#1e1e2e";
  mantle = "#181825";
  crust = "#11111b";

  # ── Latte (light) ───────────────────────────────────────────────────────────
  l_rosewater = "#dc8a78";
  l_flamingo = "#dd7878";
  l_pink = "#ea76cb";
  l_mauve = "#8839ef";
  l_red = "#d20f39";
  l_maroon = "#e64553";
  l_peach = "#fe640b";
  l_yellow = "#df8e1d";
  l_green = "#40a02b";
  l_teal = "#179299";
  l_sky = "#04a5e5";
  l_sapphire = "#209fb5";
  l_blue = "#1e66f5";
  l_lavender = "#7287fd";
  l_text = "#4c4f69";
  l_subtext1 = "#5c5f77";
  l_subtext0 = "#6c6f85";
  l_overlay2 = "#7c7f93";
  l_overlay1 = "#8c8fa1";
  l_overlay0 = "#9ca0b0";
  l_surface2 = "#acb0be";
  l_surface1 = "#bcc0cc";
  l_surface0 = "#ccd0da";
  l_base = "#eff1f5";
  l_mantle = "#e6e9ef";
  l_crust = "#dce0e8";
in
{
  desktopProfiles.profiles.catppuccin = {
    bar = "quickshell";

    quickshellTheme = {
      fg = pink;
      bg = "#99181825";
      popupBg = "#cc1e1e2e";
      rawBg = base;
      accent = mauve;
      second = pink;
      warm = peach;
      fresh = green;
      barRadius = "22";
      barHeight = "32";
      showClockDate = "false";
      showWorkspaceNumbers = "false";
      barFont = "FiraCode Nerd Font";
      barBorder = "#00000000";
      pillBg = "#00000000";
      pillBorder = "#00000000";
    };

    makoConfig = theme.mkMakoConfig {
      background = base;
      text = text;
      border = mauve;
      lowBorder = surface1;
      highBackground = mantle;
      highBorder = red;
      highText = text;
    };

    makoConfigLight = theme.mkMakoConfig {
      background = l_base;
      text = l_text;
      border = l_mauve;
      lowBorder = l_surface1;
      highBackground = l_mantle;
      highBorder = l_red;
      highText = l_text;
    };

    cursor = {
      theme = "catppuccin-mocha-mauve-cursors";
      size = 28;
      package = pkgs.catppuccin-cursors.mochaMauve;
    };

    fonts = {
      ui = {
        family = "Inter";
        size = 11;
      };
      mono = {
        family = "FiraCode Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = "adw-gtk3";
      iconTheme = "Tela-purple-dark";
      iconThemeLight = "Tela-purple-light";
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/catppuccin";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/catppuccin-light";

    niri = {
      gaps = 8;
      borderOff = true;
      borderActiveColor = mauve;
      borderInactiveColor = surface1;
      urgentColor = red;
      focusRingOff = true;
      focusRingActiveColor = mauve;
      focusRingInactiveColor = surface1;
      shadowSoftness = 28;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#11111b88";
      shadowInactiveColor = "#11111b44";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = mauve;
      tabIndicatorInactiveColor = surface1;
      windowOpacity = 0.97;
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
        # Catppuccin Kitty (Monochrome Pink/Purple)
        cursor #e8cfe4
        cursor_text_color #1a1623
        foreground #ddd2e8
        background #1b1824
        selection_foreground #1b1824
        selection_background #b9a6cf
        color0  #2b2734
        color8  #4a4458
        color1  #d7a0b3
        color9  #dfaec0
        color2  #bca9d1
        color10 #c8b8db
        color3  #c9b3d8
        color11 #d5c2e1
        color4  #af9bc8
        color12 #bcabd2
        color5  #dcb8d2
        color13 #e5c7dc
        color6  #c8afd9
        color14 #d2bfe0
        color7  #d8cde2
        color15 #e4ddea
      '';

      fish = ''
        set -g fish_color_normal ${text}
        set -g fish_color_command ${mauve}
        set -g fish_color_keyword ${pink}
        set -g fish_color_quote ${lavender}
        set -g fish_color_redirection ${mauve}
        set -g fish_color_end ${pink}
        set -g fish_color_error ${red}
        set -g fish_color_param ${text}
        set -g fish_color_comment ${overlay0}
        set -g fish_color_selection --background=${surface1}
        set -g fish_color_search_match --background=${surface0}
        set -g fish_color_operator ${mauve}
        set -g fish_color_escape ${pink}
        set -g fish_color_autosuggestion ${overlay0}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${flamingo})"
        error_symbol = "[❯](${red})"

        [directory]
        style = "bold ${lavender}"

        [git_branch]
        style = "bold ${pink}"

        [cmd_duration]
        style = "bold ${subtext1}"
      '';

      rofi = theme.mkProfilePickerRofi {
        background = base;
        text = text;
        border = surface1;
        selectedBackground = surface0;
        selectedForeground = mauve;
        inputBackground = mantle;
        prompt = mauve;
        placeholder = surface1;
        elementBackground = surface0;
        elementSelectedBackground = surface1;
        elementSelectedBorder = mauve;
      };
    };
    waybar = {
      config = waybar.mkConfig {
        floating = true;
        pill = true;
        scriptDir = "${config.repoPath}/home/scripts";
      };
      style = waybar.mkPillStyle {
        windowBg = "rgba(24, 24, 37, 0.6)";
        primary = pink;
        borderColor = surface0;
        shadowColor = "rgba(17, 17, 27, 0.45)";
        activeBg = surface0;
        performanceColor = red;
        balancedColor = mauve;
        powerSaverColor = green;
        warningColor = yellow;
        criticalColor = pink;
      };
    };

    colorsLight = {
      gtk3 = ''
        /* Catppuccin Latte */
        @define-color accent_color ${l_mauve};
        @define-color accent_bg_color ${l_mauve};
        @define-color accent_fg_color ${l_base};
        @define-color destructive_bg_color ${l_red};
        @define-color destructive_fg_color ${l_base};
        @define-color error_bg_color ${l_red};
        @define-color error_fg_color ${l_base};
        @define-color window_bg_color ${l_base};
        @define-color window_fg_color ${l_text};
        @define-color view_bg_color ${l_base};
        @define-color view_fg_color ${l_text};
        @define-color headerbar_bg_color ${l_mantle};
        @define-color headerbar_fg_color ${l_text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${l_mantle};
        @define-color popover_fg_color ${l_text};
        @define-color card_bg_color ${l_surface0};
        @define-color card_fg_color ${l_text};
        @define-color dialog_bg_color ${l_mantle};
        @define-color dialog_fg_color ${l_text};
        @define-color sidebar_bg_color ${l_mantle};
        @define-color sidebar_fg_color ${l_text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${l_surface1};
        @define-color secondary_sidebar_bg_color ${l_base};
        @define-color secondary_sidebar_fg_color ${l_subtext1};
        @define-color theme_unfocused_fg_color ${l_subtext0};
        @define-color theme_unfocused_text_color ${l_overlay2};
        @define-color theme_unfocused_bg_color ${l_base};
        @define-color theme_unfocused_base_color ${l_base};
        @define-color theme_unfocused_selected_bg_color ${l_surface1};
        @define-color theme_unfocused_selected_fg_color ${l_base};
      '';

      gtk4 = ''
        /* Catppuccin Latte */
        @define-color accent_color ${l_mauve};
        @define-color accent_bg_color ${l_mauve};
        @define-color accent_fg_color ${l_base};
        @define-color destructive_bg_color ${l_red};
        @define-color destructive_fg_color ${l_base};
        @define-color error_bg_color ${l_red};
        @define-color error_fg_color ${l_base};
        @define-color window_bg_color ${l_base};
        @define-color window_fg_color ${l_text};
        @define-color view_bg_color ${l_base};
        @define-color view_fg_color ${l_text};
        @define-color headerbar_bg_color ${l_mantle};
        @define-color headerbar_fg_color ${l_text};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color popover_bg_color ${l_mantle};
        @define-color popover_fg_color ${l_text};
        @define-color card_bg_color ${l_surface0};
        @define-color card_fg_color ${l_text};
        @define-color dialog_bg_color ${l_mantle};
        @define-color dialog_fg_color ${l_text};
        @define-color sidebar_bg_color ${l_mantle};
        @define-color sidebar_fg_color ${l_text};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_border_color ${l_surface1};
        @define-color secondary_sidebar_bg_color ${l_base};
        @define-color secondary_sidebar_fg_color ${l_subtext1};
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${l_text}, ${l_mantle}, #ffffff, ${l_overlay1}, ${l_surface0}, ${l_surface0}, ${l_text}, #ffffff, ${l_text}, ${l_base}, ${l_base}, #000000, ${l_mauve}, ${l_surface1}, ${l_mauve}, ${l_blue}, ${l_surface0}, ${l_crust}, ${l_surface0}, ${l_text}, ${l_subtext1}, ${l_mauve}
        disabled_colors=${l_overlay0}, ${l_mantle}, #ffffff, ${l_overlay1}, ${l_surface0}, ${l_surface0}, ${l_overlay0}, #ffffff, ${l_overlay0}, ${l_base}, ${l_base}, #000000, ${l_surface2}, ${l_surface1}, ${l_surface2}, ${l_blue}, ${l_surface0}, ${l_crust}, ${l_surface0}, ${l_overlay0}, ${l_overlay1}, ${l_surface2}
        inactive_colors=${l_text}, ${l_mantle}, #ffffff, ${l_overlay1}, ${l_surface0}, ${l_surface0}, ${l_subtext1}, #ffffff, ${l_text}, ${l_base}, ${l_base}, #000000, ${l_mauve}, ${l_surface1}, ${l_mauve}, ${l_blue}, ${l_surface0}, ${l_crust}, ${l_surface0}, ${l_text}, ${l_subtext1}, ${l_mauve}
      '';

      kitty = ''
        # Catppuccin Latte Kitty
        cursor ${l_mauve}
        cursor_text_color ${l_base}
        foreground ${l_text}
        background ${l_base}
        selection_foreground ${l_base}
        selection_background ${l_mauve}
        color0  ${l_surface1}
        color8  ${l_surface2}
        color1  ${l_red}
        color9  ${l_red}
        color2  ${l_green}
        color10 ${l_green}
        color3  ${l_yellow}
        color11 ${l_yellow}
        color4  ${l_blue}
        color12 ${l_blue}
        color5  ${l_mauve}
        color13 ${l_mauve}
        color6  ${l_teal}
        color14 ${l_teal}
        color7  ${l_subtext1}
        color15 ${l_text}
      '';

      fish = ''
        set -g fish_color_normal ${l_text}
        set -g fish_color_command ${l_mauve}
        set -g fish_color_keyword ${l_pink}
        set -g fish_color_quote ${l_green}
        set -g fish_color_redirection ${l_teal}
        set -g fish_color_end ${l_pink}
        set -g fish_color_error ${l_red}
        set -g fish_color_param ${l_text}
        set -g fish_color_comment ${l_overlay0}
        set -g fish_color_selection --background=${l_surface1}
        set -g fish_color_search_match --background=${l_surface0}
        set -g fish_color_operator ${l_mauve}
        set -g fish_color_escape ${l_pink}
        set -g fish_color_autosuggestion ${l_overlay1}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${l_mauve})"
        error_symbol = "[❯](${l_red})"

        [directory]
        style = "bold ${l_blue}"

        [git_branch]
        style = "bold ${l_pink}"

        [cmd_duration]
        style = "bold ${l_subtext1}"
      '';

      rofi = theme.mkProfilePickerRofi {
        background = l_base;
        text = l_text;
        border = l_surface1;
        selectedBackground = l_surface0;
        selectedForeground = l_mauve;
        inputBackground = l_mantle;
        prompt = l_mauve;
        placeholder = l_surface2;
        elementBackground = l_surface0;
        elementSelectedBackground = l_surface1;
        elementSelectedBorder = l_mauve;
      };
    };

    waybarLight.style = waybar.mkPillStyle {
      windowBg = "rgba(239, 241, 245, 0.85)";
      primary = l_mauve;
      borderColor = l_surface1;
      shadowColor = "rgba(220, 224, 232, 0.6)";
      activeBg = l_surface0;
      textColor = l_text;
      performanceColor = l_red;
      balancedColor = l_mauve;
      powerSaverColor = l_green;
      warningColor = l_yellow;
      criticalColor = l_red;
    };
  };
}
