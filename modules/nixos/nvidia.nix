{ pkgs, lib, config, ...  }: {

  options = {
    nvidia.enable = lib.mkEnableOption "enables nvidia drivers";
  };
  
  config = lib.mkIf config.nvidia.enable {
    
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
 
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";

        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };

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
