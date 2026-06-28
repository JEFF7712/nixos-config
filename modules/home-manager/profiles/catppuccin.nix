{ pkgs, config, ... }:

# Catppuccin — Mocha (dark) + Latte (light) on the static-profile default
# mapping. Catppuccin layers surfaces as crust < mantle < base < surface0..2,
# so bg0=base with mantle/crust as darker extras (bgDim=crust) and surface2 as
# an extra above bg3=surface1. Variant-specific slots (fish*, starship*,
# rofiPlaceholder, bar*) are palette keys. Mocha replaces the derived kitty
# theme with a custom monochrome pink/purple scheme (applied post-build, since
# Latte keeps the derived one).
let
  static = import ../../../lib/desktop-profiles/static-profile.nix;
  theme = import ../../../lib/desktop-profiles/theme-builders.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;
  inherit (static) alpha;

  dark = {
    title = "Catppuccin Mocha";
    bg0 = "#1e1e2e";
    bg1 = "#181825";
    bg2 = "#313244";
    bg3 = "#45475a";
    bgDim = "#11111b";
    fg1 = "#cdd6f4";
    fg2 = "#bac2de";
    fg3 = "#a6adc8";
    fg4 = "#6c7086";
    accent = "#cba6f7";
    accent2 = "#f5c2e7";
    red = "#f38ba8";
    orange = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    aqua = "#94e2d5";
    blue = "#89b4fa";
    purple = "#cba6f7";
    onError = "#1e1e2e";
    pink = "#f5c2e7";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";
    surface2 = "#585b70";
    fishQuote = "#b4befe";
    fishRedirection = "#cba6f7";
    fishAutosuggestion = "#6c7086";
    starshipSuccess = "#f2cdcd";
    starshipDirectory = "#b4befe";
    rofiPlaceholder = "#45475a";
    barPrimary = "#f5c2e7";
    barCritical = "#f5c2e7";
    barBg = "rgba(24, 24, 37, 0.6)";
    barShadow = "rgba(17, 17, 27, 0.45)";
  };

  light = {
    title = "Catppuccin Latte";
    bg0 = "#eff1f5";
    bg1 = "#e6e9ef";
    bg2 = "#ccd0da";
    bg3 = "#bcc0cc";
    bgDim = "#dce0e8";
    fg1 = "#4c4f69";
    fg2 = "#5c5f77";
    fg3 = "#6c6f85";
    fg4 = "#9ca0b0";
    accent = "#8839ef";
    accent2 = "#ea76cb";
    red = "#d20f39";
    orange = "#fe640b";
    yellow = "#df8e1d";
    green = "#40a02b";
    aqua = "#179299";
    blue = "#1e66f5";
    purple = "#8839ef";
    onError = "#eff1f5";
    pink = "#ea76cb";
    overlay1 = "#8c8fa1";
    overlay2 = "#7c7f93";
    surface2 = "#acb0be";
    fishQuote = "#40a02b";
    fishRedirection = "#179299";
    fishAutosuggestion = "#8c8fa1";
    starshipSuccess = "#8839ef";
    starshipDirectory = "#1e66f5";
    rofiPlaceholder = "#acb0be";
    barPrimary = "#8839ef";
    barCritical = "#d20f39";
    barBg = "rgba(239, 241, 245, 0.85)";
    barShadow = "rgba(220, 224, 232, 0.6)";
  };

  overrides = {
    gtk = r: {
      cardBg = r.bg2;
      dialogBg = r.bg1;
      sidebarBorder = r.bg3;
      unfocused = {
        fg = r.fg3;
        text = r.overlay2;
        bg = r.bg0;
        base = r.bg0;
        selectedBg = r.bg3;
        selectedFg = r.bg0;
      };
    };
    qt6 = r: {
      midlight = r.overlay1;
      highlightedText = r.bg3;
      alternateBase = r.bg2;
      tooltipText = r.bg2;
      secondaryText = r.fg2;
      inactiveWindowText = r.fg1;
      inactiveButtonText = r.fg1;
      inactivePlaceholderText = r.fg1;
      disabledHighlight = r.surface2;
      disabledHighlightedText = r.bg3;
      disabledSecondaryText = r.overlay1;
    };
    kitty = r: {
      cursor = r.accent;
      color0 = r.bg3;
      color8 = r.surface2;
      color7 = r.fg2;
    };
    fish = r: {
      quote = r.fishQuote;
      redirection = r.fishRedirection;
      end = r.accent2;
      param = r.fg1;
      selection = r.bg3;
      searchMatch = r.bg2;
      operator = r.accent;
      escape = r.accent2;
      autosuggestion = r.fishAutosuggestion;
    };
    starship = r: {
      success = r.starshipSuccess;
      directory = r.starshipDirectory;
      cmdDuration = r.fg2;
    };
    rofi = r: {
      border = r.bg3;
      selectedBackground = r.bg2;
      placeholder = r.rofiPlaceholder;
      elementBackground = r.bg2;
      elementSelectedBackground = r.bg3;
    };
    btop = r: {
      selectedBg = r.bg3;
      procMisc = r.aqua;
      box = r.bg3;
    };
    tmux = r: {
      border = r.bg3;
    };
    waybarStyle = r: {
      primary = r.barPrimary;
      criticalColor = r.barCritical;
    };
  };

  built = static.mkStaticProfile {
    palette = dark;
    paletteLight = light;
    inherit overrides;
    bar = "quickshell";
    waybarStyle = "pill";
    scriptDir = "${config.repoPath}/home/scripts";
    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/catppuccin";

    quickshell = r: {
      fg = r.pink;
      bg = alpha "99" r.bg1;
      second = r.pink;
      barRadius = "22";
      barFont = "FiraCode Nerd Font";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      popupAnimationStyle = "softPop";
    };

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
      iconTheme = "Papirus-Dark";
      iconThemeLight = "Papirus-Dark";
    };

    niri = {
      animations = animations.glide;
      gaps = 8;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 28;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#11111b88";
      shadowInactiveColor = "#11111b44";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorInactiveColor = dark.bg3;
      windowOpacity = 0.97;
      windowHighlightOff = true;
    };
  };

  # Mocha-only monochrome pink/purple kitty scheme; Latte keeps the derived one.
  mochaKitty = theme.mkKittyColors {
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
in
{
  desktopProfiles.profiles.catppuccin = built // {
    colors = built.colors // {
      kitty = mochaKitty;
    };
  };
}
