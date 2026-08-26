# laptop after LUKS+btrfs reinstall (same system, different disk). See docs/luks-reinstall.md.
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
  ]
  # resume_offset exists only after the swapfile does; until then skip hibernate.
  ++ lib.optional (builtins.pathExists ./resume-offset.nix) ./resume-offset.nix;

  # Ephemeral @root + /persist (camp-1 impermanence); @home stays durable.
  impermanence.enable = true;

  # Nothing else schedules a btrfs scrub.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  # Same-disk undo for @home/@persist, not a backup.
  btrfs-snapshots.enable = true;

  # TPM2 unlock that survives kernel updates; PCR 7 keyslot is the migration path.
  secureboot.measuredBoot.enable = true;

  # 180 would page into the 16G swapfile once zram fills; keep zram strictly ahead.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;
  zramSwap.priority = 100;

  # `just vm-crypt`: real disko+LUKS+btrfs in QEMU. Same strip-downs as base.nix.
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
