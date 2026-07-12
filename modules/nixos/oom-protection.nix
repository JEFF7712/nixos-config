{
  lib,
  config,
  ...
}:

{
  options.oom-protection.enable = lib.mkEnableOption "systemd-oomd monitoring so runaway builds die early instead of thrashing swap for hours";

  # Stock NixOS ships systemd-oomd running but monitoring nothing: the
  # enable*Slice toggles default off, so ManagedOOM*=auto opts no cgroup in.
  # Result: a build that eats all RAM thrashes 15G of swap for hours and the
  # *kernel* OOM killer eventually nukes random desktop apps. Opting the
  # system and user slices in lets oomd kill the single hungriest cgroup
  # (normally the build) on swap/pressure, well before that.
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
