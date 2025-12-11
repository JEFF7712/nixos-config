{ pkgs, lib, config, ... }: {
  options.netbird.enable = lib.mkEnableOption "netbird";

  config = lib.mkIf config.netbird.enable {
    services.netbird.enable = true;
  };
}
