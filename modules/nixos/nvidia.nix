{
  lib,
  config,
  ...
}:

{
  options.nvidia.enable = lib.mkEnableOption "nvidia drivers";

  config = lib.mkIf config.nvidia.enable {

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      powerManagement = {
        enable = true;
        # Offload-only: the performance specialisation uses sync, which
        # asserts against finegrained.
        finegrained = true;
      };
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };

    hardware.nvidia-container-toolkit.enable = true;
    systemd.services.nvidia-container-toolkit-cdi-generator = {
      restartIfChanged = false;
      serviceConfig.SuccessExitStatus = [ 1 ];
    };

    specialisation.performance.configuration = {
      system.nixos.tags = [ "performance" ];
      hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
      hardware.nvidia.prime = {
        offload = {
          enable = lib.mkForce false;
          enableOffloadCmd = lib.mkForce false;
        };
        sync.enable = lib.mkForce true;
      };
    };
  };
}
