{ pkgs, config, ... }:

# Rosé Pine (Main dark, Dawn light) on the static-profile default mapping.
# `highlightMed` is an extra palette key (the inactive-tab / selection tone
# that sits between bg2 and bg3); everything Rosé Pine does differently from
# the canonical role mapping lives in `overrides`.
let
  static = import ../../../lib/desktop-profiles/static-profile.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;
  inherit (static) alpha;

  dark = {
    title = "Rosé Pine";
    bg0 = "#191724";
    bg1 = "#1f1d2e";
    bg2 = "#26233a";
    bg3 = "#524f67";
    bgDim = "#21202e";
    fg1 = "#e0def4";
    fg2 = "#908caa";
    fg3 = "#6e6a86";
    fg4 = "#6e6a86";
    accent = "#c4a7e7";
    accent2 = "#ebbcba";
    red = "#eb6f92";
    orange = "#f6c177";
    yellow = "#f6c177";
    green = "#31748f";
    aqua = "#9ccfd8";
    blue = "#31748f";
    purple = "#c4a7e7";
    onError = "#191724";
    gradLow = "#9ccfd8";
    highlightMed = "#403d52";
    barBg = "rgba(25, 23, 36, 0.6)";
    barShadow = "rgba(16, 14, 24, 0.45)";
  };

  light = {
    title = "Rosé Pine Dawn";
    bg0 = "#faf4ed";
    bg1 = "#fffaf3";
    bg2 = "#f2e9e1";
    bg3 = "#cecacd";
    bgDim = "#f4ede8";
    fg1 = "#575279";
    fg2 = "#797593";
    fg3 = "#9893a5";
    fg4 = "#9893a5";
    accent = "#907aa9";
    accent2 = "#d7827e";
    red = "#b4637a";
    orange = "#ea9d34";
    yellow = "#ea9d34";
    green = "#286983";
    aqua = "#56949f";
    blue = "#286983";
    purple = "#907aa9";
    onError = "#faf4ed";
    gradLow = "#56949f";
    highlightMed = "#dfdad9";
    barBg = "rgba(250, 244, 237, 0.85)";
    barShadow = "rgba(223, 218, 217, 0.5)";
  };

  overrides = {
    gtk = r: {
      cardBg = r.bg2;
      dialogBg = r.bg1;
      sidebarBorder = r.highlightMed;
      unfocused = {
        fg = r.fg2;
        text = r.fg3;
        bg = r.bg0;
        base = r.bg0;
        selectedBg = r.highlightMed;
        selectedFg = r.fg1;
      };
    };
    qt6 = r: {
      highlightedText = r.highlightMed;
      alternateBase = r.bg2;
      tooltipText = r.bg2;
      secondaryText = r.fg2;
      inactiveSecondaryText = r.fg4;
      disabledHighlightedText = r.highlightMed;
    };
    kitty = r: {
      cursor = r.accent2;
      color0 = r.highlightMed;
      color10 = r.aqua;
      color7 = r.fg2;
    };
    fish = r: {
      keyword = r.red;
      quote = r.yellow;
      end = r.fg2;
      param = r.fg1;
      selection = r.highlightMed;
      searchMatch = r.bg2;
      operator = r.accent;
      escape = r.accent2;
    };
    starship = r: {
      directory = r.aqua;
      cmdDuration = r.fg2;
    };
    rofi = r: {
      border = r.highlightMed;
      selectedBackground = r.bg2;
    };
    btop = r: {
      selectedBg = r.highlightMed;
      procMisc = r.aqua;
      box = r.highlightMed;
    };
    tmux = r: {
      border = r.highlightMed;
    };
    hyprlock = r: {
      muted = r.fg2;
      surface = r.bg0;
    };
    waybarStyle = r: {
      borderColor = r.highlightMed;
      hoverColor = r.accent2;
      clockColor = r.accent2;
    };
  };
in
{
  desktopProfiles.profiles.rosepine = static.mkStaticProfile {
    palette = dark;
    paletteLight = light;
    inherit overrides;
    bar = "quickshell";
    waybarStyle = "pill";
    scriptDir = "${config.repoPath}/home/scripts";
    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/rosepine";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/rosepine-light";

    quickshell = r: {
      fg = r.bg0;
      bg = alpha "dd" r.accent;
      popupBg = alpha "cc" r.bg0;
      rawBg = r.bg0;
      accent = r.bg0;
      second = r.bg1;
      warm = r.yellow;
      fresh = r.aqua;
      barRadius = "22";
      barFont = "FiraCode Nerd Font";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      popupAnimationStyle = "unfold";
    };

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

    niri = {
      animations = animations.soft;
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
      tabIndicatorInactiveColor = dark.highlightMed;
      windowOpacity = 0.97;
      windowHighlightOff = true;
    };
  };
}
