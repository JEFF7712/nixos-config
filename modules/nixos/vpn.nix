{ pkgs, lib, config, inputs, ... }:

{
  options.vpn.enable = lib.mkEnableOption "vpn";

  config = lib.mkIf config.vpn.enable {
    environment.systemPackages = [
      inputs.globalprotect-openconnect.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.openconnect
    ];
  };
}
