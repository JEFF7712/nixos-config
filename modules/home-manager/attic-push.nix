# Disabled while the homelab is offline (see substituter block in hosts/laptop/base.nix).
{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.atticPush.enable = lib.mkEnableOption "Attic homelab cache push service";

  config = lib.mkIf config.atticPush.enable {
    # Push local /nix/store additions to the homelab Attic cache.

    home.packages = [ pkgs.attic-client ];

    # Token from sops (sops.secrets.attic-config-toml); needs secrets.enable.
    xdg.configFile."attic/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "/run/secrets/attic-config-toml";

    systemd.user.services.attic-watch-store = {
      Unit = {
        Description = "Attic: push new /nix/store additions to the homelab cache";
        # Network is only required for actual push; the daemon itself doesn't
        # block on it (it just retries), so we don't need NetworkManager
        # dependencies here.
      };
      Service = {
        ExecStart = "${pkgs.attic-client}/bin/attic watch-store homelab";
        Restart = "on-failure";
        RestartSec = 30;
        # Keep memory bounded — Attic chunks in-process.
        MemoryHigh = "512M";
        MemoryMax = "1G";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
