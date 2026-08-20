{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.systemHealthNotify.enable = lib.mkEnableOption "desktop notifications for failed system maintenance";

  config = lib.mkIf config.systemHealthNotify.enable (
    let
      notifyFailures = pkgs.writeShellApplication {
        name = "system-update-failure-notify";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.libnotify
          pkgs.systemd
        ];
        text = ''
          set -eu

          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/system-health-notify"
          escalate_after=3
          mkdir -p "$state_dir"

          for unit in nixos-auto-update.service nixos-ai-tools-auto-update.service; do
            properties="$(systemctl show "$unit" --property=ExecMainStatus,InvocationID,Result)"
            exec_main_status="$(printf '%s\n' "$properties" | sed -n 's/^ExecMainStatus=//p')"
            invocation_id="$(printf '%s\n' "$properties" | sed -n 's/^InvocationID=//p')"
            result="$(printf '%s\n' "$properties" | sed -n 's/^Result=//p')"
            state_file="$state_dir/$unit"

            previous_id=""
            consecutive=0
            notified_level="none"
            if [ -r "$state_file" ]; then
              previous_id="$(sed -n '1p' "$state_file")"
              consecutive="$(sed -n '2p' "$state_file")"
              notified_level="$(sed -n '3p' "$state_file")"
            fi
            case "$consecutive" in
              '''|*[!0-9]*) consecutive=0 ;;
            esac
            case "$notified_level" in
              normal|critical) ;;
              *) notified_level="none" ;;
            esac

            case "$exec_main_status" in
              '''|0)
                rm -f "$state_file"
                continue
                ;;
              *[!0-9]*)
                continue
                ;;
            esac

            [ -n "$invocation_id" ] || continue

            if [ "$previous_id" = "$invocation_id" ]; then
              continue
            fi

            consecutive=$((consecutive + 1))

            if [ "$consecutive" -ge "$escalate_after" ] && [ "$notified_level" != critical ]; then
              notify-send -u critical -t 0 "NixOS update failed" \
                "$unit has failed $consecutive times in a row (exit $exec_main_status)"
              notified_level=critical
            elif [ "$consecutive" -eq 1 ]; then
              notify-send -u normal "NixOS update failed" \
                "$unit: exit $exec_main_status ($result)"
              notified_level=normal
            fi

            printf '%s\n%s\n%s\n' "$invocation_id" "$consecutive" "$notified_level" > "$state_file"
          done
        '';
      };
    in
    {
      systemd.user.services.system-update-failure-notify = {
        Unit = {
          Description = "Notify about failed NixOS update services";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe notifyFailures;
        };
      };

      systemd.user.timers.system-update-failure-notify = {
        Unit = {
          Description = "Check for failed NixOS update services";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Timer = {
          OnActiveSec = "2m";
          OnUnitActiveSec = "5m";
          Unit = "system-update-failure-notify.service";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    }
  );
}
