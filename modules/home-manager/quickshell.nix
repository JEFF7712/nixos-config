{
  lib,
  pkgs,
  config,
  ...
}:

{
  options.quickshell.enable = lib.mkEnableOption "systemd-supervised Quickshell desktop bar";

  config = lib.mkIf config.quickshell.enable {
    systemd.user.services.quickshell-bar = {
      Unit = {
        Description = "Quickshell desktop bar";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.quickshell} -p ${config.repoPath}/home/configs/quickshell/shell.qml";
        Restart = "on-failure";
        RestartSec = 2;
        TimeoutStopSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}
