{ pkgs, config, ... }:

# Everforest Hard (dark + light) on the static-profile default mapping.
# `bg5` (bright terminal black) and `makoLow` (low-urgency notification
# border) are extra palette keys outside the canonical roles.
let
  static = import ../../../lib/desktop-profiles/static-profile.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;

  dark = {
    title = "Everforest Dark Hard";
    bg0 = "#272e33";
    bg1 = "#2e383c";
    bg2 = "#374145";
    bg3 = "#414b50";
    fg1 = "#d3c6aa";
    fg2 = "#9da9a0";
    fg3 = "#859289";
    fg4 = "#7a8478";
    accent = "#a7c080";
    accent2 = "#83c092";
    red = "#e67e80";
    orange = "#e69875";
    yellow = "#dbbc7f";
    green = "#a7c080";
    aqua = "#83c092";
    blue = "#7fbbb3";
    purple = "#d699b6";
    bg5 = "#4f5b58";
    makoLow = "#495156";
    barBg = "rgba(39, 46, 51, 0.6)";
    barShadow = "rgba(20, 24, 27, 0.45)";
  };

  light = {
    title = "Everforest Light Hard";
    bg0 = "#fff9e8";
    bg1 = "#f4f0d9";
    bg2 = "#efebd4";
    bg3 = "#e6e2cc";
    fg1 = "#5c6a72";
    fg2 = "#829181";
    fg3 = "#939f91";
    fg4 = "#a6b0a0";
    accent = "#8da101";
    accent2 = "#35a77c";
    red = "#f85552";
    orange = "#f57d26";
    yellow = "#dfa000";
    green = "#8da101";
    aqua = "#35a77c";
    blue = "#3a94c5";
    purple = "#df69ba";
    bg5 = "#bec5b2";
    makoLow = "#e6e2cc";
    barBg = "rgba(255, 249, 232, 0.85)";
    barShadow = "rgba(190, 197, 178, 0.45)";
  };

  overrides = {
    gtk = r: {
      unfocused = {
        fg = r.fg2;
        text = r.fg3;
        bg = r.bg0;
        base = r.bg0;
        selectedBg = r.bg2;
        selectedFg = r.fg1;
      };
    };
    qt6 = r: {
      secondaryText = r.fg3;
      disabledText = r.fg3;
    };
    kitty = r: {
      color0 = r.bg3;
      color8 = r.bg5;
      color7 = r.fg2;
    };
    fish = r: {
      quote = r.yellow;
      redirection = r.blue;
      end = r.fg3;
      param = r.fg1;
      escape = r.orange;
    };
    starship = r: {
      directory = r.aqua;
      gitBranch = r.yellow;
      cmdDuration = r.fg3;
    };
    btop = r: {
      inactiveFg = r.fg3;
      procMisc = r.aqua;
    };
    tmux = r: {
      inactive = r.fg3;
    };
    mako = r: {
      lowBorder = r.makoLow;
    };
    waybarStyle = r: {
      hoverColor = r.yellow;
      clockColor = r.yellow;
      powerSaverColor = r.aqua;
    };
  };
in
{
  desktopProfiles.profiles.everforest = static.mkStaticProfile {
    palette = dark;
    paletteLight = light;
    inherit overrides;
    bar = "quickshell";
    waybarStyle = "floating";
    scriptDir = "${config.repoPath}/home/scripts";
    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/everforest";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/everforest-light";

    quickshell = r: {
      fresh = r.blue;
      pillBg = "#00000000";
      pillBorder = "#00000000";
      barHeight = "30";
      barMarginTop = "7";
      exclusiveZoneOffset = "-3";
    };

    cursor = {
      theme = "Bibata-Modern-Classic";
      size = 24;
      package = pkgs.bibata-cursors;
    };

    fonts = {
      ui = {
        family = "Noto Sans";
        size = 11;
      };
      mono = {
        family = "Hack Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = "adw-gtk3";
      iconTheme = "Tela-green-dark";
      iconThemeLight = "Tela-green-light";
    };

    niri = {
      animations = animations.glide;
      gaps = 8;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 24;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 6;
      shadowColor = "#0f161380";
      shadowInactiveColor = "#0f161340";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      tabIndicatorInactiveColor = dark.bg3;
      windowOpacity = 0.96;
      windowHighlightOff = true;
    };
  };
}
