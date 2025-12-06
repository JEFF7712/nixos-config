{ pkgs, lib, config, ... }: {
  options.tailscale.enable = lib.mkEnableOption "tailscale";

  config = lib.mkIf config.tailscale.enable {

    environment.systemPackages = [
      pkgs.tailscale
    ];
  };
}
