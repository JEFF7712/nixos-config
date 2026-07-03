# The laptop after the LUKS+btrfs reinstall: same system as hosts/laptop,
# different disk layer. Runbook: docs/luks-reinstall.md. Once the reinstall
# has happened and settled, fold this into hosts/laptop and delete the ext4
# hardware-configuration.
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
    ../laptop/disko.nix
    ../laptop/base.nix
  ];

  # Ephemeral @root + /persist (camp-1 impermanence); @home stays durable.
  impermanence.enable = true;

  # Rehearsal VM (`just vm-crypt`): runs the real disko partitioning +
  # LUKS + btrfs inside QEMU, then boots from it. Same strip-downs as the
  # vmVariant in base.nix.
  virtualisation.vmVariantWithDisko = {
    virtualisation = {
      memorySize = 8192;
      cores = 8;
    };
    # The image-builder VM can't see /tmp/disk.key (real-install path), but
    # it shares the host store; LUKS passphrase in the rehearsal VM: "rupan".
    disko.devices.disk.main.content.partitions.luks.content.passwordFile = lib.mkForce (
      toString (pkgs.writeText "vm-luks-password" "rupan")
    );
    nvidia.enable = lib.mkForce false;
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    secrets.enable = lib.mkForce false;
    users.users.rupan.initialPassword = "rupan";
  };
}
