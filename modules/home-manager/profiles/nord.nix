{ pkgs, config, ... }:

# Nord (dark only) on the static-profile default mapping. The nordN bindings
# stay so overrides can reference the few tones that fall outside the canonical
# roles (nord5 bright text, nord10 deep frost, the hyprlock surface/muted).
let
  static = import ../../../lib/desktop-profiles/static-profile.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;
  inherit (static) alpha;

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

  palette = {
    title = "Nord";
    bg0 = nord0;
    bg1 = nord1;
    bg2 = nord2;
    bg3 = nord3;
    fg0 = nord6;
    fg1 = nord4;
    fg2 = nord4;
    fg3 = nord3;
    fg4 = nord3;
    accent = nord8;
    accent2 = nord9;
    red = nord11;
    orange = nord12;
    yellow = nord13;
    green = nord14;
    aqua = nord7;
    blue = nord9;
    purple = nord15;
    barBg = "rgba(46, 52, 64, 0.6)";
    barShadow = "rgba(36, 41, 51, 0.45)";
  };

  overrides = {
    gtk = _: {
      sidebarBorder = "@window_bg_color";
      unfocused = {
        fg = "@window_fg_color";
        text = "@view_fg_color";
        bg = "@window_bg_color";
        base = "@window_bg_color";
        selectedBg = "@accent_bg_color";
        selectedFg = "@accent_fg_color";
      };
    };
    qt6 = r: {
      highlight = nord10;
      highlightedText = r.fg0;
      link = r.accent2;
      linkVisited = r.accent;
      alternateBase = r.bg3;
      tooltipText = r.bg3;
      secondaryText = r.fg1;
      inherit (r) accent;
      disabledHighlight = nord10;
      disabledLink = r.accent2;
      disabledAccent = r.accent;
      disabledHighlightedText = r.fg0;
    };
    kitty = r: {
      color7 = nord5;
      color15 = r.fg0;
      title = "Nord Kitty Theme";
    };
    fish = r: {
      redirection = r.fg1;
      searchMatch = r.bg2;
      operator = r.accent;
      escape = r.yellow;
    };
    starship = _: {
      gitBranch = nord10;
    };
    rofi = r: {
      border = r.bg3;
    };
    btop = r: {
      procMisc = r.aqua;
    };
    tmux = r: {
      secondary = r.accent2;
    };
    hyprlock = r: {
      muted = "#aeb7c5";
      surface = "#171b22";
      surfaceAlt = r.bg0;
    };
    mako = _: {
      font = "Iosevka Nerd Font 11";
      borderSize = 1;
      borderRadius = 0;
      padding = 10;
      margin = 6;
    };
    waybarStyle = r: {
      hoverColor = r.aqua;
      clockColor = r.fg1;
    };
  };
in
{
  desktopProfiles.profiles.nord = static.mkStaticProfile {
    inherit palette overrides;
    bar = "quickshell";
    waybarStyle = "floating";
    scriptDir = "${config.repoPath}/home/scripts";
    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/nord";

    quickshell = r: {
      bg = alpha "ee" r.bg0;
      popupBg = alpha "ee" r.bg0;
      second = r.accent2;
      barRadius = "0";
      barHeight = "26";
      barMargin = "0";
      showWorkspaceNumbers = "true";
      barInnerHighlight = "#00000000";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      flatMode = "true";
      dividerColor = r.bg3;
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

    niri = {
      animations = animations.snappy;
      gaps = 6;
      borderOff = false;
      borderWidth = 1;
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
  };
}
