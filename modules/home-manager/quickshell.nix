{
  lib,
  pkgs,
  config,
  ...
}:

{
  options.quickshell.enable = lib.mkEnableOption "systemd-supervised Quickshell desktop bar";

  config = lib.mkIf config.quickshell.enable {
    # Idle greeting feeds: next-events (calendar-python), homelab-health (kubectl).
    home.packages = with pkgs; [
      calendar-python
      kubectl
      folio-page
    ];

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

    # Shell for the `folio` profile (bar = "folio"), vendored from seg6/dotfiles.
    systemd.user.services.folio-shell = {
      Unit = {
        Description = "Folio desktop shell";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };
      Service = {
        ExecStartPre = "-${config.repoPath}/home/scripts/folio-page-refresh";
        ExecStart = "${lib.getExe pkgs.quickshell} -p ${config.repoPath}/home/configs/quickshell-folio/shell.qml";
        Environment = [ "FOLIO_PAM_CONFIG=hyprlock" ];
        Restart = "on-failure";
        RestartSec = 2;
        TimeoutStopSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    services.cliphist.enable = true;
  };
}
