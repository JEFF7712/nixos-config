{ pkgs, lib, config, ... }: {
  options.docker.enable = lib.mkEnableOption "docker";

  config = lib.mkIf config.docker.enable {

    virtualisation.docker.enable = true;
    users.users.rupan.extraGroups = [ "docker" ];

  };
}
