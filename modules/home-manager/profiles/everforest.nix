{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;

  # Everforest Hard. One role mapping below serves dark and light; `makoLow`
  # is the low-urgency notification border (bg4 dark, bg3 light upstream).
  dark = {
    title = "Everforest Dark Hard";
    bg0 = "#272e33";
    bg1 = "#2e383c";
    bg2 = "#374145";
    bg3 = "#414b50";
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
    makoLow = "#495156";
    barBg = "rgba(39, 46, 51, 0.6)";
    barShadow = "rgba(20, 24, 27, 0.45)";
  };

  light = {
    title = "Everforest Light Hard";
    bg0 = "#fff9e8";
    bg1 = "#f4f0d9";
    bg2 = "#efebd4";
    bg3 = "#e6e2cc";
    bg5 = "#bec5b2";
    fg = "#5c6a72";
    red = "#f85552";
    orange = "#f57d26";
    yellow = "#dfa000";
    green = "#8da101";
    aqua = "#35a77c";
    blue = "#3a94c5";
    purple = "#df69ba";
    grey0 = "#a6b0a0";
    grey1 = "#939f91";
    grey2 = "#829181";
    makoLow = "#e6e2cc";
    barBg = "rgba(255, 249, 232, 0.85)";
    barShadow = "rgba(190, 197, 178, 0.45)";
  };

  alpha = a: c: "#${a}${builtins.substring 1 6 c}";

  mkColors =
    p:
    theme.mkGtkPair {
      inherit (p) title;
      accent = p.green;
      accentFg = p.bg0;
      destructiveBg = p.red;
      destructiveFg = p.fg;
      windowBg = p.bg0;
      windowFg = p.fg;
      headerbarBg = p.bg1;
      headerbarBackdrop = "@window_bg_color";
      popoverBg = p.bg1;
      cardBg = p.bg1;
      dialogBg = p.bg0;
      dialogFg = p.fg;
      sidebarBg = p.bg1;
      sidebarBackdrop = "@window_bg_color";
      sidebarBorder = p.bg2;
      secondarySidebarBg = p.bg0;
      secondarySidebarFg = p.grey2;
      unfocused = {
        fg = p.grey2;
        text = p.grey1;
        bg = p.bg0;
        base = p.bg0;
        selectedBg = p.bg2;
        selectedFg = p.fg;
      };
    }
    // {
      qt6 = theme.mkQt6Roles {
        windowText = p.fg;
        button = p.bg1;
        midlight = p.bg3;
        mid = p.bg2;
        window = p.bg0;
        highlight = p.green;
        highlightedText = p.bg0;
        linkVisited = p.blue;
        alternateBase = p.bg1;
        tooltipBase = p.bg0;
        tooltipText = p.bg1;
        secondaryText = p.grey1;
        inactiveText = p.grey2;
        disabledText = p.grey1;
        disabledHighlight = p.bg3;
        disabledHighlightedText = p.bg2;
        disabledSecondaryText = p.grey0;
      };

      kitty = theme.mkKittyColors {
        title = "${p.title} Kitty";
        cursor = p.fg;
        cursorText = p.bg0;
        foreground = p.fg;
        background = p.bg0;
        selectionForeground = p.bg0;
        selectionBackground = p.green;
        color0 = p.bg3;
        color8 = p.bg5;
        color1 = p.red;
        color9 = p.red;
        color2 = p.green;
        color10 = p.green;
        color3 = p.yellow;
        color11 = p.yellow;
        color4 = p.blue;
        color12 = p.blue;
        color5 = p.purple;
        color13 = p.purple;
        color6 = p.aqua;
        color14 = p.aqua;
        color7 = p.grey2;
        color15 = p.fg;
      };

      fish = theme.mkFishColors {
        normal = p.fg;
        command = p.green;
        keyword = p.aqua;
        quote = p.yellow;
        redirection = p.blue;
        end = p.grey1;
        error = p.red;
        param = p.fg;
        comment = p.grey0;
        selection = p.bg2;
        searchMatch = p.bg1;
        operator = p.aqua;
        escape = p.orange;
        autosuggestion = p.grey0;
      };

      starship = theme.mkStarshipPrompt {
        success = p.green;
        error = p.red;
        directory = p.aqua;
        gitBranch = p.yellow;
        cmdDuration = p.grey1;
      };

      rofi = theme.mkProfilePickerRofi {
        background = p.bg0;
        text = p.fg;
        border = p.bg2;
        selectedBackground = p.bg1;
        selectedForeground = p.green;
        inputBackground = p.bg1;
        prompt = p.green;
        placeholder = p.bg3;
        elementBackground = p.bg1;
        elementSelectedBackground = p.bg2;
        elementSelectedBorder = p.green;
      };

      btop = theme.mkBtopTheme {
        mainBg = p.bg0;
        mainFg = p.fg;
        hiFg = p.green;
        selectedBg = p.bg2;
        inactiveFg = p.grey1;
        procMisc = p.aqua;
        box = p.bg2;
        gradLow = p.green;
        gradMid = p.yellow;
        gradHigh = p.red;
      };

      tmux = theme.mkTmuxColors {
        bg = p.bg1;
        inherit (p) fg;
        accent = p.green;
        secondary = p.grey2;
        inactive = p.grey1;
        border = p.bg2;
      };
    };

  mkMako =
    p:
    theme.mkMakoConfig {
      background = p.bg0;
      text = p.fg;
      border = p.green;
      lowBorder = p.makoLow;
      highBackground = p.bg1;
      highBorder = p.red;
      highText = p.fg;
    };

  mkQuickshell = p: {
    inherit (p) fg;
    bg = alpha "66" p.bg0;
    popupBg = alpha "cc" p.bg0;
    rawBg = p.bg0;
    accent = p.green;
    second = p.grey2;
    warm = p.orange;
    fresh = p.blue;
    barRadius = "10";
    barHeight = "32";
    showClockDate = "false";
    showWorkspaceNumbers = "false";
    barFont = "Hack Nerd Font";
    barBorder = "#00000000";
    pillBorder = alpha "1d" p.bg1;
  };

  mkWaybarStyle =
    p:
    waybar.mkFloatingStyle {
      windowBg = p.barBg;
      primary = p.green;
      borderColor = p.bg2;
      shadowColor = p.barShadow;
      activeBg = p.bg2;
      hoverColor = p.yellow;
      clockColor = p.yellow;
      textColor = p.fg;
      performanceColor = p.red;
      balancedColor = p.green;
      powerSaverColor = p.aqua;
      warningColor = p.yellow;
      criticalColor = p.red;
    };
in
{
  desktopProfiles.profiles.everforest = {
    bar = "quickshell";

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    makoConfig = mkMako dark;
    makoConfigLight = mkMako light;

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
      tabIndicatorActiveColor = dark.green;
      tabIndicatorInactiveColor = dark.bg3;
      windowOpacity = 0.96;
      windowHighlightOff = true;
    };

    colors = mkColors dark;
    colorsLight = mkColors light;

    waybar = {
      config = waybar.mkConfig {
        floating = true;
        scriptDir = "${config.repoPath}/home/scripts";
      };
      style = mkWaybarStyle dark;
    };
    waybarLight.style = mkWaybarStyle light;
  };
}
