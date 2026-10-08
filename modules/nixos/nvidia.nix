{
  lib,
  config,
  pkgs,
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
        finegrained = false;
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

    # Disable runtime D3 transitions after a GSP resume crash blocked system sleep.
    boot.extraModprobeConfig = "options nvidia NVreg_DynamicPowerManagement=0x00";

    systemd.services =
      lib.genAttrs
        [
          "systemd-suspend"
          "systemd-hibernate"
          "systemd-hybrid-sleep"
          "systemd-suspend-then-hibernate"
        ]
        (_: {
          unitConfig.OnFailure = "sleep-failure-poweroff.service";
          serviceConfig = {
            TimeoutStartSec = "60s";
            TimeoutStopSec = "15s";
          };
        })
      // {
        sleep-failure-poweroff = {
          description = "Power off after failed sleep with the lid closed";
          path = [
            pkgs.coreutils
            pkgs.systemd
          ];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "30s";
          };
          script = ''
            LID_CLOSE_ACTION_LIB=1
            source ${../../home/scripts/lid-close-action}
            lid_sleep_failed
          '';
        };
        nvidia-container-toolkit-cdi-generator = {
          wantedBy = lib.mkForce [ ];
          restartIfChanged = false;
          serviceConfig = {
            ExecStartPre = lib.mkForce [ ];
            SuccessExitStatus = [ 1 ];
          };
        };
      };

    hardware.nvidia-container-toolkit.enable = true;

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
