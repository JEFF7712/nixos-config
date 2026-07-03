# Camp-1 impermanence: ephemeral btrfs @root, durable @home/@nix, declared
# system state under /persist (preservation module). Requires the disko
# layout in hosts/laptop/disko.nix (@persist subvolume, @root-blank snapshot
# from its postCreateHook) and systemd initrd. Enabled on laptop-crypt only
# until the LUKS reinstall happens.
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [ inputs.preservation.nixosModules.preservation ];

  options.impermanence.enable = lib.mkEnableOption "ephemeral btrfs root with declared state in /persist";

  config = lib.mkIf config.impermanence.enable {
    fileSystems."/persist".neededForBoot = true;

    # Wipe @root back to the blank snapshot on every boot. The outgoing root
    # is parked under old_roots/ for 14 days so "that actually mattered" has
    # a recovery window.
    boot.initrd.systemd.services.rollback-root = {
      description = "Rollback btrfs @root to the blank snapshot";
      wantedBy = [ "initrd.target" ];
      requires = [ "dev-mapper-cryptroot.device" ];
      after = [ "dev-mapper-cryptroot.device" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      path = with pkgs; [
        btrfs-progs
        coreutils
        findutils
        util-linux
      ];
      script = ''
        mkdir -p /btrfs
        mount -o subvol=/ /dev/mapper/cryptroot /btrfs

        delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs/$i"
          done
          btrfs subvolume delete "$1"
        }

        if [ -e /btrfs/@root ]; then
          mkdir -p /btrfs/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs/@root)" +%Y%m%dT%H%M%S)
          mv /btrfs/@root "/btrfs/old_roots/$timestamp"
        fi

        for i in $(find /btrfs/old_roots/ -maxdepth 1 -mindepth 1 -mtime +14); do
          delete_subvolume_recursively "$i"
        done

        btrfs subvolume snapshot /btrfs/@root-blank /btrfs/@root
        umount /btrfs
      '';
    };

    preservation = {
      enable = true;
      preserveAt."/persist" = {
        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
        ];
        directories = [
          {
            directory = "/etc/ssh";
            inInitrd = true;
          }
          {
            directory = "/var/lib/nixos";
            inInitrd = true;
          }
          {
            directory = "/var/log";
            inInitrd = true;
          }
          "/var/lib/systemd"
          "/var/lib/sbctl"
          {
            directory = "/etc/NetworkManager/system-connections";
            mode = "0700";
          }
          "/var/lib/bluetooth"
          "/var/lib/docker"
          "/var/lib/containers"
          "/var/lib/waydroid"
          "/var/lib/netbird"
          # DynamicUser services (ollama et al.) keep state here; systemd
          # requires 0700 on it.
          {
            directory = "/var/lib/private";
            mode = "0700";
          }
          "/var/lib/asusd"
          "/var/lib/upower"
          "/var/lib/fwupd"
        ];
      };
    };

    # First boot has no persisted machine-id yet; let systemd commit the
    # generated one into /persist instead of the ephemeral root.
    systemd.services.systemd-machine-id-commit = {
      unitConfig.ConditionPathIsMountPoint = [
        ""
        "/persist/etc/machine-id"
      ];
      serviceConfig.ExecStart = [
        ""
        "systemd-machine-id-setup --commit --root /persist"
      ];
    };
  };
}
