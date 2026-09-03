{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.bluetooth.enable = lib.mkEnableOption "bluetooth";

  config = lib.mkIf config.bluetooth.enable {
    systemd.user.services.mpris-proxy = {
      Unit = {
        Description = "Bluetooth AVRCP to MPRIS bridge (headset buttons)";
        After = [ "bluetooth.target" ];
      };
      Service = {
        ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
