# Hardware config for the post-reinstall encrypted laptop. Same machine as
# hosts/laptop, but fileSystems/swap come from disko.nix instead of
# nixos-generate-config output.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # systemd initrd is required for TPM2 LUKS unlock.
  boot.initrd.systemd.enable = true;
  # No-op until `systemd-cryptenroll --tpm2-device=auto` runs post-install;
  # falls back to the passphrase prompt when the TPM refuses or is absent.
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
