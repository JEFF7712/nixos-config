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

      wallpaperTheming = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Re-theme from each wallpaper at runtime via matugen: on every
          wallpaper change (and variant toggle) apply_wallpaper_theme extracts
          a dominant color and regenerates the quickshell theme, GTK/Qt/kitty/
          cava/etc. The profile's baked colors act as the pre-first-run
          fallback. Unlike selfThemed (noctalia owns everything), the profile
          still uses the project's own bar and color-file plumbing.
        '';
      };

      colorEngine = lib.mkOption {
        type = lib.types.enum [
          "matugen"
          "iris"
        ];
        default = "matugen";
        description = ''
          Which engine apply_wallpaper_theme uses for a wallpaperTheming
          profile. "matugen" runs the matugen templates (config[-<profile>].toml);
          "iris" runs the vendored iris.py extractor (k-means CIELAB palette with
          WCAG contrast nudging) + iris-render. Ignored when wallpaperTheming is
          false.
        '';
      };

      matugenScheme = lib.mkOption {
        type = lib.types.enum [
          "scheme-content"
          "scheme-expressive"
          "scheme-fidelity"
          "scheme-fruit-salad"
          "scheme-monochrome"
          "scheme-neutral"
          "scheme-rainbow"
          "scheme-tonal-spot"
          "scheme-vibrant"
        ];
        default = "scheme-tonal-spot";
        description = ''
          matugen scheme type for wallpaperTheming profiles (passed as --type).
          scheme-neutral collapses every role into the source hue for a
          monochrome look; scheme-tonal-spot gives the standard multi-hue M3.
          Ignored when wallpaperTheming is false.
        '';
      };

      wallpaperAccentVivid = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          For wallpaperTheming profiles: pick the wallpaper's most vivid+bright
          color (saturation-weighted, normalized up to a bright value) as the
          matugen source color, instead of the most frequent colorful one. Use
          for a monochrome profile that wants one punchy accent (sharp); leave
          false for a profile whose whole surface adopts the dominant mood hue
          (tinted). Templates should read {{colors.source_color...}} for the
          accent to get the literal extracted color. Ignored when
          wallpaperTheming is false.
        '';
      };

      quickshellTheme = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = ''
          Theme tokens for the modular quickshell bar (colors plus style keys
          like barRadius, barHeight, barMarginTop, exclusiveZoneOffset,
          flatMode — see shell.qml's applyTheme).
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
          type = lib.types.either lib.types.int lib.types.float;
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
        focusRingWidth = lib.mkOption {
          type = lib.types.either lib.types.int lib.types.float;
          default = 4;
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
        focusOpacity = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Emit the per-focus opacity rules (active 0.8 / inactive 0.6). Set
            false for a fully opaque profile so windows stay at windowOpacity
            regardless of focus.
          '';
        };
        blur = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable niri's window background-effect blur. Off for opaque profiles.";
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
