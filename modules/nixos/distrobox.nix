{ pkgs, lib, config, ... }:

{
  options.distrobox.enable = lib.mkEnableOption "distrobox";

  config = lib.mkIf config.distrobox.enable {
    environment.systemPackages = with pkgs; [ distrobox ];
  };
}
