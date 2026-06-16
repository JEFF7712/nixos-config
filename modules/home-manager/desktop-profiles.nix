{
  lib,
  pkgs,
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
          assertion = p.bar == "quickshell" -> p.quickshellTheme != null;
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
        {
          # A non-self-themed profile that leaves core color slots null renders
          # empty theme files (blank GTK/Qt/kitty) — almost always a broken
          # palette. Self-themed profiles (noctalia) manage colors at runtime.
          assertion =
            p.selfThemed
            || (
              p.colors.gtk3 != null && p.colors.gtk4 != null && p.colors.kitty != null && p.colors.qt6 != null
            );
          message = "desktopProfiles.profiles.${name}: not self-themed but missing core colors (gtk3/gtk4/kitty/qt6) — check the palette.";
        }
        {
          # The inverse invariant: a self-themed profile (noctalia) must leave
          # its colors null so the shell owns them at runtime. A stray static
          # color here would be written but never applied — a silent mistake.
          assertion =
            !p.selfThemed
            || (
              p.colors.gtk3 == null && p.colors.gtk4 == null && p.colors.kitty == null && p.colors.qt6 == null
            );
          message = "desktopProfiles.profiles.${name}: self-themed but defines static colors (gtk3/gtk4/kitty/qt6) — leave them null.";
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

    # matugen + imagemagick drive the wallpaper-tinted profiles: imagemagick
    # extracts a dominant source color (matugen's own image extractor is broken
    # in 4.0), matugen renders the theme templates from it.
    home.packages =
      (with pkgs; [
        matugen
        imagemagick
        iris-python # numpy+pillow python for the iris color engine (tinted)
      ])
      ++ lib.flatten (
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

    # These dirs are real copies (not store symlinks) because the runtime
    # profile scripts mutate files inside them. Repo edits to the base files
    # must still propagate without clobbering runtime-applied theme state, so:
    #   - "owned" files (whole-file rewritten on every profile switch) are
    #     seeded once and never touched again here.
    #   - base files are re-copied only when the *repo* version's content hash
    #     changes (tracked per-file), so a live copy carrying runtime sed
    #     patches is left alone unless you actually edited it in the repo.
    home.activation.initDesktopProfileLiveConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      STATE="$HOME/.local/state/desktop-profiles/synced-hashes"
      $DRY_RUN_CMD mkdir -p "$STATE"

      record_hash() {
        # Skip the side-effecting stamp write during dry-activate.
        [ -n "''${DRY_RUN_CMD:-}" ] || printf '%s' "$2" > "$1"
      }

      sync_live_config() {
        # $1=src dir  $2=dest dir  $3=space-separated owned (seed-once) rel paths
        local src="$1" dest="$2" f rel d h stamp stored o is_owned
        [ -d "$src" ] || return 0

        while IFS= read -r -d ''' f; do
          rel="''${f#"$src"/}"
          d="$dest/$rel"

          is_owned=0
          for o in $3; do
            [ "$o" = "$rel" ] && { is_owned=1; break; }
          done
          if [ "$is_owned" = 1 ]; then
            [ -e "$d" ] || $DRY_RUN_CMD install -Dm644 "$f" "$d"
            continue
          fi

          h=$(sha256sum "$f" | cut -d' ' -f1)
          stamp="$STATE/$(printf '%s' "$d" | sha256sum | cut -d' ' -f1)"
          stored=$(cat "$stamp" 2>/dev/null || echo "")

          if [ ! -e "$d" ]; then
            $DRY_RUN_CMD install -Dm644 "$f" "$d"
            record_hash "$stamp" "$h"
          elif [ -z "$stored" ]; then
            # First run against an existing checkout: adopt current state so a
            # runtime-patched live file is not reset; propagate from next edit.
            record_hash "$stamp" "$h"
          elif [ "$stored" != "$h" ]; then
            $DRY_RUN_CMD install -Dm644 "$f" "$d"
            record_hash "$stamp" "$h"
          fi
        done < <(find "$src" -type f -print0)
      }

      CFG="${config.repoPath}/home/configs"
      sync_live_config "$CFG/kitty"   "$HOME/.config/kitty"   "colors.conf"
      sync_live_config "$CFG/gtk-3.0" "$HOME/.config/gtk-3.0" "noctalia.css settings.ini"
      sync_live_config "$CFG/gtk-4.0" "$HOME/.config/gtk-4.0" "noctalia.css settings.ini"
      sync_live_config "$CFG/qt5ct"   "$HOME/.config/qt5ct"   "colors/noctalia.conf"
      sync_live_config "$CFG/qt6ct"   "$HOME/.config/qt6ct"   "colors/noctalia.conf qt6ct.conf"
      sync_live_config "$CFG/rofi"    "$HOME/.config/rofi"    "profile-switcher.rasi"
      sync_live_config "$CFG/tmux"    "$HOME/.config/tmux"    ""

      # Firefox profile dir name varies per machine; resolve the default-release
      # profile by glob instead of a hardcoded id.
      for ff in "$HOME/.mozilla/firefox/"*.default-release; do
        [ -d "$ff" ] || continue
        sync_live_config "$CFG/firefox/chrome" "$ff/chrome" "DownToneUI/_globals.css"
        break
      done
    '';
  };
}
