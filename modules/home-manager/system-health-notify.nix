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
          mkdir -p "$state_dir"

          for unit in nixos-auto-update.service nixos-ai-tools-auto-update.service; do
            properties="$(systemctl show "$unit" --property=ActiveState,InvocationID,Result)"
            active_state="$(printf '%s\n' "$properties" | sed -n 's/^ActiveState=//p')"
            invocation_id="$(printf '%s\n' "$properties" | sed -n 's/^InvocationID=//p')"
            result="$(printf '%s\n' "$properties" | sed -n 's/^Result=//p')"
            state_file="$state_dir/$unit"

            if [ "$active_state" = "failed" ] && [ -n "$invocation_id" ]; then
              previous=""
              if [ -r "$state_file" ]; then
                previous="$(cat "$state_file")"
              fi
              if [ "$previous" != "$invocation_id" ]; then
                notify-send -u critical "NixOS update failed" "$unit: $result"
                printf '%s\n' "$invocation_id" > "$state_file"
              fi
            fi
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
