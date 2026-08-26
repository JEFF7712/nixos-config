{
  lib,
  config,
  ...
}:

{
  options.oom-protection.enable = lib.mkEnableOption "systemd-oomd monitoring so runaway builds die early instead of thrashing swap for hours";

  # Stock NixOS runs oomd but monitors nothing (`enable*Slice` defaults off).
  # Opting system+user slices in kills the hungriest cgroup on swap/pressure
  # instead of letting kernel OOM nuke random desktop apps.
  config = lib.mkIf config.oom-protection.enable {
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
      settings.OOM = {
        SwapUsedLimit = "80%";
        DefaultMemoryPressureLimit = "60%";
        DefaultMemoryPressureDurationSec = "20s";
      };
    };
  };
}
