{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  # ── Gruvbox Dark Hard ────────────────────────────────────────────────────────
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

  # ── Gruvbox Light Hard ───────────────────────────────────────────────────────
  l_bg0h = "#f9f5d7";
  l_bg0 = "#fbf1c7";
  l_bg1 = "#ebdbb2";
  l_bg2 = "#d5c4a1";
  l_bg3 = "#bdae93";
  l_bg4 = "#a89984";
  l_fg0 = "#282828";
  l_fg1 = "#3c3836";
  l_fg2 = "#504945";
  l_fg3 = "#665c54";
  l_fg4 = "#7c6f64";
  l_red = "#9d0006";
  l_green = "#79740e";
  l_yellow = "#b57614";
  l_blue = "#076678";
  l_purple = "#8f3f71";
  l_aqua = "#427b58";
  l_orange = "#af3a03";
  l_gray = "#928374";
in
{
  desktopProfiles.profiles.gruvbox = {
    bar = "quickshell";

    quickshellTheme = {
      fg = fg1;
      bg = "#66282828";
      popupBg = "#cc282828";
      rawBg = bg0;
      accent = yellow;
      second = fg2;
      warm = orange;
      fresh = green;
      barRadius = "10";
      barHeight = "32";
      showClockDate = "false";
      showWorkspaceNumbers = "false";
      barFont = "Hack Nerd Font";
      barBorder = yellow;
      pillBorder = "#1d3c3836";
    };

    makoConfig = theme.mkMakoConfig {
      background = bg0;
      text = fg1;
      border = yellow;
      lowBorder = bg3;
      highBackground = bg1;
      highBorder = red;
      highText = fg0;
    };

    makoConfigLight = theme.mkMakoConfig {
      background = l_bg0;
      text = l_fg1;
      border = l_yellow;
      lowBorder = l_bg3;
      highBackground = l_bg1;
      highBorder = l_red;
      highText = l_fg0;
    };

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
      tabIndicatorActiveColor = yellow;
      tabIndicatorInactiveColor = bg2;
      windowOpacity = 0.96;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = theme.mkGtkColors {
        title = "Gruvbox Dark";
        accent = yellow;
        accentFg = bg0;
        destructiveBg = red;
        destructiveFg = fg0;
        windowBg = bg0;
        windowFg = fg1;
        headerbarBg = bg1;
        headerbarBackdrop = "@window_bg_color";
        popoverBg = bg1;
        cardBg = bg1;
        dialogBg = bg0;
        dialogFg = fg1;
        sidebarBg = bg1;
        sidebarBackdrop = "@window_bg_color";
        sidebarBorder = bg2;
        secondarySidebarBg = bg0;
        secondarySidebarFg = fg2;
        unfocused = {
          fg = fg3;
          text = fg4;
          bg = bg0;
          base = bg0;
          selectedBg = bg2;
          selectedFg = fg1;
        };
      };

      gtk4 = theme.mkGtkColors {
        title = "Gruvbox Dark";
        accent = yellow;
        accentFg = bg0;
        destructiveBg = red;
        destructiveFg = fg0;
        windowBg = bg0;
        windowFg = fg1;
        headerbarBg = bg1;
        headerbarBackdrop = "@window_bg_color";
        popoverBg = bg1;
        cardBg = bg1;
        dialogBg = bg0;
        dialogFg = fg1;
        sidebarBg = bg1;
        sidebarBackdrop = "@window_bg_color";
        sidebarBorder = bg2;
        secondarySidebarBg = bg0;
        secondarySidebarFg = fg2;
      };

      qt6 = theme.mkQt6ColorScheme {
        active = [
          fg1
          bg1
          "#ffffff"
          bg3
          bg2
          bg2
          fg1
          "#ffffff"
          fg1
          bg0
          bg0
          "#000000"
          yellow
          bg0
          yellow
          blue
          bg1
          bg0h
          bg1
          fg1
          fg4
          yellow
        ];
        disabled = [
          fg4
          bg1
          "#ffffff"
          bg3
          bg2
          bg2
          fg4
          "#ffffff"
          fg4
          bg0
          bg0
          "#000000"
          bg3
          bg2
          bg3
          blue
          bg1
          bg0h
          bg1
          fg4
          gray
          bg3
        ];
        inactive = [
          fg2
          bg1
          "#ffffff"
          bg3
          bg2
          bg2
          fg2
          "#ffffff"
          fg2
          bg0
          bg0
          "#000000"
          yellow
          bg0
          yellow
          blue
          bg1
          bg0h
          bg1
          fg2
          fg4
          yellow
        ];
      };

      kitty = theme.mkKittyColors {
        title = "Gruvbox Dark Kitty";
        cursor = fg1;
        cursorText = bg0;
        foreground = fg1;
        background = bg0;
        selectionForeground = bg0;
        selectionBackground = yellow;
        color0 = bg1;
        color8 = bg3;
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
        color7 = fg4;
        color15 = fg1;
      };

      fish = theme.mkFishColors {
        normal = fg1;
        command = yellow;
        keyword = orange;
        quote = green;
        redirection = aqua;
        end = fg4;
        error = red;
        param = fg2;
        comment = bg4;
        selection = bg2;
        searchMatch = bg1;
        operator = orange;
        escape = purple;
        autosuggestion = bg4;
      };

      starship = theme.mkStarshipPrompt {
        success = yellow;
        error = red;
        directory = blue;
        gitBranch = orange;
        cmdDuration = fg4;
      };

      rofi = theme.mkProfilePickerRofi {
        background = bg0;
        text = fg1;
        border = bg2;
        selectedBackground = bg1;
        selectedForeground = yellow;
        inputBackground = bg1;
        prompt = yellow;
        placeholder = bg3;
        elementBackground = bg1;
        elementSelectedBackground = bg2;
        elementSelectedBorder = yellow;
      };
    };

    waybar = {
      config = waybar.mkConfig {
        floating = true;
        scriptDir = "${config.repoPath}/home/scripts";
      };
      style = waybar.mkFloatingStyle {
        windowBg = "rgba(40, 40, 40, 0.6)";
        primary = yellow;
        borderColor = bg2;
        shadowColor = "rgba(29, 32, 33, 0.45)";
        activeBg = bg2;
        hoverColor = orange;
        clockColor = yellow;
        textColor = fg1;
        performanceColor = red;
        balancedColor = yellow;
        powerSaverColor = green;
        warningColor = yellow;
        criticalColor = red;
      };
    };

    colorsLight = {
      gtk3 = theme.mkGtkColors {
        title = "Gruvbox Light Hard";
        accent = l_yellow;
        accentFg = l_fg0;
        destructiveBg = l_red;
        destructiveFg = l_bg0;
        windowBg = l_bg0;
        windowFg = l_fg1;
        headerbarBg = l_bg1;
        headerbarBackdrop = "@window_bg_color";
        popoverBg = l_bg1;
        cardBg = l_bg1;
        dialogBg = l_bg0;
        dialogFg = l_fg1;
        sidebarBg = l_bg1;
        sidebarBackdrop = "@window_bg_color";
        sidebarBorder = l_bg2;
        secondarySidebarBg = l_bg0;
        secondarySidebarFg = l_fg2;
        unfocused = {
          fg = l_fg3;
          text = l_fg4;
          bg = l_bg0;
          base = l_bg0;
          selectedBg = l_bg2;
          selectedFg = l_fg1;
        };
      };

      gtk4 = theme.mkGtkColors {
        title = "Gruvbox Light Hard";
        accent = l_yellow;
        accentFg = l_fg0;
        destructiveBg = l_red;
        destructiveFg = l_bg0;
        windowBg = l_bg0;
        windowFg = l_fg1;
        headerbarBg = l_bg1;
        headerbarBackdrop = "@window_bg_color";
        popoverBg = l_bg1;
        cardBg = l_bg1;
        dialogBg = l_bg0;
        dialogFg = l_fg1;
        sidebarBg = l_bg1;
        sidebarBackdrop = "@window_bg_color";
        sidebarBorder = l_bg2;
        secondarySidebarBg = l_bg0;
        secondarySidebarFg = l_fg2;
      };

      qt6 = theme.mkQt6ColorScheme {
        active = [
          l_fg1
          l_bg1
          "#ffffff"
          l_bg3
          l_bg2
          l_bg2
          l_fg1
          "#ffffff"
          l_fg1
          l_bg0
          l_bg0
          "#000000"
          l_yellow
          l_bg0
          l_yellow
          l_blue
          l_bg1
          l_bg0h
          l_bg1
          l_fg1
          l_fg4
          l_yellow
        ];
        disabled = [
          l_fg4
          l_bg1
          "#ffffff"
          l_bg3
          l_bg2
          l_bg2
          l_fg4
          "#ffffff"
          l_fg4
          l_bg0
          l_bg0
          "#000000"
          l_bg3
          l_bg2
          l_bg3
          l_blue
          l_bg1
          l_bg0h
          l_bg1
          l_fg4
          l_gray
          l_bg3
        ];
        inactive = [
          l_fg2
          l_bg1
          "#ffffff"
          l_bg3
          l_bg2
          l_bg2
          l_fg2
          "#ffffff"
          l_fg2
          l_bg0
          l_bg0
          "#000000"
          l_yellow
          l_bg0
          l_yellow
          l_blue
          l_bg1
          l_bg0h
          l_bg1
          l_fg2
          l_fg4
          l_yellow
        ];
      };

      kitty = theme.mkKittyColors {
        title = "Gruvbox Light Hard Kitty";
        cursor = l_fg1;
        cursorText = l_bg0;
        foreground = l_fg1;
        background = l_bg0;
        selectionForeground = l_bg0;
        selectionBackground = l_yellow;
        color0 = l_bg1;
        color8 = l_bg3;
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
        color7 = l_fg4;
        color15 = l_fg1;
      };

      fish = theme.mkFishColors {
        normal = l_fg1;
        command = l_yellow;
        keyword = l_orange;
        quote = l_green;
        redirection = l_aqua;
        end = l_fg4;
        error = l_red;
        param = l_fg2;
        comment = l_bg4;
        selection = l_bg2;
        searchMatch = l_bg1;
        operator = l_orange;
        escape = l_purple;
        autosuggestion = l_bg4;
      };

      starship = theme.mkStarshipPrompt {
        success = l_yellow;
        error = l_red;
        directory = l_blue;
        gitBranch = l_orange;
        cmdDuration = l_fg4;
      };

      rofi = theme.mkProfilePickerRofi {
        background = l_bg0;
        text = l_fg1;
        border = l_bg2;
        selectedBackground = l_bg1;
        selectedForeground = l_yellow;
        inputBackground = l_bg1;
        prompt = l_yellow;
        placeholder = l_bg3;
        elementBackground = l_bg1;
        elementSelectedBackground = l_bg2;
        elementSelectedBorder = l_yellow;
      };
    };

    waybarLight.style = waybar.mkFloatingStyle {
      windowBg = "rgba(251, 241, 199, 0.85)";
      primary = l_yellow;
      borderColor = l_bg2;
      shadowColor = "rgba(189, 174, 147, 0.45)";
      activeBg = l_bg2;
      hoverColor = l_orange;
      clockColor = l_yellow;
      textColor = l_fg1;
      performanceColor = l_red;
      balancedColor = l_yellow;
      powerSaverColor = l_green;
      warningColor = l_yellow;
      criticalColor = l_red;
    };
  };
}
