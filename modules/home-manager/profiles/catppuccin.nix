{ pkgs, config, ... }:

# Catppuccin desktop profile — Mocha (dark) + Latte (light).
# One role mapping serves both variants; slots that intentionally differ
# between Mocha and Latte (fish*, starship*, rofiPlaceholder, bar*) are
# palette entries. Mocha additionally replaces the derived kitty theme with
# a custom monochrome pink/purple scheme.
let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;

  dark = rec {
    title = "Catppuccin Mocha";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
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
    fishQuote = lavender;
    fishRedirection = mauve;
    fishAutosuggestion = overlay0;
    starshipSuccess = flamingo;
    starshipDirectory = lavender;
    rofiPlaceholder = surface1;
    barBg = "rgba(24, 24, 37, 0.6)";
    barShadow = "rgba(17, 17, 27, 0.45)";
    barPrimary = pink;
    barBorder = surface0;
    barCritical = pink;
  };

  light = rec {
    title = "Catppuccin Latte";
    pink = "#ea76cb";
    mauve = "#8839ef";
    red = "#d20f39";
    peach = "#fe640b";
    yellow = "#df8e1d";
    green = "#40a02b";
    teal = "#179299";
    blue = "#1e66f5";
    text = "#4c4f69";
    subtext1 = "#5c5f77";
    subtext0 = "#6c6f85";
    overlay2 = "#7c7f93";
    overlay1 = "#8c8fa1";
    overlay0 = "#9ca0b0";
    surface2 = "#acb0be";
    surface1 = "#bcc0cc";
    surface0 = "#ccd0da";
    base = "#eff1f5";
    mantle = "#e6e9ef";
    crust = "#dce0e8";
    fishQuote = green;
    fishRedirection = teal;
    fishAutosuggestion = overlay1;
    starshipSuccess = mauve;
    starshipDirectory = blue;
    rofiPlaceholder = surface2;
    barBg = "rgba(239, 241, 245, 0.85)";
    barShadow = "rgba(220, 224, 232, 0.6)";
    barPrimary = mauve;
    barBorder = surface1;
    barCritical = red;
    barText = text;
  };

  alpha = a: c: "#${a}${builtins.substring 1 6 c}";

  mkColors =
    p:
    theme.mkGtkPair {
      inherit (p) title;
      accent = p.mauve;
      accentFg = p.base;
      destructiveBg = p.red;
      destructiveFg = p.base;
      windowBg = p.base;
      windowFg = p.text;
      headerbarBg = p.mantle;
      headerbarBackdrop = "@window_bg_color";
      popoverBg = p.mantle;
      cardBg = p.surface0;
      dialogBg = p.mantle;
      dialogFg = p.text;
      sidebarBg = p.mantle;
      sidebarBackdrop = "@window_bg_color";
      sidebarBorder = p.surface1;
      secondarySidebarBg = p.base;
      secondarySidebarFg = p.subtext1;
      unfocused = {
        fg = p.subtext0;
        text = p.overlay2;
        bg = p.base;
        inherit (p) base;
        selectedBg = p.surface1;
        selectedFg = p.base;
      };
    }
    // {
      qt6 = theme.mkQt6Roles {
        windowText = p.text;
        button = p.mantle;
        midlight = p.overlay1;
        mid = p.surface0;
        window = p.base;
        highlight = p.mauve;
        highlightedText = p.surface1;
        linkVisited = p.blue;
        alternateBase = p.surface0;
        tooltipBase = p.crust;
        tooltipText = p.surface0;
        secondaryText = p.subtext1;
        inactiveText = p.subtext1;
        inactiveWindowText = p.text;
        inactiveButtonText = p.text;
        inactivePlaceholderText = p.text;
        disabledText = p.overlay0;
        disabledHighlight = p.surface2;
        disabledSecondaryText = p.overlay1;
      };

      kitty = theme.mkKittyColors {
        title = "${p.title} Kitty";
        cursor = p.mauve;
        cursorText = p.base;
        foreground = p.text;
        background = p.base;
        selectionForeground = p.base;
        selectionBackground = p.mauve;
        color0 = p.surface1;
        color8 = p.surface2;
        color1 = p.red;
        color9 = p.red;
        color2 = p.green;
        color10 = p.green;
        color3 = p.yellow;
        color11 = p.yellow;
        color4 = p.blue;
        color12 = p.blue;
        color5 = p.mauve;
        color13 = p.mauve;
        color6 = p.teal;
        color14 = p.teal;
        color7 = p.subtext1;
        color15 = p.text;
      };

      fish = theme.mkFishColors {
        normal = p.text;
        command = p.mauve;
        keyword = p.pink;
        quote = p.fishQuote;
        redirection = p.fishRedirection;
        end = p.pink;
        error = p.red;
        param = p.text;
        comment = p.overlay0;
        selection = p.surface1;
        searchMatch = p.surface0;
        operator = p.mauve;
        escape = p.pink;
        autosuggestion = p.fishAutosuggestion;
      };

      starship = theme.mkStarshipPrompt {
        success = p.starshipSuccess;
        error = p.red;
        directory = p.starshipDirectory;
        gitBranch = p.pink;
        cmdDuration = p.subtext1;
      };

      rofi = theme.mkProfilePickerRofi {
        background = p.base;
        inherit (p) text;
        border = p.surface1;
        selectedBackground = p.surface0;
        selectedForeground = p.mauve;
        inputBackground = p.mantle;
        prompt = p.mauve;
        placeholder = p.rofiPlaceholder;
        elementBackground = p.surface0;
        elementSelectedBackground = p.surface1;
        elementSelectedBorder = p.mauve;
      };

      btop = theme.mkBtopTheme {
        mainBg = p.base;
        mainFg = p.text;
        hiFg = p.mauve;
        selectedBg = p.surface1;
        inactiveFg = p.overlay0;
        procMisc = p.teal;
        box = p.surface1;
        gradLow = p.green;
        gradMid = p.yellow;
        gradHigh = p.red;
      };

      tmux = theme.mkTmuxColors {
        bg = p.mantle;
        fg = p.text;
        accent = p.mauve;
        secondary = p.subtext1;
        inactive = p.overlay0;
        border = p.surface1;
      };

      hyprlock = theme.mkHyprlockColors {
        fg = p.text;
        muted = p.subtext0;
        accent = p.mauve;
        surface = p.crust;
        surfaceAlt = p.mantle;
        error = p.red;
      };

      cava = theme.mkCavaColors {
        gradLow = p.green;
        gradMid = p.yellow;
        gradHigh = p.red;
      };
    };

  mkMako =
    p:
    theme.mkMakoConfig {
      background = p.base;
      inherit (p) text;
      border = p.mauve;
      lowBorder = p.surface1;
      highBackground = p.mantle;
      highBorder = p.red;
      highText = p.text;
    };

  mkQuickshell = p: {
    fg = p.pink;
    bg = alpha "99" p.mantle;
    popupBg = alpha "cc" p.base;
    rawBg = p.base;
    accent = p.mauve;
    second = p.pink;
    warm = p.peach;
    fresh = p.green;
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
        primary = p.barPrimary;
        borderColor = p.barBorder;
        shadowColor = p.barShadow;
        activeBg = p.surface0;
        performanceColor = p.red;
        balancedColor = p.mauve;
        powerSaverColor = p.green;
        warningColor = p.yellow;
        criticalColor = p.barCritical;
      }
      // (if p ? barText then { textColor = p.barText; } else { })
    );
in
{
  desktopProfiles.profiles.catppuccin = {
    bar = "quickshell";

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    makoConfig = mkMako dark;
    makoConfigLight = mkMako light;

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
      borderActiveColor = dark.mauve;
      borderInactiveColor = dark.surface1;
      urgentColor = dark.red;
      focusRingOff = true;
      focusRingActiveColor = dark.mauve;
      focusRingInactiveColor = dark.surface1;
      shadowSoftness = 28;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#11111b88";
      shadowInactiveColor = "#11111b44";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = dark.mauve;
      tabIndicatorInactiveColor = dark.surface1;
      windowOpacity = 0.97;
      windowHighlightOff = true;
    };

    colors = mkColors dark // {
      kitty = theme.mkKittyColors {
        title = "Catppuccin Kitty (Monochrome Pink/Purple)";
        cursor = "#e8cfe4";
        cursorText = "#1a1623";
        foreground = "#ddd2e8";
        background = "#1b1824";
        selectionForeground = "#1b1824";
        selectionBackground = "#b9a6cf";
        color0 = "#2b2734";
        color8 = "#4a4458";
        color1 = "#d7a0b3";
        color9 = "#dfaec0";
        color2 = "#bca9d1";
        color10 = "#c8b8db";
        color3 = "#c9b3d8";
        color11 = "#d5c2e1";
        color4 = "#af9bc8";
        color12 = "#bcabd2";
        color5 = "#dcb8d2";
        color13 = "#e5c7dc";
        color6 = "#c8afd9";
        color14 = "#d2bfe0";
        color7 = "#d8cde2";
        color15 = "#e4ddea";
      };
    };
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
