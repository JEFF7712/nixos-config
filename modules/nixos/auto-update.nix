{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.auto-update.enable = lib.mkEnableOption "weekly flake input update, lock commit, and rebuild";

  # Replaces system.autoUpgrade, which is channel-based unless given a flake
  # and whose documented --update-input flags were removed from Nix >= 2.22.
  # The lock update and commit run as rupan so the repo never collects
  # root-owned files; only the rebuild itself runs as root.
  config = lib.mkIf config.auto-update.enable {
    systemd.services.nixos-auto-update = {
      description = "Update flake inputs, commit lock file, and rebuild";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        config.nix.package
        pkgs.git
        pkgs.util-linux
        pkgs.coreutils
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        repo=/home/rupan/nixos
        runuser -u rupan -- nix flake update --flake "path:$repo"
        if ! runuser -u rupan -- git -C "$repo" diff --quiet -- flake.lock; then
          runuser -u rupan -- git -C "$repo" commit -m "flake.lock: weekly auto-update" -- flake.lock
        fi
        ${lib.getExe pkgs.nixos-rebuild} switch --flake "path:$repo#laptop"
      '';
    };

    systemd.timers.nixos-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
