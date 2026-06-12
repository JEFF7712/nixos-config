{ pkgs, config, ... }:

# nordzy cursor/icon themes are used when available.
# mako handles notifications (noctalia manages its own when active).
# Dark-only profile; no colorsLight.

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  nord0 = "#2e3440";
  nord1 = "#3b4252";
  nord2 = "#434c5e";
  nord3 = "#4c566a";
  nord4 = "#d8dee9";
  nord5 = "#e5e9f0";
  nord6 = "#eceff4";
  nord7 = "#8fbcbb";
  nord8 = "#88c0d0";
  nord9 = "#81a1c1";
  nord10 = "#5e81ac";
  nord11 = "#bf616a";
  nord12 = "#d08770";
  nord13 = "#ebcb8b";
  nord14 = "#a3be8c";
  nord15 = "#b48ead";

  gtkArgs = {
    accent = nord8;
    accentFg = nord0;
    destructiveBg = nord11;
    destructiveFg = nord6;
    windowBg = nord0;
    windowFg = nord4;
    headerbarBg = nord1;
    headerbarBackdrop = "@window_bg_color";
    popoverBg = nord1;
    cardBg = nord1;
    dialogBg = nord0;
    dialogFg = nord4;
    sidebarBg = nord1;
    sidebarBackdrop = "@window_bg_color";
    sidebarBorder = "@window_bg_color";
    secondarySidebarBg = nord0;
    secondarySidebarFg = nord4;
    unfocused = {
      fg = "@window_fg_color";
      text = "@view_fg_color";
      bg = "@window_bg_color";
      base = "@window_bg_color";
      selectedBg = "@accent_bg_color";
      selectedFg = "@accent_fg_color";
    };
  };
in
{
  desktopProfiles.profiles.nord = {
    bar = "quickshell";

    quickshellTheme = {
      fg = nord4;
      bg = "#ee2e3440";
      popupBg = "#ee2e3440";
      rawBg = nord0;
      accent = nord8;
      second = nord9;
      warm = nord12;
      fresh = nord14;
      barRadius = "0";
      barHeight = "26";
      barMargin = "0";
      showClockDate = "false";
      showWorkspaceNumbers = "true";
      barFont = "Iosevka Nerd Font";
      barBorder = "#00000000";
      barInnerHighlight = "#00000000";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      flatMode = "true";
      dividerColor = nord3;
    };

    makoConfig = theme.mkMakoConfig {
      background = nord0;
      text = nord4;
      border = nord8;
      lowBorder = nord3;
      highBackground = nord1;
      highBorder = nord11;
      highText = nord6;
      font = "Iosevka Nerd Font 11";
      borderSize = 1;
      borderRadius = 0;
      padding = 10;
      margin = 6;
    };

    cursor = {
      theme = "Nordzy-cursors";
      size = 24;
      package = pkgs.nordzy-cursor-theme;
    };

    fonts = {
      ui = {
        family = "IBM Plex Sans";
        size = 11;
      };
      mono = {
        family = "Iosevka Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = null;
      iconTheme = "Tela-nord-dark";
      iconThemeLight = null;
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/nord";

    niri = {
      gaps = 6;
      borderOff = false;
      borderWidth = 1;
      borderActiveColor = nord8;
      borderInactiveColor = nord1;
      urgentColor = nord11;
      focusRingOff = true;
      shadowOff = true;
      shadowSoftness = 0;
      shadowSpread = 0;
      shadowOffsetX = 0;
      shadowOffsetY = 0;
      shadowColor = "#00000000";
      shadowInactiveColor = "#00000000";
      shadowDrawBehindWindow = false;
      tabIndicatorOff = false;
      tabIndicatorActiveColor = nord8;
      tabIndicatorInactiveColor = nord3;
      windowOpacity = 1.0;
      windowHighlightOff = true;
      extraConfig = ''
        window-rule {
            geometry-corner-radius 0
            clip-to-geometry true
        }
      '';
    };

    colors = {
      gtk3 = theme.mkGtkColors (gtkArgs // { title = "GTK3 Nord Theme"; });
      gtk4 = theme.mkGtkColors (
        builtins.removeAttrs gtkArgs [ "unfocused" ] // { title = "GTK4 Nord Theme"; }
      );

      qt6 = theme.mkQt6Roles {
        windowText = nord4;
        button = nord1;
        midlight = nord3;
        mid = nord2;
        window = nord0;
        highlight = nord10;
        highlightedText = nord6;
        link = nord9;
        linkVisited = nord8;
        alternateBase = nord3;
        tooltipBase = nord0;
        tooltipText = nord3;
        secondaryText = nord4;
        accent = nord8;
        disabledText = nord3;
        disabledHighlight = nord10;
        disabledLink = nord9;
        disabledAccent = nord8;
      };

      kitty = theme.mkKittyColors {
        title = "Nord Kitty Theme";
        cursor = nord4;
        cursorText = nord0;
        foreground = nord4;
        background = nord0;
        selectionForeground = nord0;
        selectionBackground = nord8;
        color0 = nord1;
        color8 = nord3;
        color1 = nord11;
        color9 = nord11;
        color2 = nord14;
        color10 = nord14;
        color3 = nord13;
        color11 = nord13;
        color4 = nord9;
        color12 = nord9;
        color5 = nord15;
        color13 = nord15;
        color6 = nord7;
        color14 = nord7;
        color7 = nord5;
        color15 = nord6;
      };

      fish = theme.mkFishColors {
        normal = nord4;
        command = nord8;
        keyword = nord9;
        quote = nord14;
        redirection = nord4;
        end = nord3;
        error = nord11;
        param = nord4;
        comment = nord3;
        selection = nord2;
        searchMatch = nord2;
        operator = nord8;
        escape = nord13;
        autosuggestion = nord3;
      };

      starship = theme.mkStarshipPrompt {
        success = nord8;
        error = nord11;
        directory = nord9;
        gitBranch = nord10;
        cmdDuration = nord3;
      };

      rofi = theme.mkProfilePickerRofi {
        background = nord0;
        text = nord4;
        border = nord3;
        selectedBackground = nord1;
        selectedForeground = nord8;
        inputBackground = nord1;
        prompt = nord8;
        placeholder = nord3;
        elementBackground = nord1;
        elementSelectedBackground = nord2;
        elementSelectedBorder = nord8;
      };

      btop = theme.mkBtopTheme {
        mainBg = nord0;
        mainFg = nord4;
        hiFg = nord8;
        selectedBg = nord2;
        inactiveFg = nord3;
        procMisc = nord7;
        box = nord2;
        gradLow = nord14;
        gradMid = nord13;
        gradHigh = nord11;
      };

      tmux = theme.mkTmuxColors {
        bg = nord1;
        fg = nord4;
        accent = nord8;
        secondary = nord9;
        inactive = nord3;
        border = nord2;
      };

      # Matches the pre-profile hyprlock.conf values; the muted tone and the
      # darker-than-nord0 surface are not palette colors.
      hyprlock = theme.mkHyprlockColors {
        fg = nord6;
        muted = "#aeb7c5";
        accent = nord8;
        surface = "#171b22";
        surfaceAlt = nord0;
        error = nord11;
      };

      cava = theme.mkCavaColors {
        gradLow = nord14;
        gradMid = nord13;
        gradHigh = nord11;
      };
    };

    waybar = {
      config = waybar.mkConfig {
        floating = true;
        scriptDir = "${config.repoPath}/home/scripts";
      };
      style = waybar.mkFloatingStyle {
        windowBg = "rgba(46, 52, 64, 0.6)";
        primary = nord8;
        borderColor = nord2;
        shadowColor = "rgba(36, 41, 51, 0.45)";
        activeBg = nord2;
        hoverColor = nord7;
        clockColor = nord4;
        textColor = nord4;
        performanceColor = nord11;
        balancedColor = nord8;
        powerSaverColor = nord14;
        warningColor = nord13;
        criticalColor = nord11;
      };
    };
  };
}
