{ lib }:

let
  animationType = lib.types.submodule {
    options = {
      spring = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              dampingRatio = lib.mkOption { type = lib.types.float; };
              stiffness = lib.mkOption { type = lib.types.int; };
              epsilon = lib.mkOption { type = lib.types.float; };
            };
          }
        );
        default = null;
      };
      durationMs = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      curve = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };

  animationShapeValid =
    animation:
    (animation.spring != null && animation.durationMs == null && animation.curve == null)
    || (animation.spring == null && animation.durationMs != null && animation.curve != null);

  defaultNiriAnimations = (import ./niri-animations.nix).default;

  colorOptions = {
    gtk3 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    gtk4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    qt6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    kitty = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    fish = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    starship = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    rofi = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    btop = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    tmux = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    hyprlock = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    cava = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };
in
{
  inherit colorOptions;

  profileType = lib.types.submodule {
    options = {
      bar = lib.mkOption {
        type = lib.types.enum [
          "clean"
          "noctalia"
          "quickshell"
          "waybar"
        ];
        description = "Which bar to run for this profile.";
      };

      selfThemed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          The profile's shell manages its own colors and wallpaper at runtime
          (noctalia). Switching scripts skip color-file copies, wallpaper
          setting, and kitty reload for self-themed profiles.
        '';
      };

      quickshellTheme = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = ''
          Theme tokens for the modular quickshell bar (colors plus style keys
          like barRadius, barHeight, exclusiveZoneOffset, flatMode — see
          shell.qml's applyTheme).
          Materialized as
          ~/.config/desktop-profiles/<profile>/quickshell-theme.json and
          loaded at runtime by shell.qml.
        '';
      };

      quickshellThemeLight = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = ''
          Light-variant theme tokens for the quickshell bar. Materialized as
          quickshell-theme-light.json and picked up by shell.qml when
          active-variant is light.
        '';
      };

      cursor = {
        theme = lib.mkOption {
          type = lib.types.str;
          default = "Adwaita";
        };
        size = lib.mkOption {
          type = lib.types.int;
          default = 28;
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Cursor theme package. null if already installed.";
        };
      };

      fonts = {
        ui = {
          family = lib.mkOption {
            type = lib.types.str;
            default = "JetBrainsMono Nerd Font";
          };
          size = lib.mkOption {
            type = lib.types.int;
            default = 11;
          };
        };
        mono = {
          family = lib.mkOption {
            type = lib.types.str;
            default = "JetBrainsMono Nerd Font";
          };
          size = lib.mkOption {
            type = lib.types.int;
            default = 14;
          };
        };
      };

      appearance = {
        gtkTheme = lib.mkOption {
          type = lib.types.str;
          default = "adw-gtk3-dark";
        };
        gtkThemeLight = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "adw-gtk3";
        };
        iconTheme = lib.mkOption {
          type = lib.types.str;
          default = "Papirus-Dark";
        };
        iconThemeLight = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "Papirus-Light";
        };
        kittyOpacity = lib.mkOption {
          type = lib.types.float;
          default = 1.0;
        };
      };

      wallpaperDir = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to wallpaper directory.";
      };

      wallpaperDirLight = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Wallpaper directory for the light variant. Falls back to wallpaperDir if null.";
      };

      niri = {
        gaps = lib.mkOption {
          type = lib.types.int;
          default = 16;
        };
        borderOff = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        borderWidth = lib.mkOption {
          type = lib.types.int;
          default = 1;
        };
        borderActiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#b1c6ff";
        };
        borderInactiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#121316";
        };
        urgentColor = lib.mkOption {
          type = lib.types.str;
          default = "#ffb4ab";
        };
        focusRingOff = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        focusRingActiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#b1c6ff";
        };
        focusRingInactiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#121316";
        };
        shadowSoftness = lib.mkOption {
          type = lib.types.int;
          default = 30;
        };
        shadowOff = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        shadowSpread = lib.mkOption {
          type = lib.types.int;
          default = 5;
        };
        shadowOffsetX = lib.mkOption {
          type = lib.types.int;
          default = 0;
        };
        shadowOffsetY = lib.mkOption {
          type = lib.types.int;
          default = 5;
        };
        shadowColor = lib.mkOption {
          type = lib.types.str;
          default = "#00000070";
        };
        shadowInactiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#00000054";
        };
        shadowDrawBehindWindow = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        tabIndicatorOff = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        tabIndicatorActiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#b1c6ff";
        };
        tabIndicatorInactiveColor = lib.mkOption {
          type = lib.types.str;
          default = "#4c566a";
        };
        windowOpacity = lib.mkOption {
          type = lib.types.float;
          default = 1.0;
        };
        windowHighlightOff = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        animations = lib.mkOption {
          type = lib.types.addCheck (lib.types.attrsOf animationType) (
            animations: builtins.all animationShapeValid (builtins.attrValues animations)
          );
          default = defaultNiriAnimations;
        };
        extraConfig = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
      };

      colors = colorOptions;
      colorsLight = colorOptions;

      waybar = {
        config = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        style = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };

      waybarLight = {
        style = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };

      makoConfig = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      makoConfigLight = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      runtime = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Profile metadata consumed by runtime switching scripts.";
      };
    };
  };
}
