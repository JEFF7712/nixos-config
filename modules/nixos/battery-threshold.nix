{ lib, config, ... }:

{
  options.battery-threshold.enable = lib.mkEnableOption "writable charge_control_end_threshold for wheel group";

  config = lib.mkIf config.battery-threshold.enable {
    # The sysfs value resets to 100 on every boot; write the default here.
    # asusd (if running) re-applies its own saved limit afterwards.
    systemd.tmpfiles.rules = [
      "z /sys/class/power_supply/BAT0/charge_control_end_threshold 0664 root wheel - -"
      "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 80"
    ];
  };
}
