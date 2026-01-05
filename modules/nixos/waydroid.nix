{ pkgs, lib, config, ... }:

{
  options.waydroid.enable = lib.mkEnableOption "waydroid";

  config = lib.mkIf config.waydroid.enable {
    environment.systemPackages = with pkgs; [ waydroid ];
    virtualisation.waydroid.enable = true;
  };
}
