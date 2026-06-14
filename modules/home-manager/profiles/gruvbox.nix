{ pkgs, config, ... }:

# Gruvbox Hard, built on the static-profile default mapping. The palette is
# the only theme-specific content; `comment` carries the bg4 tone the fish
# theme uses, and the quickshell bar deviates from the mono font on purpose.
let
  static = import ../../../lib/desktop-profiles/static-profile.nix;

  dark = rec {
    title = "Gruvbox Dark";
    bgDim = "#1d2021";
    bg0 = "#282828";
    bg1 = "#3c3836";
    bg2 = "#504945";
    bg3 = "#665c54";
    fg0 = "#fbf1c7";
    fg1 = "#ebdbb2";
    fg2 = "#d5c4a1";
    fg3 = "#bdae93";
    fg4 = "#a89984";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    purple = "#d3869b";
    aqua = "#8ec07c";
    orange = "#fe8019";
    gray = "#928374";
    accent = yellow;
    accent2 = orange;
    comment = "#7c6f64";
    onAccent = "#282828";
    onError = "#fbf1c7";
    barBg = "rgba(40, 40, 40, 0.6)";
    barShadow = "rgba(29, 32, 33, 0.45)";
  };

  light = rec {
    title = "Gruvbox Light Hard";
    bgDim = "#f9f5d7";
    bg0 = "#fbf1c7";
    bg1 = "#ebdbb2";
    bg2 = "#d5c4a1";
    bg3 = "#bdae93";
    fg0 = "#282828";
    fg1 = "#3c3836";
    fg2 = "#504945";
    fg3 = "#665c54";
    fg4 = "#7c6f64";
    red = "#9d0006";
    green = "#79740e";
    yellow = "#b57614";
    blue = "#076678";
    purple = "#8f3f71";
    aqua = "#427b58";
    orange = "#af3a03";
    gray = "#928374";
    accent = yellow;
    accent2 = orange;
    comment = "#a89984";
    onAccent = "#282828";
    onError = "#fbf1c7";
    barBg = "rgba(251, 241, 199, 0.85)";
    barShadow = "rgba(189, 174, 147, 0.45)";
  };
in
{
  desktopProfiles.profiles.gruvbox = static.mkStaticProfile {
    palette = dark;
    paletteLight = light;
    scriptDir = "${config.repoPath}/home/scripts";
    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/gruvbox";
    wallpaperDirLight = "${config.repoPath}/home/assets/wallpapers/gruvbox-light";

    cursor = {
      theme = "Capitaine Cursors (Gruvbox)";
      size = 24;
      package = pkgs.capitaine-cursors-themed;
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
      iconTheme = "Tela-yellow-dark";
      iconThemeLight = "Tela-yellow-light";
    };

    niri = {
      gaps = 6;
      borderOff = false;
      borderWidth = 2;
      focusRingOff = true;
      shadowSoftness = 0;
      shadowSpread = 0;
      shadowOffsetX = 5;
      shadowOffsetY = 5;
      shadowColor = "#1d2021";
      shadowInactiveColor = "#1d2021";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = false;
      windowOpacity = 0.96;
      windowHighlightOff = true;
      extraConfig = ''
        window-rule {
            geometry-corner-radius 0
            clip-to-geometry true
        }

        layer-rule {
            match namespace="^quickshell-clean-topbar$"
            geometry-corner-radius 0
        }

        layer-rule {
            match namespace="^quickshell-clean-popup$"
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
      '';
    };

    quickshell = p: {
      barFont = "Hack Nerd Font";
      bg = "#ee282828";
      popupBg = "#ee282828";
      barRadius = "0";
      barHeight = "30";
      barMargin = "0";
      showWorkspaceNumbers = "true";
      barBorder = "#00000000";
      barInnerHighlight = "#00000000";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      flatMode = "true";
      dividerColor = p.bg3;
    };

    overrides = {
      rofi = p: {
        border = p.accent;
        selectedBackground = p.bg2;
        elementSelectedBorder = p.accent2;
        borderWidth = 2;
        selectedBorderWidth = 2;
        windowRadius = 0;
        inputRadius = 0;
        elementRadius = 0;
        iconRadius = 0;
      };

      mako = p: {
        border = p.accent;
        lowBorder = p.bg3;
        highBorder = p.orange;
        borderSize = 2;
        borderRadius = 0;
        padding = 10;
        margin = 6;
      };
    };
  };
}
