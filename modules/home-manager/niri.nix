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

          ensure_niri_socket() {
            if [ -n "''${NIRI_SOCKET:-}" ] && [ -S "$NIRI_SOCKET" ]; then
              return 0
            fi
            for s in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/niri.*.sock; do
              if [ -S "$s" ]; then
                export NIRI_SOCKET="$s"
                return 0
              fi
            done
            return 1
          }

          connected_external_outputs() {
            local status_file connector
            for status_file in /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-*/status; do
              [ -r "$status_file" ] || continue
              [ "$(<"$status_file")" = connected ] || continue
              connector="$(basename "$(dirname "$status_file")")"
              connector="''${connector#card*-}"
              printf '%s\n' "$connector" 2>/dev/null || true
            done
          }

          niri_lost_external_output() {
            local connector outputs
            ensure_niri_socket || return 1
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
        satty
        imv
        awww
        mpvpaper
        wl-clipboard
        nwg-look
        kdePackages.qt6ct
        adw-gtk3
        waypaper
        ia-writer-quattro
        quickshell
        bc
        pulseaudio
        ddcutil
        python3
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
      };

      xdg.configFile."niri".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/niri";
      xdg.configFile."gtk-2.0".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/gtk-2.0";
    }
  );
}
