{
  lib,
  runtimeDefaults,
}:

let
  renderNiriAnimation =
    name: animation:
    let
      body =
        if animation.spring != null then
          [
            "        spring damping-ratio=${toString animation.spring.dampingRatio} stiffness=${toString animation.spring.stiffness} epsilon=${toString animation.spring.epsilon}"
          ]
        else
          [
            "        duration-ms ${toString animation.durationMs}"
            "        curve \"${animation.curve}\""
          ];
    in
    lib.concatStringsSep "\n" (
      [
        "    ${name} {"
      ]
      ++ body
      ++ [
        "    }"
      ]
    );

  renderNiriAnimations =
    animations:
    lib.concatStringsSep "\n" (
      [
        "animations {"
      ]
      ++ map (name: renderNiriAnimation name animations.${name}) (builtins.attrNames animations)
      ++ [
        "}"
      ]
    );

  generateNiriOverrides = focus: profile: ''
    cursor {
        xcursor-theme "${profile.cursor.theme}"
        xcursor-size ${toString profile.cursor.size}
    }

    ${
      if focus then
        ''
          animations {
              off
          }''
      else
        renderNiriAnimations profile.niri.animations
    }

    layout {
        gaps ${toString profile.niri.gaps}

        focus-ring {
            ${if profile.niri.focusRingOff then "off" else ""}
            width ${toString profile.niri.focusRingWidth}
            active-color "${profile.niri.focusRingActiveColor}"
            inactive-color "${profile.niri.focusRingInactiveColor}"
            urgent-color "${profile.niri.urgentColor}"
        }

        border {
            ${if profile.niri.borderOff then "off" else ""}
            width ${toString profile.niri.borderWidth}
            active-color "${profile.niri.borderActiveColor}"
            inactive-color "${profile.niri.borderInactiveColor}"
            urgent-color "${profile.niri.urgentColor}"
        }

        shadow {
            ${if (focus || profile.niri.shadowOff) then "off" else "on"}
            softness ${toString profile.niri.shadowSoftness}
            spread ${toString profile.niri.shadowSpread}
            offset x=${toString profile.niri.shadowOffsetX} y=${toString profile.niri.shadowOffsetY}
            ${if profile.niri.shadowDrawBehindWindow then "draw-behind-window true" else ""}
            color "${profile.niri.shadowColor}"
            inactive-color "${profile.niri.shadowInactiveColor}"
        }

        tab-indicator {
            ${if profile.niri.tabIndicatorOff then "off" else ""}
            hide-when-single-tab
            place-within-column
            gap 5
            width 4
            length total-proportion=1.0
            position "right"
            gaps-between-tabs 2
            corner-radius 8
            active-color "${profile.niri.tabIndicatorActiveColor}"
            inactive-color "${profile.niri.tabIndicatorInactiveColor}"
            urgent-color "${profile.niri.urgentColor}"
        }
    }

    window-rule {
        opacity ${toString profile.niri.windowOpacity}
    }

    ${lib.optionalString (!focus && profile.niri.focusOpacity) ''
      window-rule {
          match is-active=true
          opacity 0.8
      }
      window-rule {
          match is-active=false
          opacity 0.6
      }
    ''}

    window-rule {
        geometry-corner-radius 10
        clip-to-geometry true
        background-effect {
            blur ${if (focus || !profile.niri.blur) then "false" else "true"}
        }
    }

    ${lib.optionalString profile.niri.windowHighlightOff ''
      recent-windows {
          highlight {
              active-color "#00000000"
              urgent-color "#00000000"
          }
      }
    ''}

    ${profile.niri.extraConfig}

    ${lib.optionalString focus ''
      window-rule {
          opacity 1.0
      }
    ''}
  '';

  orEmpty = v: if v != null then v else "";

  hasLight = profile: profile.colorsLight.kitty != null || profile.colorsLight.gtk3 != null;

  runtimeFor = name: profile: lib.recursiveUpdate (runtimeDefaults.${name} or { }) profile.runtime;

  stripAlpha =
    color:
    if
      builtins.isString color && builtins.stringLength color == 9 && builtins.substring 0 1 color == "#"
    then
      "#" + builtins.substring 3 6 color
    else
      color;

  colorFrom =
    theme: key: fallback:
    stripAlpha (theme.${key} or fallback);

  vicinaeTheme =
    name: variant: theme:
    let
      rawBg = colorFrom theme "rawBg" (colorFrom theme "bg" "#101010");
      popupBg = colorFrom theme "popupBg" rawBg;
      fg = colorFrom theme "fg" "#ffffff";
      secondary = colorFrom theme "second" fg;
      accent = colorFrom theme "accent" fg;
      warm = colorFrom theme "warm" accent;
      fresh = colorFrom theme "fresh" accent;
      red = colorFrom theme "red" "#ff6b6b";
    in
    ''
      [meta]
      version = 1
      name = "${name} ${variant}"
      description = "Generated from the active desktop profile"
      variant = "${variant}"
      inherits = "vicinae-${variant}"

      [colors.core]
      background = "${rawBg}"
      foreground = "${fg}"
      secondary_background = "${popupBg}"
      border = "${secondary}"
      accent = "${accent}"

      [colors.accents]
      blue = "${accent}"
      green = "${fresh}"
      magenta = "${warm}"
      orange = "${warm}"
      purple = "${accent}"
      red = "${red}"
      yellow = "${warm}"
      cyan = "${fresh}"

      [colors.text]
      default = "${fg}"
      muted = "${secondary}"
      placeholder = "${secondary}"
      danger = "${red}"
      success = "${fresh}"

      [colors.list.item.selection]
      background = "${popupBg}"
      foreground = "${fg}"
      secondary_background = "${rawBg}"
      secondary_foreground = "${secondary}"

      [colors.list.item.hover]
      background = "${popupBg}"
      foreground = "${fg}"
      secondary_foreground = "${secondary}"

      [colors.input]
      border = "${secondary}"
      border_focus = "${accent}"

      [colors.loading]
      bar = "${accent}"
      spinner = "${accent}"
    '';

  vicinaeDarkTheme =
    name: profile:
    vicinaeTheme name "dark" (
      profile.quickshellTheme or {
        rawBg = "#101010";
        popupBg = "#202020";
        fg = "#ffffff";
        second = "#d0d0d0";
        accent = "#ffffff";
        warm = "#e6dcc6";
        fresh = "#d6eadc";
      }
    );

  vicinaeLightTheme =
    name: profile:
    vicinaeTheme name "light" (
      profile.quickshellThemeLight or profile.quickshellTheme or {
        rawBg = "#f7f7f7";
        popupBg = "#ffffff";
        fg = "#101010";
        second = "#404040";
        accent = "#101010";
        warm = "#6f5d32";
        fresh = "#336b4f";
      }
    );

  renderProfileFiles =
    name: profile:
    let
      base = {
        ".config/desktop-profiles/${name}/gtk-3.0.css".text = orEmpty profile.colors.gtk3;
        ".config/desktop-profiles/${name}/gtk-4.0.css".text = orEmpty profile.colors.gtk4;
        ".config/desktop-profiles/${name}/qt6ct.conf".text = orEmpty profile.colors.qt6;
        ".config/desktop-profiles/${name}/kitty-colors.conf".text = orEmpty profile.colors.kitty;
        ".config/desktop-profiles/${name}/fish-theme.fish".text = orEmpty profile.colors.fish;
        ".config/desktop-profiles/${name}/starship.toml".text = ''
          scan_timeout = 100
          ${orEmpty profile.colors.starship}
        '';
        ".config/desktop-profiles/${name}/rofi-theme.rasi".text = orEmpty profile.colors.rofi;
        ".config/desktop-profiles/${name}/btop.theme".text = orEmpty profile.colors.btop;
        ".config/desktop-profiles/${name}/tmux-colors.conf".text = orEmpty profile.colors.tmux;
        ".config/desktop-profiles/${name}/hyprlock-colors.conf".text = orEmpty profile.colors.hyprlock;
        ".config/desktop-profiles/${name}/cava-colors".text = orEmpty profile.colors.cava;
        ".config/desktop-profiles/${name}/vicinae-theme-dark.toml".text = vicinaeDarkTheme name profile;
        ".config/desktop-profiles/${name}/vicinae-theme-light.toml".text = vicinaeLightTheme name profile;
        ".config/desktop-profiles/${name}/niri-overrides.kdl".text = generateNiriOverrides false profile;
        ".config/desktop-profiles/${name}/niri-overrides-focus.kdl".text =
          generateNiriOverrides true profile;
      }
      // lib.optionalAttrs (profile.makoConfig != null) {
        ".config/desktop-profiles/${name}/mako-config".text = profile.makoConfig;
      };

      lightFiles =
        lib.optionalAttrs (hasLight profile) {
          ".config/desktop-profiles/${name}/gtk-3.0-light.css".text = orEmpty profile.colorsLight.gtk3;
          ".config/desktop-profiles/${name}/gtk-4.0-light.css".text = orEmpty profile.colorsLight.gtk4;
          ".config/desktop-profiles/${name}/qt6ct-light.conf".text = orEmpty profile.colorsLight.qt6;
          ".config/desktop-profiles/${name}/kitty-colors-light.conf".text = orEmpty profile.colorsLight.kitty;
          ".config/desktop-profiles/${name}/fish-theme-light.fish".text = orEmpty profile.colorsLight.fish;
          ".config/desktop-profiles/${name}/starship-light.toml".text = ''
            scan_timeout = 100
            ${orEmpty profile.colorsLight.starship}
          '';
          ".config/desktop-profiles/${name}/rofi-theme-light.rasi".text = orEmpty profile.colorsLight.rofi;
          ".config/desktop-profiles/${name}/btop-light.theme".text = orEmpty profile.colorsLight.btop;
          ".config/desktop-profiles/${name}/tmux-colors-light.conf".text = orEmpty profile.colorsLight.tmux;
          ".config/desktop-profiles/${name}/hyprlock-colors-light.conf".text =
            orEmpty profile.colorsLight.hyprlock;
          ".config/desktop-profiles/${name}/cava-colors-light".text = orEmpty profile.colorsLight.cava;
        }
        // lib.optionalAttrs (profile.makoConfigLight != null) {
          ".config/desktop-profiles/${name}/mako-config-light".text = profile.makoConfigLight;
        };

      # Materialized regardless of the active bar choice so switching a
      # profile's bar is a one-line change with no stale or missing files.
      waybarFiles = lib.optionalAttrs (profile.waybar.config != null) (
        {
          ".config/desktop-profiles/${name}/waybar-config.jsonc".text = profile.waybar.config;
          ".config/desktop-profiles/${name}/waybar-style.css".text = orEmpty profile.waybar.style;
        }
        // lib.optionalAttrs (profile.waybarLight.style != null) {
          ".config/desktop-profiles/${name}/waybar-style-light.css".text = profile.waybarLight.style;
        }
      );

      quickshellFiles =
        lib.optionalAttrs (profile.quickshellTheme != null) {
          ".config/desktop-profiles/${name}/quickshell-theme.json".text =
            builtins.toJSON profile.quickshellTheme;
        }
        // lib.optionalAttrs (profile.quickshellThemeLight != null) {
          ".config/desktop-profiles/${name}/quickshell-theme-light.json".text =
            builtins.toJSON profile.quickshellThemeLight;
        };
    in
    base // lightFiles // waybarFiles // quickshellFiles;
in
{
  inherit
    generateNiriOverrides
    hasLight
    renderProfileFiles
    runtimeFor
    ;
}
