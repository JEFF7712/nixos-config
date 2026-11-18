{ pkgs, config, ... }:

let
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;
  trails = import ../../../lib/desktop-profiles/kitty-cursor-trail.nix;
  motionPresets = import ../../../lib/desktop-profiles/motion.nix;

  bg0 = "#141414";
  bg1 = "#202020";
  bg2 = "#323232";
  bg3 = "#5f5f5f";
  fg0 = "#ffffff";
  fg1 = "#f2f2f2";
  fg2 = "#c8c8c8";
  accent = "#ffffff";
  err = "#f0dada";

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
in
{
  desktopProfiles.profiles.clean = {
    bar = "quickshell";
    wallpaperTheming = true;
    colorEngine = "temperature";

    quickshellTheme = {
      fg = "#ffffff";
      bg = "#66101010";
      popupBg = "#66101010";
      rawBg = "#101010";
      accent = "#ffffff";
      second = "#e8e8e8";
      warm = "#e6dcc6";
      fresh = "#d6eadc";
      barHeight = "30";
      barMarginTop = "7";
      exclusiveZoneOffset = "-3";
      barRadius = "10";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      showClockDate = "false";
      showWorkspaceNumbers = "false";
      popupAnimationStyle = "quickFade";
      motionStyle = "dry";
      showWorkspaceIndicator = "true";
      showIdleGreeting = "true";
      barFont = "JetBrainsMono Nerd Font";
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
        family = "JetBrainsMono Nerd Font";
        size = 13;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = null;
      iconTheme = "Papirus-Dark";
      iconThemeLight = "Papirus-Dark";
      kittyOpacity = 0.4;
      kittyCursorTrail = trails.snappy;
      motion = motionPresets.snappy;
    };

    wallpaperDir = "${config.assetsPath}/wallpapers/clean";

    niri = {
      animations = animations.snappy;
      gaps = 12;
      cornerRadius = 15;
      borderOff = true;
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
        // Outline, not filled: default border-with-background washes through glass.
        window-rule {
            draw-border-with-background false
        }

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
            opacity 0.9
            background-effect {
                blur true
                xray false
                noise 0.015
                saturation 1.25
            }
        }

        // Compositor blur over wallpaper, independent of the spicetify theme.
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

        // Same glass as the bar: 0.4 client fill × 0.9 compositor opacity,
        // wallpaper-tinted blur (xray is fine on real windows).
        window-rule {
            match app-id="kitty"
            opacity 0.9
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.25
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
        tooltipBase = bg1;
        tooltipText = fg1;
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

      zathura = theme.mkZathuraColors {
        bg = bg0;
        fg = fg1;
        surface = bg1;
        muted = fg2;
        inherit accent;
        error = err;
        recolorLight = bg0;
        recolorDark = fg0;
      };

    };
  };
}
