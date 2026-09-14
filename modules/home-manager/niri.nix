{
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

      niriDisplayRecovery = pkgs.writeShellApplication {
        name = "niri-display-recovery";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          pkgs.niri
          pkgs.systemd
        ];
        text = ''
          set -u

          connected_external_outputs() {
            local status_file connector
            for status_file in /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-*/status; do
              [ -r "$status_file" ] || continue
              [ "$(cat "$status_file")" = connected ] || continue
              connector="$(basename "$(dirname "$status_file")")"
              printf '%s\n' "$connector"
            done
          }

          niri_lost_external_output() {
            local connector outputs
            outputs="$(niri msg -j outputs 2>/dev/null)" || return 1
            while IFS= read -r connector; do
              [ -n "$connector" ] || continue
              if ! jq -e --arg connector "$connector" 'has($connector)' >/dev/null 2>&1 <<<"$outputs"; then
                return 0
              fi
            done < <(connected_external_outputs)
            return 1
          }

          consecutive_failures=0
          cooldown_until=0

          while :; do
            now="$(date +%s)"
            if niri_lost_external_output; then
              consecutive_failures=$((consecutive_failures + 1))
            else
              consecutive_failures=0
            fi

            if [ "$consecutive_failures" -ge 2 ] && [ "$now" -ge "$cooldown_until" ]; then
              niri msg action power-on-monitors >/dev/null 2>&1 || true
              sleep 2
              if niri_lost_external_output; then
                systemctl --user restart niri.service
                cooldown_until=$((now + 30))
              fi
              consecutive_failures=0
            fi

            sleep 5
          done
        '';
      };
    in
    {

      home.packages = with pkgs; [
        grim
        slurp
        imv
        awww
        mpvpaper
        wl-clipboard
        nwg-look
        kdePackages.qt6ct
        adw-gtk3
        waypaper
        rofi
        ia-writer-quattro
        swayosd
        quickshell
        bc
        pulseaudio
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

        niri-display-recovery = {
          Unit = {
            Description = "Recover Niri after a stale external-display hotplug state";
            PartOf = [ "graphical-session.target" ];
            After = [ "niri.service" ];
          };
          Service = {
            ExecStart = lib.getExe niriDisplayRecovery;
            Restart = "on-failure";
            RestartSec = 3;
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };

        swayosd = {
          Unit = {
            Description = "SwayOSD on-screen display server";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            # GTK4 defaults to Vulkan. After idle, the first OSD frame on this
            # Intel iGPU + NVIDIA Prime laptop waits on pipeline compile
            # (SwayOSD#198), and volume is applied on that same GTK thread.
            Environment = [ "GSK_RENDERER=gl" ];
            ExecStart = "${pkgs.swayosd}/bin/swayosd-server";
            Restart = "on-failure";
            RestartSec = 3;
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
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
      xdg.configFile."gtk-2.0".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/gtk-2.0";
      xdg.configFile."swayosd".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/swayosd";
    }
  );
}
