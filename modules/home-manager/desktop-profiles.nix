{ pkgs, lib, config, ... }:

let
  profileType = lib.types.submodule {
    options = {
      bar = lib.mkOption {
        type = lib.types.enum [ "noctalia" "waybar" ];
        description = "Which bar to run for this profile.";
      };

      cursor = {
        theme = lib.mkOption { type = lib.types.str; default = "Adwaita"; };
        size  = lib.mkOption { type = lib.types.int; default = 28; };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Cursor theme package. null if already installed.";
        };
      };

      wallpaperDir = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to wallpaper directory.";
      };

      niri = {
        gaps                = lib.mkOption { type = lib.types.int;    default = 16; };
        borderOff           = lib.mkOption { type = lib.types.bool;   default = true; };
        borderWidth         = lib.mkOption { type = lib.types.int;    default = 1; };
        borderActiveColor   = lib.mkOption { type = lib.types.str;    default = "#b1c6ff"; };
        borderInactiveColor = lib.mkOption { type = lib.types.str;    default = "#121316"; };
        urgentColor         = lib.mkOption { type = lib.types.str;    default = "#ffb4ab"; };
        focusRingActiveColor   = lib.mkOption { type = lib.types.str; default = "#b1c6ff"; };
        focusRingInactiveColor = lib.mkOption { type = lib.types.str; default = "#121316"; };
        shadowSoftness      = lib.mkOption { type = lib.types.int;    default = 30; };
        shadowSpread        = lib.mkOption { type = lib.types.int;    default = 5; };
        shadowOffsetX       = lib.mkOption { type = lib.types.int;    default = 0; };
        shadowOffsetY       = lib.mkOption { type = lib.types.int;    default = 5; };
        shadowColor         = lib.mkOption { type = lib.types.str;    default = "#00000070"; };
        shadowInactiveColor = lib.mkOption { type = lib.types.str;    default = "#00000054"; };
        shadowDrawBehindWindow = lib.mkOption { type = lib.types.bool; default = true; };
        tabIndicatorOff     = lib.mkOption { type = lib.types.bool;   default = true; };
        tabIndicatorActiveColor   = lib.mkOption { type = lib.types.str; default = "#b1c6ff"; };
        tabIndicatorInactiveColor = lib.mkOption { type = lib.types.str; default = "#4c566a"; };
        windowOpacity       = lib.mkOption { type = lib.types.float;  default = 1.0; };
        windowHighlightOff  = lib.mkOption { type = lib.types.bool;   default = false; };
      };

      colors = {
        gtk3     = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        gtk4     = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        qt6      = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        kitty    = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        fish     = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        starship = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      };

      waybar = {
        config = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        style  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      };
    };
  };

  generateNiriOverrides = profile: ''
    cursor {
        xcursor-theme "${profile.cursor.theme}"
        xcursor-size ${toString profile.cursor.size}
    }

    layout {
        gaps ${toString profile.niri.gaps}

        focus-ring {
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
            on
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

    ${lib.optionalString profile.niri.windowHighlightOff "recent-windows { highlight { off } }"}
  '';

  orEmpty = v: if v != null then v else "";

  generateProfileFiles = name: profile:
    let
      base = {
        ".config/desktop-profiles/${name}/meta.json".text =
          builtins.toJSON {
            bar = profile.bar;
            cursor = profile.cursor.theme;
            cursorSize = profile.cursor.size;
          };
        ".config/desktop-profiles/${name}/wallpaper-dir".text = profile.wallpaperDir;
        ".config/desktop-profiles/${name}/gtk-3.0.css".text   = orEmpty profile.colors.gtk3;
        ".config/desktop-profiles/${name}/gtk-4.0.css".text   = orEmpty profile.colors.gtk4;
        ".config/desktop-profiles/${name}/qt6ct.conf".text    = orEmpty profile.colors.qt6;
        ".config/desktop-profiles/${name}/kitty-colors.conf".text  = orEmpty profile.colors.kitty;
        ".config/desktop-profiles/${name}/fish-theme.fish".text    = orEmpty profile.colors.fish;
        ".config/desktop-profiles/${name}/starship.toml".text      = orEmpty profile.colors.starship;
        ".config/desktop-profiles/${name}/niri-overrides.kdl".text = generateNiriOverrides profile;
      };
      waybarFiles = lib.optionalAttrs
        (profile.bar == "waybar" && profile.waybar.config != null) {
          ".config/desktop-profiles/${name}/waybar-config.jsonc".text = profile.waybar.config;
          ".config/desktop-profiles/${name}/waybar-style.css".text    = orEmpty profile.waybar.style;
        };
    in base // waybarFiles;

in {
  options.desktopProfiles = {
    enable = lib.mkEnableOption "desktop profile system";
    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "noctalia";
      description = "Profile to activate on first home-manager switch if none is set.";
    };
    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = {};
    };
  };

  config = lib.mkIf config.desktopProfiles.enable {

    home.packages = lib.flatten (
      lib.mapAttrsToList (_name: profile:
        lib.optional (profile.cursor.package != null) profile.cursor.package
      ) config.desktopProfiles.profiles
    );

    home.file = lib.mkMerge (
      lib.mapAttrsToList generateProfileFiles config.desktopProfiles.profiles
    );

    # Bootstrap: create the active symlink on first activation if not set.
    home.activation.initDesktopProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PROFILES_DIR="$HOME/.config/desktop-profiles"
      ACTIVE_LINK="$PROFILES_DIR/active-niri-overrides.kdl"
      ACTIVE_FILE="$PROFILES_DIR/active"
      DEFAULT="${config.desktopProfiles.defaultProfile}"

      if [ ! -e "$ACTIVE_LINK" ]; then
        $DRY_RUN_CMD ln -s "$PROFILES_DIR/$DEFAULT/niri-overrides.kdl" "$ACTIVE_LINK"
      fi
      if [ ! -e "$ACTIVE_FILE" ]; then
        echo "$DEFAULT" | $DRY_RUN_CMD tee "$ACTIVE_FILE" > /dev/null
      fi
    '';
  };
}
