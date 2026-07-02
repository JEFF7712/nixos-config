{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.atticPush.enable = lib.mkEnableOption "Attic homelab cache push service";

  config = lib.mkIf config.atticPush.enable {
    # `attic watch-store` tails additions to /nix/store and pushes them to the
    # configured cache. Once this service runs, anything you build locally —
    # `nix develop`, `nix build`, GC-then-rebuild — gets pre-warmed into the
    # homelab Attic cache so CI doesn't have to recompile it.

    home.packages = [ pkgs.attic-client ];

    # Client config incl. the push token comes from sops-nix (system module,
    # sops.secrets.attic-config-toml) so a fresh install needs no out-of-band
    # `attic login`. Requires secrets.enable on the host.
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
