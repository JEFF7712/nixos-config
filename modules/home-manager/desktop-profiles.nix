{
  lib,
  config,
  ...
}:

let
  profileOptions = import ../../lib/desktop-profiles/options.nix { inherit lib; };
  runtimeDefaults = import ../../lib/desktop-profiles/runtime-defaults.nix;
  profileFiles = import ../../lib/desktop-profiles/files.nix {
    inherit lib runtimeDefaults;
  };
in
{
  options.desktopProfiles = {
    enable = lib.mkEnableOption "desktop profile system";

    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "noctalia";
      description = "Profile to activate on first home-manager switch if none is set.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileOptions.profileType;
      default = { };
    };

    autoVariant = {
      enable = lib.mkEnableOption "scheduled dark/light variant switching";

      lightTime = lib.mkOption {
        type = lib.types.str;
        default = "08:00";
        description = "Time of day (HH:MM) to switch to the light variant.";
      };

      darkTime = lib.mkOption {
        type = lib.types.str;
        default = "20:00";
        description = "Time of day (HH:MM) to switch back to dark. Must be later than lightTime.";
      };
    };
  };

  config = lib.mkIf config.desktopProfiles.enable {
    assertions = lib.flatten (
      lib.mapAttrsToList (name: p: [
        {
          assertion = (p.bar == "quickshell" || p.bar == "clean") -> p.quickshellTheme != null;
          message = "desktopProfiles.profiles.${name}: bar \"${p.bar}\" requires quickshellTheme.";
        }
        {
          assertion = p.bar == "waybar" -> p.waybar.config != null;
          message = "desktopProfiles.profiles.${name}: bar \"waybar\" requires waybar.config.";
        }
        {
          assertion =
            profileFiles.hasLight p -> (p.quickshellTheme == null -> p.quickshellThemeLight == null);
          message = "desktopProfiles.profiles.${name}: defines quickshellThemeLight without a quickshellTheme.";
        }
        {
          assertion =
            (profileFiles.hasLight p && p.quickshellTheme != null) -> p.quickshellThemeLight != null;
          message = "desktopProfiles.profiles.${name}: has a light variant but no quickshellThemeLight — the bar would stay dark when toggling.";
        }
      ]) config.desktopProfiles.profiles
    );

    systemd.user.services.auto-variant = lib.mkIf config.desktopProfiles.autoVariant.enable {
      Unit.Description = "Apply scheduled desktop profile variant";
      Service = {
        Type = "oneshot";
        ExecStart = "${config.home.homeDirectory}/.local/bin/auto-variant ${config.desktopProfiles.autoVariant.lightTime} ${config.desktopProfiles.autoVariant.darkTime}";
        Environment = "PATH=${config.home.homeDirectory}/.local/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin";
      };
    };

    systemd.user.timers.auto-variant = lib.mkIf config.desktopProfiles.autoVariant.enable {
      Unit.Description = "Scheduled desktop profile variant switching";
      Timer = {
        OnCalendar = [
          config.desktopProfiles.autoVariant.lightTime
          config.desktopProfiles.autoVariant.darkTime
        ];
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    home.packages = lib.flatten (
      lib.mapAttrsToList (
        _name: profile: lib.optional (profile.cursor.package != null) profile.cursor.package
      ) config.desktopProfiles.profiles
    );

    home.file = lib.mkMerge (
      lib.mapAttrsToList profileFiles.generateProfileFiles config.desktopProfiles.profiles
    );

    home.activation.initDesktopProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PROFILES_DIR="$HOME/.config/desktop-profiles"
      ACTIVE_LINK="$PROFILES_DIR/active-niri-overrides.kdl"
      ACTIVE_FILE="$PROFILES_DIR/active"
      VARIANT_FILE="$PROFILES_DIR/active-variant"
      DEFAULT="${config.desktopProfiles.defaultProfile}"

      if [ ! -e "$ACTIVE_LINK" ]; then
        $DRY_RUN_CMD ln -s "$PROFILES_DIR/$DEFAULT/niri-overrides.kdl" "$ACTIVE_LINK"
      fi
      if [ ! -e "$ACTIVE_FILE" ]; then
        echo "$DEFAULT" | $DRY_RUN_CMD tee "$ACTIVE_FILE" > /dev/null
      fi
      if [ ! -e "$VARIANT_FILE" ]; then
        echo "dark" | $DRY_RUN_CMD tee "$VARIANT_FILE" > /dev/null
      fi
    '';

    home.activation.initDesktopProfileLiveConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      copy_live_dir() {
        src="$1"
        dest="$2"

        if [ -L "$dest" ]; then
          $DRY_RUN_CMD rm -f "$dest"
        fi

        if [ ! -e "$dest" ]; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$dest")"
          $DRY_RUN_CMD cp -R "$src" "$dest"
        fi
      }

      copy_live_dir "${config.repoPath}/home/configs/kitty" "$HOME/.config/kitty"
      copy_live_dir "${config.repoPath}/home/configs/gtk-3.0" "$HOME/.config/gtk-3.0"
      copy_live_dir "${config.repoPath}/home/configs/gtk-4.0" "$HOME/.config/gtk-4.0"
      copy_live_dir "${config.repoPath}/home/configs/qt5ct" "$HOME/.config/qt5ct"
      copy_live_dir "${config.repoPath}/home/configs/qt6ct" "$HOME/.config/qt6ct"
      copy_live_dir "${config.repoPath}/home/configs/rofi" "$HOME/.config/rofi"
      copy_live_dir "${config.repoPath}/home/configs/tmux" "$HOME/.config/tmux"
      copy_live_dir \
        "${config.repoPath}/home/configs/firefox/chrome" \
        "$HOME/.mozilla/firefox/09longn9.default-release/chrome"
    '';
  };
}
