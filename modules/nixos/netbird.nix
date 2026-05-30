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

    # NetBird's daemon stays running across suspend but fails to rebuild
    # its peer map on resume — symptom: every routed subnet has "no
    # peers currently available" and Management gRPC is in silent
    # retry. Restarting the service after wake gets us back to a clean
    # ICE + handshake state.
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
