{
  lib,
  config,
  ...
}:

{
  options.build-resource-policy.enable = lib.mkEnableOption "resource controls for daemon-owned Nix builds";

  config = lib.mkIf config.build-resource-policy.enable {
    systemd.services.nix-daemon.serviceConfig = {
      CPUWeight = 25;
      IOWeight = 25;
      MemoryHigh = "22G";
      MemoryMax = "25G";
      TasksMax = 4096;
    };
  };
}
