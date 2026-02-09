{ pkgs, lib, config, ... }:

{
  options.nvidia.enable = lib.mkEnableOption "nvidia drivers";

  config = lib.mkIf config.nvidia.enable {
    
    services.xserver.videoDrivers = [ "nvidia" ];
    
    hardware.graphics = {
      enable = true;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
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

    # Performance mode that uses GPU and iGPU with sync
    specialisation.performance.configuration = {
      system.nixos.tags = [ "performance" ];
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
