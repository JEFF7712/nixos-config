{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.netbird.enable = lib.mkEnableOption "netbird";

  config = lib.mkIf config.netbird.enable {
    services.netbird.enable = true;

    # Daemon stays up across suspend but peer map does not; restart after wake.
    systemd.services.netbird-restart-on-resume = {
      description = "Restart NetBird after resume from sleep";
      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      after = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart netbird.service";
      };
    };
  };
}
