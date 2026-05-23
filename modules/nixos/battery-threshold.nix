{ lib, config, ... }:

{
  options.battery-threshold.enable = lib.mkEnableOption "writable charge_control_end_threshold for wheel group";

  config = lib.mkIf config.battery-threshold.enable {
    systemd.tmpfiles.rules = [
      "z /sys/class/power_supply/BAT0/charge_control_end_threshold 0664 root wheel - -"
    ];
  };
}
