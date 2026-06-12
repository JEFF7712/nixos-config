{
  lib,
  runtimeDefaults,
}:

let
  generateNiriOverrides = profile: ''
    cursor {
        xcursor-theme "${profile.cursor.theme}"
        xcursor-size ${toString profile.cursor.size}
    }

    layout {
        gaps ${toString profile.niri.gaps}

        focus-ring {
            ${if profile.niri.focusRingOff then "off" else ""}
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
            ${if profile.niri.shadowOff then "off" else "on"}
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

    ${lib.optionalString profile.niri.windowHighlightOff ''
      recent-windows {
          highlight {
              active-color "#00000000"
              urgent-color "#00000000"
          }
      }
    ''}

    ${profile.niri.extraConfig}
  '';

  orEmpty = v: if v != null then v else "";

  hasLight = profile: profile.colorsLight.kitty != null || profile.colorsLight.gtk3 != null;

  runtimeFor = name: profile: lib.recursiveUpdate (runtimeDefaults.${name} or { }) profile.runtime;

  generateProfileFiles =
    name: profile:
    let
      base = {
        ".config/desktop-profiles/${name}/meta.json".text = builtins.toJSON {
          inherit (profile) bar selfThemed;
          cursor = profile.cursor.theme;
          cursorSize = profile.cursor.size;
          inherit (profile) fonts;
          inherit (profile) appearance;
          hasLightVariant = hasLight profile;
        };
        ".config/desktop-profiles/${name}/runtime.json".text = builtins.toJSON (runtimeFor name profile);
        ".config/desktop-profiles/${name}/wallpaper-dir".text = profile.wallpaperDir;
        ".config/desktop-profiles/${name}/wallpaper-dir-light".text =
          if profile.wallpaperDirLight != null then profile.wallpaperDirLight else profile.wallpaperDir;
        ".config/desktop-profiles/${name}/gtk-3.0.css".text = orEmpty profile.colors.gtk3;
        ".config/desktop-profiles/${name}/gtk-4.0.css".text = orEmpty profile.colors.gtk4;
        ".config/desktop-profiles/${name}/qt6ct.conf".text = orEmpty profile.colors.qt6;
        ".config/desktop-profiles/${name}/kitty-colors.conf".text = orEmpty profile.colors.kitty;
        ".config/desktop-profiles/${name}/fish-theme.fish".text = orEmpty profile.colors.fish;
        ".config/desktop-profiles/${name}/starship.toml".text = orEmpty profile.colors.starship;
        ".config/desktop-profiles/${name}/rofi-theme.rasi".text = orEmpty profile.colors.rofi;
        ".config/desktop-profiles/${name}/btop.theme".text = orEmpty profile.colors.btop;
        ".config/desktop-profiles/${name}/tmux-colors.conf".text = orEmpty profile.colors.tmux;
        ".config/desktop-profiles/${name}/hyprlock-colors.conf".text = orEmpty profile.colors.hyprlock;
        ".config/desktop-profiles/${name}/cava-colors".text = orEmpty profile.colors.cava;
        ".config/desktop-profiles/${name}/niri-overrides.kdl".text = generateNiriOverrides profile;
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
          ".config/desktop-profiles/${name}/starship-light.toml".text = orEmpty profile.colorsLight.starship;
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
    generateProfileFiles
    hasLight
    runtimeFor
    ;
}
