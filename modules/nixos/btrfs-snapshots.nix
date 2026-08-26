{
  lib,
  config,
  ...
}:

{
  options.btrfs-snapshots.enable = lib.mkEnableOption "scheduled btrbk snapshots of @home and @persist into @snapshots";

  config = lib.mkIf config.btrfs-snapshots.enable {
    assertions = [
      {
        assertion = config.impermanence.enable;
        message = "btrfs-snapshots.enable targets the disko btrfs layout, which only laptop-crypt has";
      }
    ];

    # btrbk snapshot_dir is relative to the volume; subvolid=5 must be mounted.
    fileSystems."/btrfs" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=/"
        "noatime"
        "nosuid"
        "nodev"
      ];
    };

    services.btrbk.instances.local = {
      onCalendar = "daily";
      settings = {
        timestamp_format = "long";
        # @root is deliberately absent: it is wiped every boot by design, so
        # a snapshot of it preserves nothing worth keeping.
        snapshot_preserve_min = "2d";
        snapshot_preserve = "14d 8w";
        volume."/btrfs" = {
          snapshot_dir = "@snapshots";
          subvolume = {
            "@home" = { };
            "@persist" = { };
          };
        };
      };
    };
  };
}
