{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;

  # Gruvbox Hard. Dark and light share one role mapping below; `onAccent` and
  # `onError` are the ink tones used on accent/error backgrounds (the opposite
  # extreme of each variant).
  dark = {
    title = "Gruvbox Dark";
    bg0h = "#1d2021";
    bg0 = "#282828";
    bg1 = "#3c3836";
    bg2 = "#504945";
    bg3 = "#665c54";
    bg4 = "#7c6f64";
    fg0 = "#fbf1c7";
    fg1 = "#ebdbb2";
    fg2 = "#d5c4a1";
    fg3 = "#bdae93";
    fg4 = "#a89984";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    purple = "#d3869b";
    aqua = "#8ec07c";
    orange = "#fe8019";
    gray = "#928374";
    onAccent = "#282828";
    onError = "#fbf1c7";
    barBg = "rgba(40, 40, 40, 0.6)";
    barShadow = "rgba(29, 32, 33, 0.45)";
  };

  light = {
    title = "Gruvbox Light Hard";
    bg0h = "#f9f5d7";
    bg0 = "#fbf1c7";
    bg1 = "#ebdbb2";
    bg2 = "#d5c4a1";
    bg3 = "#bdae93";
    bg4 = "#a89984";
    fg0 = "#282828";
    fg1 = "#3c3836";
    fg2 = "#504945";
    fg3 = "#665c54";
    fg4 = "#7c6f64";
    red = "#9d0006";
    green = "#79740e";
    yellow = "#b57614";
    blue = "#076678";
    purple = "#8f3f71";
    aqua = "#427b58";
    orange = "#af3a03";
    gray = "#928374";
    onAccent = "#282828";
    onError = "#fbf1c7";
    barBg = "rgba(251, 241, 199, 0.85)";
    barShadow = "rgba(189, 174, 147, 0.45)";
  };

  alpha = a: c: "#${a}${builtins.substring 1 6 c}";

  mkColors =
    p:
    theme.mkGtkPair {
      inherit (p) title;
      accent = p.yellow;
      accentFg = p.onAccent;
      destructiveBg = p.red;
      destructiveFg = p.onError;
      windowBg = p.bg0;
      windowFg = p.fg1;
      headerbarBg = p.bg1;
      headerbarBackdrop = "@window_bg_color";
      popoverBg = p.bg1;
      cardBg = p.bg1;
      dialogBg = p.bg0;
      dialogFg = p.fg1;
      sidebarBg = p.bg1;
      sidebarBackdrop = "@window_bg_color";
      sidebarBorder = p.bg2;
      secondarySidebarBg = p.bg0;
      secondarySidebarFg = p.fg2;
      unfocused = {
        fg = p.fg3;
        text = p.fg4;
        bg = p.bg0;
        base = p.bg0;
        selectedBg = p.bg2;
        selectedFg = p.fg1;
      };
    }
    // {
      qt6 = theme.mkQt6Roles {
        windowText = p.fg1;
        button = p.bg1;
        midlight = p.bg3;
        mid = p.bg2;
        window = p.bg0;
        highlight = p.yellow;
        highlightedText = p.bg0;
        linkVisited = p.blue;
        alternateBase = p.bg1;
        tooltipBase = p.bg0h;
        tooltipText = p.bg1;
        secondaryText = p.fg4;
        inactiveText = p.fg2;
        disabledText = p.fg4;
        disabledHighlight = p.bg3;
        disabledHighlightedText = p.bg2;
        disabledSecondaryText = p.gray;
      };

      kitty = theme.mkKittyColors {
        title = "${p.title} Kitty";
        cursor = p.fg1;
        cursorText = p.bg0;
        foreground = p.fg1;
        background = p.bg0;
        selectionForeground = p.bg0;
        selectionBackground = p.yellow;
        color0 = p.bg1;
        color8 = p.bg3;
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
        color7 = p.fg4;
        color15 = p.fg1;
      };

      fish = theme.mkFishColors {
        normal = p.fg1;
        command = p.yellow;
        keyword = p.orange;
        quote = p.green;
        redirection = p.aqua;
        end = p.fg4;
        error = p.red;
        param = p.fg2;
        comment = p.bg4;
        selection = p.bg2;
        searchMatch = p.bg1;
        operator = p.orange;
        escape = p.purple;
        autosuggestion = p.bg4;
      };

      starship = theme.mkStarshipPrompt {
        success = p.yellow;
        error = p.red;
        directory = p.blue;
        gitBranch = p.orange;
        cmdDuration = p.fg4;
      };

      rofi = theme.mkProfilePickerRofi {
        background = p.bg0;
        text = p.fg1;
        border = p.bg2;
        selectedBackground = p.bg1;
        selectedForeground = p.yellow;
        inputBackground = p.bg1;
        prompt = p.yellow;
        placeholder = p.bg3;
        elementBackground = p.bg1;
        elementSelectedBackground = p.bg2;
        elementSelectedBorder = p.yellow;
      };
    };

  mkMako =
    p:
    theme.mkMakoConfig {
      background = p.bg0;
      text = p.fg1;
      border = p.yellow;
      lowBorder = p.bg3;
      highBackground = p.bg1;
      highBorder = p.red;
      highText = p.fg0;
    };

  mkQuickshell = p: {
    fg = p.fg1;
    bg = alpha "66" p.bg0;
    popupBg = alpha "cc" p.bg0;
    rawBg = p.bg0;
    accent = p.yellow;
    second = p.fg2;
    warm = p.orange;
    fresh = p.green;
    barRadius = "10";
    barHeight = "32";
    showClockDate = "false";
    showWorkspaceNumbers = "false";
    barFont = "Hack Nerd Font";
    barBorder = p.yellow;
    pillBorder = alpha "1d" p.bg1;
  };

  mkWaybarStyle =
    p:
    waybar.mkFloatingStyle {
      windowBg = p.barBg;
      primary = p.yellow;
      borderColor = p.bg2;
      shadowColor = p.barShadow;
      activeBg = p.bg2;
      hoverColor = p.orange;
      clockColor = p.yellow;
      textColor = p.fg1;
      performanceColor = p.red;
      balancedColor = p.yellow;
      powerSaverColor = p.green;
      warningColor = p.yellow;
      criticalColor = p.red;
    };
in
{
  desktopProfiles.profiles.gruvbox = {
    bar = "quickshell";

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    makoConfig = mkMako dark;
    makoConfigLight = mkMako light;

    cursor = {
      theme = "Capitaine Cursors (Gruvbox)";
      size = 24;
      package = pkgs.capitaine-cursors-themed;
    };

    fonts = {
      ui = {
        family = "Source Sans Pro";
        size = 11;
      };
      mono = {
        family = "Iosevka Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = "adw-gtk3";
      iconTheme = "Tela-yellow-dark";
      iconThemeLight = "Tela-yellow-light";
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/gruvbox";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/gruvbox-light";

    niri = {
      gaps = 8;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 30;
      shadowSpread = 6;
      shadowOffsetX = 0;
      shadowOffsetY = 7;
      shadowColor = "#1d202180";
      shadowInactiveColor = "#1d202140";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = dark.yellow;
      tabIndicatorInactiveColor = dark.bg2;
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
