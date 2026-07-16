{ pkgs, config, ... }:

let
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;

  bg0 = "#141414";
  bg1 = "#202020";
  bg2 = "#323232";
  bg3 = "#5f5f5f";
  fg0 = "#ffffff";
  fg1 = "#f2f2f2";
  fg2 = "#c8c8c8";
  accent = "#ffffff";
  err = "#f0dada";
  glass0 = "rgba(20, 20, 20, 0.42)";
  glass1 = "rgba(255, 255, 255, 0.08)";
  glass2 = "rgba(255, 255, 255, 0.14)";
  glassBorder = "rgba(255, 255, 255, 0.34)";

  gtk = theme.mkGtkColors {
    inherit accent;
    accentBg = "rgba(255, 255, 255, 0.24)";
    accentFg = bg0;
    destructiveBg = err;
    destructiveFg = fg0;
    windowBg = "rgba(20, 20, 20, 0.54)";
    windowFg = fg1;
    viewBg = "rgba(20, 20, 20, 0.44)";
    headerbarBg = "rgba(255, 255, 255, 0.08)";
    popoverBg = "rgba(20, 20, 20, 0.74)";
    cardBg = "rgba(255, 255, 255, 0.08)";
    sidebarBg = "rgba(255, 255, 255, 0.06)";
    sidebarBorder = "rgba(255, 255, 255, 0.18)";
  };

  rofi = theme.mkProfilePickerRofi {
    background = glass0;
    text = fg1;
    border = glassBorder;
    selectedBackground = glass2;
    selectedForeground = fg0;
    normalBackground = "transparent";
    windowBackground = glass0;
    inputBackground = glass1;
    prompt = fg1;
    placeholder = fg2;
    elementBackground = glass1;
    elementSelectedBackground = glass2;
    elementSelectedBorder = accent;
    borderWidth = 1;
    selectedBorderWidth = 1;
    windowRadius = 15;
    inputRadius = 10;
    elementRadius = 10;
    inputBorder = "1px solid; border-color: ${glassBorder}";
    elementBorder = "1px solid; border-color: rgba(255, 255, 255, 0.16)";
    placeholderText = "Switch profile...";
  };
in
{
  desktopProfiles.profiles.clean = {
    bar = "quickshell";
    wallpaperTheming = true;
    colorEngine = "temperature";

    quickshellTheme = {
      fg = "#ffffff";
      bg = "#66101010";
      popupBg = "#cc101010";
      rawBg = "#101010";
      accent = "#ffffff";
      second = "#e8e8e8";
      warm = "#e6dcc6";
      fresh = "#d6eadc";
      barHeight = "38";
      showClockDate = "false";
      popupAnimationStyle = "quickFade";
    };

    cursor = {
      theme = "Bibata-Modern-Ice";
      size = 22;
      package = pkgs.bibata-cursors;
    };

    fonts = {
      ui = {
        family = "JetBrainsMono Nerd Font";
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
      iconTheme = "Papirus-Dark";
      iconThemeLight = "Papirus-Dark";
      kittyOpacity = 0.78;
    };

    wallpaperDir = "${config.assetsPath}/wallpapers/clean";

    makoConfig = theme.mkMakoConfig {
      # match the clean bar (#66101010), a touch more opaque
      background = "#10101080";
      text = fg1;
      border = "#ffffff66";
      lowBorder = "#ffffff44";
      highBackground = "#1a1a1ab3";
      highBorder = "#ffffffaa";
      highText = fg0;
      borderSize = 1;
      borderRadius = 6;
    };

    niri = {
      animations = animations.snappy;
      gaps = 16;
      cornerRadius = 15;
      borderOff = false;
      borderWidth = 1;
      borderActiveColor = "#ffffffcc";
      borderInactiveColor = "#ffffff44";
      focusRingOff = true;
      shadowSoftness = 34;
      shadowSpread = 2;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#00000022";
      shadowInactiveColor = "#00000016";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = true;
      windowOpacity = 0.85;
      focusOpacity = false;
      blur = true;
      windowHighlightOff = true;
      extraConfig = ''
        layer-rule {
            match namespace="^quickshell-topbar$"
            geometry-corner-radius 15
            opacity 0.9
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.25
            }
        }

        layer-rule {
            match namespace="^quickshell-popup$"
            geometry-corner-radius 15
        }

        layer-rule {
            match namespace="^rofi$"
            geometry-corner-radius 15
            opacity 0.88
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.25
            }
        }

        layer-rule {
            match namespace="^mako$"
            geometry-corner-radius 6
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.2
            }
        }

        layer-rule {
            match namespace="^swayosd$"
            geometry-corner-radius 10
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.2
            }
        }

        // Spotify glass: compositor-level transparency + blur over the
        // wallpaper, independent of the spicetify theme (so it never breaks on
        // Spotify UI updates). Matches the 0.85 global window opacity; keep the
        // dedicated rule for blur/noise/radius independent of global defaults.
        window-rule {
            match app-id="Spotify"
            geometry-corner-radius 12
            clip-to-geometry true
            opacity 0.85
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.2
            }
        }
      '';
    };

    colors = {
      gtk3 = gtk;
      gtk4 = gtk;

      qt6 = theme.mkQt6Roles {
        windowText = fg1;
        button = bg1;
        midlight = bg3;
        mid = bg2;
        window = bg0;
        highlight = accent;
        highlightedText = bg2;
        linkVisited = fg2;
        alternateBase = bg1;
        tooltipBase = bg0;
        tooltipText = bg1;
        secondaryText = fg2;
        inactiveText = fg2;
        disabledText = fg2;
        disabledHighlight = bg3;
      };

      kitty = theme.mkKittyColors {
        cursor = fg1;
        cursorText = bg0;
        foreground = fg1;
        background = bg0;
        selectionForeground = bg0;
        selectionBackground = bg3;
        color0 = bg1;
        color8 = bg3;
        color1 = err;
        color9 = err;
        color2 = fg2;
        color10 = fg1;
        color3 = fg2;
        color11 = fg1;
        color4 = fg2;
        color12 = fg1;
        color5 = fg2;
        color13 = fg1;
        color6 = fg2;
        color14 = fg1;
        color7 = fg1;
        color15 = fg0;
      };

      fish = theme.mkFishColors {
        normal = fg1;
        command = fg0;
        keyword = fg0;
        quote = fg2;
        error = fg0;
        param = fg1;
        comment = fg2;
        selection = bg2;
        autosuggestion = fg2;
      };

      starship = theme.mkStarshipPrompt {
        success = fg1;
        error = fg0;
        directory = fg0;
        gitBranch = fg2;
        cmdDuration = fg2;
      };

      inherit rofi;

      btop = theme.mkBtopTheme {
        mainBg = bg0;
        mainFg = fg1;
        hiFg = accent;
        selectedBg = bg2;
        inactiveFg = fg2;
        procMisc = fg2;
        box = bg2;
        gradLow = fg2;
        gradMid = fg1;
        gradHigh = fg0;
      };

      tmux = theme.mkTmuxColors {
        bg = bg1;
        fg = fg1;
        accent = fg0;
        secondary = fg2;
        inactive = fg2;
        border = bg2;
      };

      hyprlock = theme.mkHyprlockColors {
        fg = fg0;
        muted = fg2;
        inherit accent;
        surface = bg0;
        surfaceAlt = bg1;
        error = err;
      };

      cava = theme.mkCavaColors {
        gradLow = fg2;
        gradMid = fg1;
        gradHigh = fg0;
      };
    };
  };
}
