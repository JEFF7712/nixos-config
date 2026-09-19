{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.local-containers;
in
{
  options.local-containers.enable = lib.mkEnableOption "rootless docker, podman, and distrobox";

  config = lib.mkIf cfg.enable {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
    hardware.nvidia-container-toolkit.enable = lib.mkIf (config.nvidia.enable or false) true;

    virtualisation.podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    environment.systemPackages = with pkgs; [ distrobox ];
  };
}
