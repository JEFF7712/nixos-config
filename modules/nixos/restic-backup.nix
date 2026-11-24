# Point-in-time backups of what Syncthing does not carry: preserved system
# state (/persist) and home configuration, to the homelab restic REST server
# (homelab flake/modules/nas-restic.nix). The NAS dataset keeps 30 days of
# daily ZFS snapshots on top of the retention below.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.backup;
  home = config.users.users.${cfg.user}.home;
  # Synced send-only to the NAS by modules/nixos/syncthing.nix.
  syncedFolders = [
    "documents"
    "Documents"
    "projects"
    "code"
    "school"
    "businesses"
    "research"
    "homelab"
    "obsidian"
    "media"
    "Videos"
  ];
  # Regenerable caches, downloads, game data and tool stores.
  regenerable = [
    ".cache"
    ".npm"
    ".bun"
    ".gradle"
    ".android"
    ".arduino15"
    ".wine"
    ".cargo/registry"
    ".rustup"
    "go"
    "games"
    "ProxyMedia"
    "Downloads"
    ".local/share/Steam"
    ".local/share/containers"
    ".local/share/docker"
    ".local/share/waydroid"
    ".local/share/Trash"
    ".local/share/pnpm"
    ".local/share/uv"
    ".local/share/opencode"
    ".local/share/cursor-agent"
    ".local/share/zed/external_agents"
    ".local/share/zed/languages"
    ".local/share/zed/copilot"
    ".local/share/zed/extensions"
    ".local/share/zed/node"
    ".codex/.tmp"
    ".codex/packages"
    ".codex/sessions"
    ".vscode/extensions"
    ".cursor/extensions"
    ".antigravity/extensions"
    ".MathWorks/ServiceHost"
    ".proton_test_compat"
    # Pushed to GitHub; the working tree stays in the backup.
    "nixos-assets/.git"
    ".mozilla/firefox/*/cache2"
    ".mozilla/firefox/Crash Reports"
    ".config/*/Cache"
    ".config/*/Code Cache"
    ".config/*/GPUCache"
    ".config/*/CachedData"
    ".config/*/CachedExtensionVSIXs"
    ".config/*/logs"
  ];
in
{
  options.homelab.backup = {
    enable = lib.mkEnableOption "restic backups of /persist and home configuration to the homelab";
    user = lib.mkOption {
      type = lib.types.str;
      default = "rupan";
      description = "Desktop user whose home is backed up.";
    };
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://restic.rupan.dev/";
      description = "Server root probed before each run; unreachable means skip, not fail.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."restic/repository" = { };
    sops.secrets."restic/password" = { };

    services.restic.backups.homelab = {
      initialize = true;
      repositoryFile = config.sops.secrets."restic/repository".path;
      passwordFile = config.sops.secrets."restic/password".path;
      paths = [
        "/persist"
        home
      ];
      exclude = [
        "/persist/var/log"
        "/persist/var/lib/containers"
        "/persist/var/lib/systemd/coredump"
        # Re-pulled models.
        "/persist/var/lib/private/ollama"
      ]
      ++ map (path: "${home}/${path}") (syncedFolders ++ regenerable);
      extraBackupArgs = [
        "--exclude-caches"
        "--one-file-system"
      ];
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
      timerConfig = {
        OnCalendar = "00/4:00";
        Persistent = true;
        RandomizedDelaySec = "20min";
      };
    };

    systemd.services.restic-backups-homelab = {
      # On battery or away from the homelab the run is skipped, not failed;
      # the 4-hourly timer retries.
      unitConfig.ConditionACPower = true;
      serviceConfig = {
        ExecCondition = "${lib.getExe pkgs.curl} -s -o /dev/null --max-time 10 ${cfg.endpoint}";
        Nice = 19;
        IOSchedulingClass = "idle";
        CPUWeight = 20;
        # The NVMe has no IO scheduler, so idle class is a no-op: cap reads
        # instead, and keep the scanned files from evicting app pages.
        IOReadBandwidthMax = "/dev/mapper/cryptroot 80M";
        MemoryHigh = "1G";
      };
    };
  };
}
