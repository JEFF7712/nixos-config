{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  measured = config.secureboot.measuredBoot.enable;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.secureboot = {
    enable = lib.mkEnableOption "secure boot via lanzaboote (auto keygen + enrollment)";
    measuredBoot.enable = lib.mkEnableOption "systemd-pcrlock measured boot, for TPM2-bound LUKS unlock";
  };

  config = lib.mkIf config.secureboot.enable {
    # lanzaboote replaces the systemd-boot *module* but keeps it as boot manager.
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      # Keygen at activation; enroll next boot in setup mode. Microsoft CAs for NVIDIA ROM.
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = true;

      # pcrlock rewrites TPM2 policy every switch (static PCR 7 breaks on UKI
      # updates). Cap 8: systemd-pcrlock refuses more variants.
      configurationLimit = lib.mkIf measured (lib.mkForce 8);
      measuredBoot = lib.mkIf measured {
        enable = true;
        # 0 firmware, 4 bootloader+UKI, 7 SB state. 1/2/3 are flaky.
        pcrs = [
          0
          4
          7
        ];
      };
    };

    # Upstream races first activation: generate-sb-keys vs fwupd EFI signer.
    systemd.services.fwupd-efi = {
      wants = [ "generate-sb-keys.service" ];
      after = [ "generate-sb-keys.service" ];
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
