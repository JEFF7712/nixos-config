{
  diskoModule,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    diskoModule
    ./hardware-configuration.nix
    ./disko.nix
    ./base.nix
  ]
  ++ lib.optional (builtins.pathExists ./resume-offset.nix) ./resume-offset.nix;

  impermanence.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  btrfs-snapshots.enable = true;
  secureboot.measuredBoot.enable = true;

  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;
  zramSwap.priority = 100;

  virtualisation.vmVariantWithDisko = {
    virtualisation = {
      memorySize = 8192;
      cores = 8;
    };
    disko.devices.disk.main.content.partitions.luks.content.passwordFile = lib.mkForce (
      toString (pkgs.writeText "vm-luks-password" "rupan")
    );
    nvidia.enable = lib.mkForce false;
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    secrets.enable = lib.mkForce false;
    users.users.rupan.initialPassword = "rupan";
  };
}
