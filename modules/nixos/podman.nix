{ pkgs, lib, config, ... }:

{
  options.podman.enable = lib.mkEnableOption "podman";

  config = lib.mkIf config.podman.enable {
    virtualisation.podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
