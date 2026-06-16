# Tinted: opaque, wallpaper-driven profile.
#
# Unlike the static schemes, every surface here is fully opaque (no blur, no
# per-focus translucency) and the palette is regenerated from the current
# wallpaper at runtime by `apply_wallpaper_theme` (matugen). The colors below
# are only the pre-first-tint fallback — on the first wallpaper change after a
# switch, matugen overwrites the quickshell theme, GTK/Qt/kitty/cava/etc. from
# the wallpaper's dominant color (dark or light per the active variant).
{ config, ... }:

let
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;

  # Soft, low-contrast fallback palettes. Dark = warm charcoal, light = cream —
  # both in the spirit of the wallpaper-tinted result before matugen runs.
  dark = rec {
    title = "Tinted dark";
    bg0 = "#16181c";
    bg1 = "#1d2024";
    bg2 = "#24272c";
    bg3 = "#33373d";
    fg0 = "#e6e8ec";
    fg1 = "#c4c8ce";
    fg2 = "#8b9098";
    accent = "#9fc6e8";
    err = "#ffb4ab";
    rofiText = fg1;
  };

  light = rec {
    title = "Tinted light";
    bg0 = "#f3efe9";
    bg1 = "#eae5dd";
    bg2 = "#e0dacf";
    bg3 = "#cbc3b6";
    fg0 = "#2a2620";
    fg1 = "#443e34";
    fg2 = "#6d6555";
    accent = "#7d8a5a";
    err = "#ba1a1a";
    rofiText = fg0;
  };

  mkColors =
    p:
    theme.mkGtkPair {
      inherit (p) title accent;
      accentBg = p.accent;
      accentFg = p.bg0;
      destructiveBg = p.err;
      destructiveFg = p.fg0;
      windowBg = p.bg0;
      windowFg = p.fg1;
      headerbarBg = p.bg1;
      headerbarBackdrop = "@window_bg_color";
      popoverBg = p.bg2;
      cardBg = p.bg2;
      dialogBg = p.bg2;
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
        highlightedText = p.bg0;
        linkVisited = p.fg2;
        alternateBase = p.bg1;
        tooltipBase = p.bg2;
        tooltipText = p.fg1;
        secondaryText = p.fg2;
        inactiveText = p.fg2;
        disabledText = p.fg2;
        disabledHighlight = p.bg3;
      };

      # Readable fallback (matugen overwrites this on the first tint). A dark
      # surface bg keeps text legible; the accent is the only colored pop.
      kitty = theme.mkKittyColors {
        inherit (p) title;
        cursor = p.accent;
        cursorText = p.bg0;
        foreground = p.fg0;
        background = p.bg0;
        selectionForeground = p.bg0;
        selectionBackground = p.accent;
        color0 = p.bg1;
        color8 = p.fg2;
        color1 = p.err;
        color9 = p.err;
        color2 = p.accent;
        color10 = p.accent;
        color3 = p.fg1;
        color11 = p.fg0;
        color4 = p.accent;
        color12 = p.accent;
        color5 = p.fg1;
        color13 = p.fg0;
        color6 = p.accent;
        color14 = p.accent;
        color7 = p.fg1;
        color15 = p.fg0;
      };

      fish = theme.mkFishColors {
        normal = p.fg1;
        command = p.accent;
        keyword = p.accent;
        quote = p.fg2;
        redirection = p.fg2;
        end = p.fg2;
        error = p.err;
        param = p.fg1;
        comment = p.fg2;
        selection = p.bg2;
        searchMatch = p.bg2;
        operator = p.accent;
        escape = p.fg2;
        autosuggestion = p.fg2;
      };

      starship = theme.mkStarshipPrompt {
        success = p.accent;
        error = p.err;
        directory = p.fg1;
        gitBranch = p.fg2;
        cmdDuration = p.fg2;
      };

      rofi = theme.mkProfilePickerRofi {
        background = p.bg0;
        text = p.rofiText;
        border = p.bg3;
        selectedBackground = p.bg2;
        selectedForeground = p.accent;
        inputBackground = p.bg1;
        prompt = p.rofiText;
        placeholder = p.fg2;
        elementBackground = p.bg1;
        elementSelectedBackground = p.bg2;
        elementSelectedBorder = p.accent;
        windowRadius = 16;
        inputRadius = 12;
        elementRadius = 12;
        iconRadius = 10;
      };

      btop = theme.mkBtopTheme {
        mainBg = p.bg0;
        mainFg = p.fg1;
        hiFg = p.accent;
        selectedBg = p.bg2;
        inactiveFg = p.fg2;
        procMisc = p.fg2;
        box = p.bg2;
        gradLow = p.fg2;
        gradMid = p.accent;
        gradHigh = p.fg0;
      };

      tmux = theme.mkTmuxColors {
        bg = p.bg1;
        fg = p.fg1;
        inherit (p) accent;
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
        gradMid = p.accent;
        gradHigh = p.fg0;
      };
    };

  # Opaque quickshell theme: bar, popups and base are all the main (accent)
  # color, fully solid. matugen overwrites these from the wallpaper at runtime.
  mkQuickshell = p: {
    fg = p.bg0;
    bg = p.accent;
    popupBg = p.accent;
    rawBg = p.accent;
    accent = p.bg0;
    second = p.bg1;
    warm = p.bg1;
    fresh = p.bg1;
    barRadius = "0";
    barHeight = "30";
    barMargin = "0";
    flatMode = "true";
    showClockDate = "false";
    showWorkspaceNumbers = "true";
    showBarDividers = "false";
    barFont = "Maple Mono NF";
    barBorder = "#00000000";
    barInnerHighlight = "#00000000";
    pillBg = "#00000000";
    pillBorder = "#00000000";
    dividerColor = p.bg3;
    moduleAnimationStyle = "slide";
    popupAttachToBar = "true";
    popupAnimationStyle = "attachedSlide";
  };
in
{
  desktopProfiles.profiles.tinted = {
    bar = "quickshell";
    wallpaperTheming = true;
    # iris (vendored from Alphonso): k-means CIELAB palette extraction with
    # built-in WCAG contrast nudging. Deep wallpaper-tinted surfaces, legible
    # text guaranteed, auto dark/light. matugenScheme is unused under iris.
    colorEngine = "iris";

    quickshellTheme = mkQuickshell dark;
    quickshellThemeLight = mkQuickshell light;

    cursor = {
      theme = "Adwaita";
      size = 24;
    };

    fonts = {
      ui = {
        family = "Maple Mono NF";
        size = 11;
      };
      mono = {
        family = "Maple Mono NF";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = "adw-gtk3";
      iconTheme = "WhiteSur-dark";
      iconThemeLight = "WhiteSur-light";
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/tinted";

    niri = {
      animations = animations.soft;
      gaps = 12;
      borderOff = true;
      focusRingOff = true;
      # Opaque: solid windows, no per-focus dimming, no blur.
      windowOpacity = 1.0;
      focusOpacity = false;
      blur = false;
      shadowSoftness = 28;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#00000040";
      shadowInactiveColor = "#0000002a";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = true;
      tabIndicatorActiveColor = dark.accent;
      tabIndicatorInactiveColor = dark.bg3;
    };

    colors = mkColors dark;
    colorsLight = mkColors light;
  };
}
