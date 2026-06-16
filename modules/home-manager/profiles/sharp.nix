{ pkgs, config, ... }:

let
  waybar = import ../../../lib/waybar.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;

  # Neutral greys only. One role mapping serves dark and light; `rofiText`
  # and `hoverBg` are the two slots that differ beyond the palette itself.
  dark = rec {
    title = "Sharp dark";
    bg0 = "#141414";
    bg1 = "#1c1c1c";
    bg2 = "#262626";
    bg3 = "#3a3a3a";
    fg0 = "#f2f2f2";
    fg1 = "#c8c8c8";
    fg2 = "#8a8a8a";
    accent = "#e0e0e0";
    err = "#5c5c5c";
    rofiText = fg1;
    hoverBg = "rgba(255,255,255,0.06)";
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
    hoverBg = "rgba(0,0,0,0.06)";
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
        button = p.bg1;
        midlight = p.bg3;
        mid = p.bg2;
        window = p.bg0;
        highlight = p.accent;
        highlightedText = p.bg2;
        linkVisited = p.fg2;
        alternateBase = p.bg1;
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
    };

  mkMako =
    p:
    theme.mkMakoConfig {
      background = p.bg0;
      text = p.fg1;
      border = p.bg3;
      lowBorder = p.bg2;
      highBackground = p.bg1;
      highBorder = p.err;
      highText = p.fg0;
      borderSize = 1;
      borderRadius = 0;
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

  mkWaybarStyle =
    p:
    waybar.mkFlatStyle {
      fg = p.fg1;
      activeText = p.fg0;
      activeUnderline = p.fg0;
      clockColor = p.fg1;
      performanceColor = p.fg2;
      balancedColor = p.fg1;
      powerSaverColor = p.fg2;
      warningColor = p.accent;
      criticalColor = p.fg0;
      inherit (p) hoverBg;
    };
in
{
  desktopProfiles.profiles.sharp = {
    bar = "quickshell";

    # Transparent, monochrome counterpart to `tinted`: surfaces stay near-grey
    # (subtly tinted toward the wallpaper) while the wallpaper's primary becomes
    # the accent. apply_wallpaper_theme picks config-sharp.toml at runtime; the
    # baked greys below are the pre-first-tint fallback. tonal-spot keeps surface
    # chroma low (subtle tint) while the accent still follows the wallpaper hue.
    wallpaperTheming = true;
    matugenScheme = "scheme-tonal-spot";
    # Accent = the wallpaper's most vivid+bright color (not the dominant mood
    # hue), surfaced raw via {{colors.source_color}} in the sharp templates.
    wallpaperAccentVivid = true;

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    makoConfig = mkMako dark;
    makoConfigLight = mkMako light;

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
      iconTheme = "Colloid-Dark";
      iconThemeLight = "Colloid-Light";
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/sharp";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/sharp-light";

    niri = {
      animations = animations.snappy;
      gaps = 6;
      # No border; the focused window is marked by a thin accent focus ring
      # (active-color overridden at runtime by the matugen-rendered include
      # below to the wallpaper accent). Windows stay transparent (per-focus
      # 0.8/0.6 + blur, the niri defaults).
      borderOff = true;
      focusRingOff = false;
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
      windowOpacity = 1.0;
      windowHighlightOff = true;
      extraConfig = ''
        // Draw the focus ring as an outline, NOT a solid filled rectangle behind
        // the window. Without this, niri fills the ring's background for windows
        // that omit client-side decorations, which bleeds the accent through
        // transparent windows and reads as a whole-window tint.
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
            match namespace="^mako$"
            geometry-corner-radius 0
        }

        // Wallpaper-driven accent focus ring (matugen renders this file on every
        // wallpaper change; the activation default below seeds it). Last include
        // wins, so it overrides the focus-ring block above.
        include "${config.home.homeDirectory}/.config/desktop-profiles/runtime-niri-sharp.kdl"
      '';
    };

    colors = mkColors dark;
    colorsLight = mkColors light;

    waybar = {
      config = waybar.mkConfig { scriptDir = "${config.repoPath}/home/scripts"; };
      style = mkWaybarStyle dark;
    };
    waybarLight.style = mkWaybarStyle light;
  };

  # niri errors on a missing include, so seed runtime-niri-sharp.kdl with the
  # baked accent focus ring before matugen ever runs. Only when absent — never
  # clobber a wallpaper-rendered version on rebuild.
  home.activation.sharpNiriAccentDefault = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    f="${config.home.homeDirectory}/.config/desktop-profiles/runtime-niri-sharp.kdl"
    if [ ! -e "$f" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$f")"
      $DRY_RUN_CMD install -m 644 ${pkgs.writeText "runtime-niri-sharp-default.kdl" ''
        layout {
            focus-ring {
                on
                width 0.5
                active-color "${dark.accent}"
                inactive-color "#00000000"
            }
        }
      ''} "$f"
    fi
  '';
}
