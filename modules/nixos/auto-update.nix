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
      getent
      git
      nix
      nixos-rebuild
      util-linux
    ];
    text = builtins.readFile ../../home/scripts/nixos-flake-update;
  };

  mkUpdateService =
    {
      description,
      label,
      commitMessage,
      inputs,
    }:
    let
      pipelineArgs = lib.escapeShellArgs (
        [
          "--label"
          label
          "--repo"
          "/home/rupan/nixos"
          "--target"
          "path:/home/rupan/nixos#laptop"
          "--commit-message"
          commitMessage
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
      serviceConfig = {
        Type = "oneshot";
        Nice = 15;
        IOSchedulingClass = "idle";
        CPUQuota = "1200%";
        MemoryHigh = "18G";
        MemoryMax = "22G";
        TasksMax = 1024;
      };
      script = ''
        exec ${lib.getExe updatePipeline} ${pipelineArgs}
      '';
    };
in
{
  options.auto-update.enable = lib.mkEnableOption "weekly flake input update plus hourly AI tool updates";

  config = lib.mkIf config.auto-update.enable {
    systemd.tmpfiles.rules = [ "f /run/nixos-auto-update.lock 0664 root users -" ];

    systemd.services.nixos-auto-update = mkUpdateService {
      description = "Update flake inputs, commit lock file, and rebuild";
      label = "weekly";
      commitMessage = "flake.lock: weekly auto-update";
      inputs = [ ];
    };

    systemd.services.nixos-ai-tools-auto-update = mkUpdateService {
      description = "Update AI tool flake inputs, commit lock file, and rebuild";
      label = "AI tools";
      commitMessage = "flake.lock: ai tools auto-update";
      inputs = [
        "claude-code-nix"
        "codex-cli-nix"
        "code-cursor-nix"
      ];
    };

    systemd.timers.nixos-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    systemd.timers.nixos-ai-tools-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
