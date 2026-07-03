{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.secureboot.enable = lib.mkEnableOption "secure boot via lanzaboote (auto keygen + enrollment)";

  config = lib.mkIf config.secureboot.enable {
    # lanzaboote replaces the systemd-boot module but keeps systemd-boot as
    # the boot manager and inherits its configurationLimit.
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      # Keys are generated at activation if missing; enrollment happens on
      # the next boot while the firmware is in setup mode. Microsoft CAs are
      # included by default so the NVIDIA option ROM keeps loading.
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = true;
    };

    # Upstream orders generate-sb-keys before the enroll prep but not before
    # the fwupd EFI signer, so the very first activation races key creation.
    systemd.services.fwupd-efi = {
      wants = [ "generate-sb-keys.service" ];
      after = [ "generate-sb-keys.service" ];
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
