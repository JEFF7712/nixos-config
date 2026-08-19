{
  lib,
  config,
  ...
}:

{
  options.docker.enable = lib.mkEnableOption "docker";

  config = lib.mkIf config.docker.enable {
    # Rootless is a separate user daemon. Leave virtualisation.docker.enable
    # off: that flag starts a rootful dockerd and the docker group, which is
    # root-equivalent via the docker.sock.
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
    # Still needed: nixpkgs wires CDI into rootless dockerd and Podman. The
    # rootful nvidia runtime wrapper applies only when virtualisation.docker.enable.
    hardware.nvidia-container-toolkit.enable = true;
  };
}
