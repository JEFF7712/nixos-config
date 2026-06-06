{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
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
  desktopProfiles.profiles.everforest = {
    bar = "quickshell";

    quickshellTheme = {
      fg = fg;
      bg = "#66272e33";
      popupBg = "#cc272e33";
      rawBg = bg0;
      accent = green;
      second = grey2;
      warm = orange;
      fresh = blue;
      barRadius = "10";
      barHeight = "32";
      showClockDate = "false";
      showWorkspaceNumbers = "false";
      barFont = "Hack Nerd Font";
      barBorder = "#00000000";
      pillBorder = "#1d2e383c";
    };

    makoConfig = theme.mkMakoConfig {
      background = bg0;
      text = fg;
      border = green;
      lowBorder = bg4;
      highBackground = bg1;
      highBorder = red;
      highText = fg;
    };

    makoConfigLight = theme.mkMakoConfig {
      background = l_bg0;
      text = l_fg;
      border = l_green;
      lowBorder = l_bg3;
      highBackground = l_bg1;
      highBorder = l_red;
      highText = l_fg;
    };

    cursor = {
      theme = "Bibata-Modern-Classic";
      size = 24;
      package = pkgs.bibata-cursors;
    };

    fonts = {
      ui = {
        family = "Noto Sans";
        size = 11;
      };
      mono = {
        family = "Hack Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = "adw-gtk3";
      iconTheme = "Tela-green-dark";
      iconThemeLight = "Tela-green-light";
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/everforest";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/everforest-light";

    niri = {
      gaps = 8;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 24;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#0f161380";
      shadowInactiveColor = "#0f161340";
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

      qt6 = theme.mkQt6ColorScheme {
        active = [
          fg
          bg1
          "#ffffff"
          bg3
          bg2
          bg2
          fg
          "#ffffff"
          fg
          bg0
          bg0
          "#000000"
          green
          bg0
          green
          blue
          bg1
          bg0
          bg1
          fg
          grey1
          green
        ];
        disabled = [
          grey1
          bg1
          "#ffffff"
          bg3
          bg2
          bg2
          grey1
          "#ffffff"
          grey1
          bg0
          bg0
          "#000000"
          bg3
          bg2
          bg3
          blue
          bg1
          bg0
          bg1
          grey1
          grey0
          bg3
        ];
        inactive = [
          grey2
          bg1
          "#ffffff"
          bg3
          bg2
          bg2
          grey2
          "#ffffff"
          grey2
          bg0
          bg0
          "#000000"
          green
          bg0
          green
          blue
          bg1
          bg0
          bg1
          grey2
          grey1
          green
        ];
      };

      kitty = theme.mkKittyColors {
        title = "Everforest Dark Hard Kitty";
        cursor = fg;
        cursorText = bg0;
        foreground = fg;
        background = bg0;
        selectionForeground = bg0;
        selectionBackground = green;
        color0 = bg3;
        color8 = bg5;
        color1 = red;
        color9 = red;
        color2 = green;
        color10 = green;
        color3 = yellow;
        color11 = yellow;
        color4 = blue;
        color12 = blue;
        color5 = purple;
        color13 = purple;
        color6 = aqua;
        color14 = aqua;
        color7 = grey2;
        color15 = fg;
      };

      fish = theme.mkFishColors {
        normal = fg;
        command = green;
        keyword = aqua;
        quote = yellow;
        redirection = blue;
        end = grey1;
        error = red;
        param = fg;
        comment = grey0;
        selection = bg2;
        searchMatch = bg1;
        operator = aqua;
        escape = orange;
        autosuggestion = grey0;
      };

      starship = theme.mkStarshipPrompt {
        success = green;
        error = red;
        directory = aqua;
        gitBranch = yellow;
        cmdDuration = grey1;
      };

      rofi = theme.mkProfilePickerRofi {
        background = bg0;
        text = fg;
        border = bg2;
        selectedBackground = bg1;
        selectedForeground = green;
        inputBackground = bg1;
        prompt = green;
        placeholder = bg3;
        elementBackground = bg1;
        elementSelectedBackground = bg2;
        elementSelectedBorder = green;
      };
    };

    waybar = {
      config = waybar.mkConfig {
        floating = true;
        scriptDir = "${config.repoPath}/home/scripts";
      };
      style = waybar.mkFloatingStyle {
        windowBg = "rgba(39, 46, 51, 0.6)";
        primary = green;
        borderColor = bg2;
        shadowColor = "rgba(20, 24, 27, 0.45)";
        activeBg = bg2;
        hoverColor = yellow;
        clockColor = yellow;
        textColor = fg;
        performanceColor = red;
        balancedColor = green;
        powerSaverColor = aqua;
        warningColor = yellow;
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

      qt6 = theme.mkQt6ColorScheme {
        active = [
          l_fg
          l_bg1
          "#ffffff"
          l_bg3
          l_bg2
          l_bg2
          l_fg
          "#ffffff"
          l_fg
          l_bg0
          l_bg0
          "#000000"
          l_green
          l_bg0
          l_green
          l_blue
          l_bg1
          l_bg0
          l_bg1
          l_fg
          l_grey1
          l_green
        ];
        disabled = [
          l_grey1
          l_bg1
          "#ffffff"
          l_bg3
          l_bg2
          l_bg2
          l_grey1
          "#ffffff"
          l_grey1
          l_bg0
          l_bg0
          "#000000"
          l_bg3
          l_bg2
          l_bg3
          l_blue
          l_bg1
          l_bg0
          l_bg1
          l_grey1
          l_grey0
          l_bg3
        ];
        inactive = [
          l_grey2
          l_bg1
          "#ffffff"
          l_bg3
          l_bg2
          l_bg2
          l_grey2
          "#ffffff"
          l_grey2
          l_bg0
          l_bg0
          "#000000"
          l_green
          l_bg0
          l_green
          l_blue
          l_bg1
          l_bg0
          l_bg1
          l_grey2
          l_grey1
          l_green
        ];
      };

      kitty = theme.mkKittyColors {
        title = "Everforest Light Hard Kitty";
        cursor = l_fg;
        cursorText = l_bg0;
        foreground = l_fg;
        background = l_bg0;
        selectionForeground = l_bg0;
        selectionBackground = l_green;
        color0 = l_bg3;
        color8 = l_bg5;
        color1 = l_red;
        color9 = l_red;
        color2 = l_green;
        color10 = l_green;
        color3 = l_yellow;
        color11 = l_yellow;
        color4 = l_blue;
        color12 = l_blue;
        color5 = l_purple;
        color13 = l_purple;
        color6 = l_aqua;
        color14 = l_aqua;
        color7 = l_grey2;
        color15 = l_fg;
      };

      fish = theme.mkFishColors {
        normal = l_fg;
        command = l_green;
        keyword = l_aqua;
        quote = l_yellow;
        redirection = l_blue;
        end = l_grey1;
        error = l_red;
        param = l_fg;
        comment = l_grey0;
        selection = l_bg2;
        searchMatch = l_bg1;
        operator = l_aqua;
        escape = l_orange;
        autosuggestion = l_grey0;
      };

      starship = theme.mkStarshipPrompt {
        success = l_green;
        error = l_red;
        directory = l_aqua;
        gitBranch = l_yellow;
        cmdDuration = l_grey1;
      };

      rofi = theme.mkProfilePickerRofi {
        background = l_bg0;
        text = l_fg;
        border = l_bg2;
        selectedBackground = l_bg1;
        selectedForeground = l_green;
        inputBackground = l_bg1;
        prompt = l_green;
        placeholder = l_bg3;
        elementBackground = l_bg1;
        elementSelectedBackground = l_bg2;
        elementSelectedBorder = l_green;
      };
    };

    waybarLight.style = waybar.mkFloatingStyle {
      windowBg = "rgba(255, 249, 232, 0.85)";
      primary = l_green;
      borderColor = l_bg2;
      shadowColor = "rgba(190, 197, 178, 0.45)";
      activeBg = l_bg2;
      hoverColor = l_yellow;
      clockColor = l_yellow;
      textColor = l_fg;
      performanceColor = l_red;
      balancedColor = l_green;
      powerSaverColor = l_aqua;
      warningColor = l_yellow;
      criticalColor = l_red;
    };
  };
}
