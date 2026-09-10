{
  pkgs,
  lib,
  config,
  ...
}:

let
  updatePipeline = pkgs.writeShellApplication {
    name = "nixos-flake-update";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      # `cmp` for flake.lock snapshot; writeShellApplication pins PATH.
      diffutils
      getent
      git
      gnutar
      # gnused for nix-cascade-guard (same PATH-pin coupling as missing-cmp).
      gnused
      nix
      nixos-rebuild
      util-linux
    ];
    text = builtins.readFile ../../home/scripts/nixos-flake-update;
  };

  failureAlert = pkgs.writeShellApplication {
    name = "nixos-auto-update-alert";
    runtimeInputs = with pkgs; [
      systemd
    ];
    text = ''
      # Root has no session bus; start the user notify unit instead.
      systemctl --machine=rupan@ --user start system-update-failure-notify.service
    '';
  };

  mkUpdateService =
    {
      description,
      label,
      commitMessage,
      evalFailure,
      inputs,
    }:
    let
      pipelineArgs = lib.escapeShellArgs (
        [
          "--label"
          label
          "--repo"
          config.repoPath
          "--target"
          "path:${config.repoPath}#laptop"
          "--commit-message"
          commitMessage
          "--eval-failure"
          evalFailure
        ]
        ++ lib.concatMap (input: [
          "--input"
          input
        ]) inputs
      );
    in
    {
      inherit description;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      onFailure = [ "nixos-auto-update-alert.service" ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 15;
        IOSchedulingClass = "idle";
        CPUQuota = "1200%";
        MemoryHigh = "18G";
        MemoryMax = "22G";
        TasksMax = 1024;
        StateDirectory = "nixos-auto-update";
      };
      script = ''
        exec ${lib.getExe updatePipeline} ${pipelineArgs}
      '';
    };
in
{
  options.auto-update.enable = lib.mkEnableOption "weekly flake input update and rebuild";

  config = lib.mkIf config.auto-update.enable {
    systemd.tmpfiles.rules = [ "f /run/nixos-auto-update.lock 0664 root users -" ];

    systemd.services.nixos-auto-update-alert = {
      description = "Notify the graphical session that an auto-update unit failed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe failureAlert;
      };
    };

    systemd.services.nixos-auto-update = mkUpdateService {
      description = "Update flake inputs, commit lock file, and rebuild";
      label = "weekly";
      commitMessage = "flake.lock: weekly auto-update";
      evalFailure = "hard";
      inputs = [ ];
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
