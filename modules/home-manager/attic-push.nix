{
  pkgs,
  lib,
  config,
  ...
}:

{
  # `attic watch-store` tails additions to /nix/store and pushes them to the
  # configured cache. Setup is one-time: `attic login homelab http://... <token>`
  # (already done out-of-band; token lives in ~/.config/attic/config.toml).
  # Once this service runs, anything you build locally — `nix develop`,
  # `nix build`, GC-then-rebuild — gets pre-warmed into the homelab Attic
  # cache so CI doesn't have to recompile it.

  home.packages = [ pkgs.attic-client ];

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
      # Keep memory bounded — Attic chunks paths in-process.
      MemoryHigh = "512M";
      MemoryMax = "1G";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
