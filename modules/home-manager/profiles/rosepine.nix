{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;

  # Rosé Pine (Main dark, Dawn light). One role mapping serves both variants;
  # `barText` is only set for the light waybar (dark uses the style default).
  dark = {
    title = "Rosé Pine";
    base = "#191724";
    surface = "#1f1d2e";
    overlay = "#26233a";
    muted = "#6e6a86";
    subtle = "#908caa";
    text = "#e0def4";
    love = "#eb6f92";
    gold = "#f6c177";
    rose = "#ebbcba";
    pine = "#31748f";
    foam = "#9ccfd8";
    iris = "#c4a7e7";
    highlightLow = "#21202e";
    highlightMed = "#403d52";
    highlightHigh = "#524f67";
    barBg = "rgba(25, 23, 36, 0.6)";
    barShadow = "rgba(16, 14, 24, 0.45)";
  };

  light = {
    title = "Rosé Pine Dawn";
    base = "#faf4ed";
    surface = "#fffaf3";
    overlay = "#f2e9e1";
    muted = "#9893a5";
    subtle = "#797593";
    text = "#575279";
    love = "#b4637a";
    gold = "#ea9d34";
    rose = "#d7827e";
    pine = "#286983";
    foam = "#56949f";
    iris = "#907aa9";
    highlightLow = "#f4ede8";
    highlightMed = "#dfdad9";
    highlightHigh = "#cecacd";
    barBg = "rgba(250, 244, 237, 0.85)";
    barShadow = "rgba(223, 218, 217, 0.5)";
    barText = "#575279";
  };

  alpha = a: c: "#${a}${builtins.substring 1 6 c}";

  mkColors =
    p:
    theme.mkGtkPair {
      inherit (p) title;
      accent = p.iris;
      accentFg = p.base;
      destructiveBg = p.love;
      destructiveFg = p.base;
      windowBg = p.base;
      windowFg = p.text;
      headerbarBg = p.surface;
      headerbarBackdrop = "@window_bg_color";
      popoverBg = p.surface;
      cardBg = p.overlay;
      dialogBg = p.surface;
      dialogFg = p.text;
      sidebarBg = p.surface;
      sidebarBackdrop = "@window_bg_color";
      sidebarBorder = p.highlightMed;
      secondarySidebarBg = p.base;
      secondarySidebarFg = p.subtle;
      unfocused = {
        fg = p.subtle;
        text = p.muted;
        bg = p.base;
        inherit (p) base;
        selectedBg = p.highlightMed;
        selectedFg = p.text;
      };
    }
    // {
      qt6 = theme.mkQt6Roles {
        windowText = p.text;
        button = p.surface;
        midlight = p.highlightHigh;
        mid = p.overlay;
        window = p.base;
        highlight = p.iris;
        highlightedText = p.highlightMed;
        linkVisited = p.pine;
        alternateBase = p.overlay;
        tooltipBase = p.highlightLow;
        tooltipText = p.overlay;
        secondaryText = p.subtle;
        inactiveText = p.subtle;
        inactiveSecondaryText = p.muted;
        disabledText = p.muted;
        disabledHighlight = p.highlightHigh;
      };

      kitty = theme.mkKittyColors {
        title = "${p.title} Kitty";
        cursor = p.rose;
        cursorText = p.base;
        foreground = p.text;
        background = p.base;
        selectionForeground = p.base;
        selectionBackground = p.iris;
        color0 = p.highlightMed;
        color8 = p.highlightHigh;
        color1 = p.love;
        color9 = p.love;
        color2 = p.pine;
        color10 = p.foam;
        color3 = p.gold;
        color11 = p.gold;
        color4 = p.pine;
        color12 = p.pine;
        color5 = p.iris;
        color13 = p.iris;
        color6 = p.foam;
        color14 = p.foam;
        color7 = p.subtle;
        color15 = p.text;
      };

      fish = theme.mkFishColors {
        normal = p.text;
        command = p.iris;
        keyword = p.love;
        quote = p.gold;
        redirection = p.foam;
        end = p.subtle;
        error = p.love;
        param = p.text;
        comment = p.muted;
        selection = p.highlightMed;
        searchMatch = p.overlay;
        operator = p.iris;
        escape = p.rose;
        autosuggestion = p.muted;
      };

      starship = theme.mkStarshipPrompt {
        success = p.iris;
        error = p.love;
        directory = p.foam;
        gitBranch = p.rose;
        cmdDuration = p.subtle;
      };

      rofi = theme.mkProfilePickerRofi {
        background = p.base;
        inherit (p) text;
        border = p.highlightMed;
        selectedBackground = p.overlay;
        selectedForeground = p.iris;
        inputBackground = p.surface;
        prompt = p.iris;
        placeholder = p.highlightHigh;
        elementBackground = p.surface;
        elementSelectedBackground = p.overlay;
        elementSelectedBorder = p.iris;
      };

      btop = theme.mkBtopTheme {
        mainBg = p.base;
        mainFg = p.text;
        hiFg = p.iris;
        selectedBg = p.highlightMed;
        inactiveFg = p.muted;
        procMisc = p.foam;
        box = p.highlightMed;
        gradLow = p.foam;
        gradMid = p.gold;
        gradHigh = p.love;
      };

      tmux = theme.mkTmuxColors {
        bg = p.surface;
        fg = p.text;
        accent = p.iris;
        secondary = p.subtle;
        inactive = p.muted;
        border = p.highlightMed;
      };
    };

  mkMako =
    p:
    theme.mkMakoConfig {
      background = p.base;
      inherit (p) text;
      border = p.iris;
      lowBorder = p.highlightHigh;
      highBackground = p.surface;
      highBorder = p.love;
      highText = p.text;
    };

  mkQuickshell = p: {
    fg = p.base;
    bg = alpha "dd" p.iris;
    popupBg = alpha "cc" p.base;
    rawBg = p.base;
    accent = p.base;
    second = p.surface;
    warm = p.gold;
    fresh = p.foam;
    barRadius = "22";
    barHeight = "32";
    showClockDate = "false";
    showWorkspaceNumbers = "false";
    barFont = "FiraCode Nerd Font";
    barBorder = "#00000000";
    pillBg = "#00000000";
    pillBorder = "#00000000";
  };

  mkWaybarStyle =
    p:
    waybar.mkPillStyle (
      {
        windowBg = p.barBg;
        primary = p.iris;
        borderColor = p.highlightMed;
        shadowColor = p.barShadow;
        activeBg = p.overlay;
        hoverColor = p.rose;
        clockColor = p.rose;
        performanceColor = p.love;
        balancedColor = p.iris;
        powerSaverColor = p.pine;
        warningColor = p.gold;
        criticalColor = p.love;
      }
      // (if p ? barText then { textColor = p.barText; } else { })
    );
in
{
  desktopProfiles.profiles.rosepine = {
    bar = "quickshell";

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    makoConfig = mkMako dark;
    makoConfigLight = mkMako light;

    cursor = {
      theme = "BreezeX-RosePine-Linux";
      size = 24;
      package = pkgs.rose-pine-cursor;
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
      iconTheme = "Tela-pink-dark";
      iconThemeLight = "Tela-pink-light";
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/rosepine";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/rosepine-light";

    niri = {
      gaps = 8;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 36;
      shadowSpread = 5;
      shadowOffsetX = 0;
      shadowOffsetY = 8;
      shadowColor = "#100e1880";
      shadowInactiveColor = "#100e1840";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = dark.iris;
      tabIndicatorInactiveColor = dark.highlightMed;
      windowOpacity = 0.97;
      windowHighlightOff = true;
    };

    colors = mkColors dark;
    colorsLight = mkColors light;

    waybar = {
      config = waybar.mkConfig {
        floating = true;
        pill = true;
        scriptDir = "${config.repoPath}/home/scripts";
      };
      style = mkWaybarStyle dark;
    };
    waybarLight.style = mkWaybarStyle light;
  };
}
