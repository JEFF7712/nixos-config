{ inputs, ... }:
{
  imports = [
    inputs.intentd.nixosModules.reliabilityRecovery
    "${inputs.disko}/module.nix"
    ./hardware-configuration.nix
    ./disko.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = "intentd-recovery";
  boot.lanzaboote.pkiBundle = "/var/lib/sbctl";
  fileSystems."/var/lib/intentd" = {
    device = "/persist/var/lib/intentd";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/persist" ];
  };
  fileSystems."/var/lib/sbctl" = {
    device = "/persist/var/lib/sbctl";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/persist" ];
  };
}
