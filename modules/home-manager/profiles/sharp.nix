{ pkgs, config, ... }:

let
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;

  # Neutral greys; `rofiText` is the only slot that differs beyond the palette.
  dark = rec {
    title = "Sharp dark";
    bg0 = "#0a0a0a";
    bg1 = "#121212";
    bg2 = "#1e1e1e";
    bg3 = "#2e2e2e";
    fg0 = "#f2f2f2";
    fg1 = "#c8c8c8";
    fg2 = "#8a8a8a";
    accent = "#e0e0e0";
    err = "#5c5c5c";
    rofiText = fg1;
  };

  light = rec {
    title = "Sharp light";
    bg0 = "#fafafa";
    bg1 = "#f0f0f0";
    bg2 = "#e2e2e2";
    bg3 = "#c8c8c8";
    fg0 = "#141414";
    fg1 = "#2e2e2e";
    fg2 = "#5a5a5a";
    accent = "#1a1a1a";
    err = "#a3a3a3";
    rofiText = fg0;
  };

  alpha = a: c: "#${a}${builtins.substring 1 6 c}";

  mkColors =
    p:
    theme.mkGtkPair {
      inherit (p) title;
      inherit (p) accent;
      accentBg = p.bg3;
      accentFg = p.bg0;
      destructiveBg = p.err;
      destructiveFg = p.fg0;
      # Flatten chrome to bg0 so GTK matches kitty (matugen templates do the
      # same with surface_container_lowest). Elevations stay on popover/card.
      windowBg = p.bg0;
      windowFg = p.fg1;
      viewBg = p.bg0;
      headerbarBg = p.bg0;
      headerbarBackdrop = "@window_bg_color";
      popoverBg = p.bg1;
      cardBg = p.bg1;
      dialogBg = p.bg0;
      dialogFg = p.fg1;
      sidebarBg = p.bg0;
      sidebarBackdrop = "@window_bg_color";
      sidebarBorder = p.bg2;
      secondarySidebarBg = p.bg0;
      secondarySidebarFg = p.fg2;
      unfocused = {
        fg = p.fg2;
        text = p.fg2;
        bg = p.bg0;
        base = p.bg0;
        selectedBg = p.bg2;
        selectedFg = p.fg0;
      };
    }
    // {
      qt6 = theme.mkQt6Roles {
        windowText = p.fg1;
        button = p.bg0;
        midlight = p.bg3;
        mid = p.bg2;
        window = p.bg0;
        highlight = p.accent;
        highlightedText = p.bg2;
        linkVisited = p.fg2;
        alternateBase = p.bg0;
        tooltipBase = p.bg0;
        tooltipText = p.bg1;
        secondaryText = p.fg2;
        inactiveText = p.fg2;
        disabledText = p.fg2;
        disabledHighlight = p.bg3;
      };

      kitty = theme.mkKittyColors {
        inherit (p) title;
        cursor = p.fg1;
        cursorText = p.bg0;
        foreground = p.fg1;
        background = p.bg0;
        selectionForeground = p.bg0;
        selectionBackground = p.bg3;
        color0 = p.bg1;
        color8 = p.bg3;
        color1 = p.err;
        color9 = p.err;
        color2 = p.fg2;
        color10 = p.fg1;
        color3 = p.fg2;
        color11 = p.fg1;
        color4 = p.fg2;
        color12 = p.fg1;
        color5 = p.fg2;
        color13 = p.fg1;
        color6 = p.fg2;
        color14 = p.fg1;
        color7 = p.fg1;
        color15 = p.fg0;
      };

      fish = theme.mkFishColors {
        normal = p.fg1;
        command = p.fg0;
        keyword = p.fg0;
        quote = p.fg2;
        redirection = p.fg2;
        end = p.fg2;
        error = p.fg0;
        param = p.fg1;
        comment = p.fg2;
        selection = p.bg2;
        searchMatch = p.bg1;
        operator = p.fg1;
        escape = p.fg2;
        autosuggestion = p.fg2;
      };

      starship = theme.mkStarshipPrompt {
        success = p.fg1;
        error = p.fg0;
        directory = p.fg0;
        gitBranch = p.fg2;
        cmdDuration = p.fg2;
      };

      rofi = theme.mkProfilePickerRofi {
        background = p.bg0;
        text = p.rofiText;
        border = p.bg3;
        selectedBackground = p.bg1;
        selectedForeground = p.accent;
        inputBackground = p.bg1;
        prompt = p.rofiText;
        placeholder = p.fg2;
        elementBackground = p.bg1;
        elementSelectedBackground = p.bg2;
        elementSelectedBorder = p.accent;
        borderWidth = 1;
        selectedBorderWidth = 1;
        windowRadius = 0;
        inputRadius = 0;
        elementRadius = 0;
        iconRadius = 0;
      };

      btop = theme.mkBtopTheme {
        mainBg = p.bg0;
        mainFg = p.fg1;
        hiFg = p.fg0;
        selectedBg = p.bg2;
        inactiveFg = p.fg2;
        procMisc = p.fg2;
        box = p.bg2;
        gradLow = p.fg2;
        gradMid = p.fg1;
        gradHigh = p.fg0;
      };

      tmux = theme.mkTmuxColors {
        bg = p.bg1;
        fg = p.fg1;
        accent = p.fg0;
        secondary = p.fg2;
        inactive = p.fg2;
        border = p.bg2;
      };

      hyprlock = theme.mkHyprlockColors {
        fg = p.fg0;
        muted = p.fg2;
        inherit (p) accent;
        surface = p.bg0;
        surfaceAlt = p.bg1;
        error = p.err;
      };

      cava = theme.mkCavaColors {
        gradLow = p.fg2;
        gradMid = p.fg1;
        gradHigh = p.fg0;
      };

      zathura = theme.mkZathuraColors {
        bg = p.bg0;
        fg = p.fg1;
        surface = p.bg1;
        muted = p.fg2;
        inherit (p) accent;
        error = p.err;
        recolorLight = p.bg0;
        recolorDark = p.fg0;
      };
    };

  mkQuickshell = p: {
    fg = p.fg0;
    bg = alpha "cc" p.bg0;
    popupBg = alpha "cc" p.bg0;
    rawBg = p.bg0;
    inherit (p) accent;
    second = p.fg1;
    warm = p.fg1;
    fresh = p.fg1;
    barRadius = "0";
    barHeight = "26";
    barMargin = "0";
    barMarginTop = "0";
    flatMode = "true";
    showClockDate = "false";
    showWorkspaceNumbers = "true";
    showBarDividers = "false";
    barFont = "JetBrainsMono Nerd Font";
    barBorder = "#00000000";
    barInnerHighlight = "#00000000";
    pillBg = "#00000000";
    pillBorder = "#00000000";
    moduleAnimationStyle = "slide";
    popupAttachToBar = "true";
    popupAnimationStyle = "attachedSlide";
  };
in
{
  desktopProfiles.profiles.sharp = {
    bar = "quickshell";

    # Wallpaper-tinted greys + wallpaper primary as accent. Fallback until first tint.
    wallpaperTheming = true;
    # Neutral-grey Obsidian surfaces; accent follows wallpaper (`apply_obsidian_sharp`).
    obsidianWallpaperTheme = true;
    matugenScheme = "scheme-tonal-spot";
    # Push M3 surfaces toward the baked bg0 (#0a0a0a).
    matugenContrast = 0.5;
    # Wallpaper's most vivid+bright color via {{colors.source_color}}, not the mood hue.
    wallpaperAccentVivid = true;

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    cursor = {
      theme = "Bibata-Modern-Ice";
      size = 22;
      package = pkgs.bibata-cursors;
    };

    fonts = {
      ui = {
        family = "Inter";
        size = 11;
      };
      mono = {
        family = "JetBrainsMono Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = "adw-gtk3";
      iconTheme = "Papirus-Dark";
      iconThemeLight = "Papirus-Dark";
    };

    wallpaperDir = "${config.assetsPath}/wallpapers/sharp";

    niri = {
      animations = animations.snappy;
      gaps = 6;
      # No border; thin accent focus ring. active-color rewritten at runtime.
      borderOff = true;
      focusRingOff = false;
      focusRingWidth = 0.5;
      focusRingActiveColor = dark.accent;
      focusRingInactiveColor = "#00000000";
      shadowOff = true;
      shadowSoftness = 0;
      shadowSpread = 0;
      shadowOffsetX = 0;
      shadowOffsetY = 0;
      shadowColor = "#00000000";
      shadowInactiveColor = "#00000000";
      shadowDrawBehindWindow = false;
      tabIndicatorOff = true;
      tabIndicatorActiveColor = dark.fg1;
      tabIndicatorInactiveColor = dark.bg3;
      windowOpacity = 0.8;
      focusOpacity = false;
      windowHighlightOff = true;
      extraConfig = ''
        // Outline the focus ring; niri otherwise fills CSD-less windows (accent bleed).
        window-rule {
            draw-border-with-background false
        }

        window-rule {
            geometry-corner-radius 0
            clip-to-geometry true
        }

        layer-rule {
            match namespace="^quickshell-topbar$"
            geometry-corner-radius 0
        }

        layer-rule {
            match namespace="^quickshell-popup$"
            geometry-corner-radius 0
        }

        layer-rule {
            match namespace="^rofi$"
            geometry-corner-radius 0
            opacity 1.0
        }

        layer-rule {
            match namespace="^quickshell-notifications$"
            geometry-corner-radius 0
        }
      '';
    };

    colors = mkColors dark;
    colorsLight = mkColors light;
  };
}
