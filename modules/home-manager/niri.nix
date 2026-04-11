{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

{
  options.niri.enable = lib.mkEnableOption "user niri config";

  config = lib.mkIf config.niri.enable (
    let
      batteryLowNotify = pkgs.writeShellApplication {
        name = "battery-low-notify";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.libnotify
        ];
        text = ''
          set -eu

          profile_file="$HOME/.config/desktop-profiles/active"
          cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}"
          state_file="$cache_dir/battery-low-notify-level"

          mkdir -p "$cache_dir"

          active_profile=""
          if [ -r "$profile_file" ]; then
            active_profile="$(cat "$profile_file")"
          fi

          if [ "$active_profile" = "noctalia" ]; then
            rm -f "$state_file"
            exit 0
          fi

          set -- /sys/class/power_supply/BAT*
          if [ ! -e "$1" ]; then
            rm -f "$state_file"
            exit 0
          fi

          battery_dir="$1"
          if [ ! -r "$battery_dir/capacity" ] || [ ! -r "$battery_dir/status" ]; then
            rm -f "$state_file"
            exit 0
          fi

          capacity="$(cat "$battery_dir/capacity")"
          status="$(cat "$battery_dir/status")"
          last_level=""

          if [ -f "$state_file" ]; then
            last_level="$(cat "$state_file")"
          fi

          if [ "$status" != "Discharging" ]; then
            rm -f "$state_file"
            exit 0
          fi

          if [ "$capacity" -le 10 ] && [ "$last_level" != "critical" ]; then
            notify-send -u critical "Battery critical" "''${capacity}% remaining"
            printf '%s\n' critical > "$state_file"
          elif [ "$capacity" -le 20 ] && [ "$last_level" != "warning" ] && [ "$last_level" != "critical" ]; then
            notify-send -u normal "Battery low" "''${capacity}% remaining"
            printf '%s\n' warning > "$state_file"
          elif [ "$capacity" -gt 20 ]; then
            rm -f "$state_file"
          fi
        '';
      };
    in
    {

      home.packages = with pkgs; [
        grim
        slurp
        awww
        wl-clipboard
        nwg-look
        kdePackages.qt6ct
        adw-gtk3
        waypaper
        rofi
        python3Packages.pywal
        mako
        waybar
        ia-writer-quattro
      ];

      systemd.user.services = {
        awww = {
          Unit = {
            Description = "Wayland wallpaper daemon";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.awww}/bin/awww-daemon --no-cache";
            Restart = "on-failure";
            RestartSec = 3;
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };

        battery-low-notify = {
          Unit = {
            Description = "Low battery notifier";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe batteryLowNotify;
          };
        };
      };

      systemd.user.timers.battery-low-notify = {
        Unit = {
          Description = "Poll battery level for notifications";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Timer = {
          OnActiveSec = "1m";
          OnUnitActiveSec = "1m";
          Unit = "battery-low-notify.service";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      xdg.configFile."niri".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/niri";
      xdg.configFile."kitty".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/kitty";
      xdg.configFile."gtk-2.0".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/gtk-2.0";
      xdg.configFile."gtk-3.0".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/gtk-3.0";
      xdg.configFile."gtk-4.0".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/gtk-4.0";
      xdg.configFile."qt5ct".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/qt5ct";
      xdg.configFile."qt6ct".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/qt6ct";
    }
  );
}
