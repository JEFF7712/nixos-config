{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.auto-update.enable = lib.mkEnableOption "weekly flake input update plus daily AI tool updates";

  # Replaces system.autoUpgrade, which is channel-based unless given a flake
  # and whose documented --update-input flags were removed from Nix >= 2.22.
  # The lock update and commit run as rupan so the repo never collects
  # root-owned files; only the rebuild itself runs as root.
  config = lib.mkIf config.auto-update.enable {
    systemd.services.nixos-auto-update = {
      description = "Update flake inputs, commit lock file, and rebuild";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        config.nix.package
        pkgs.git
        pkgs.util-linux
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        # Persistent= catch-up fires right after boot/resume; don't let the
        # rebuild starve the interactive session.
        Nice = 10;
        IOSchedulingClass = "idle";
      };
      script = ''
        repo=/home/rupan/nixos
        exec 9>/run/nixos-auto-update.lock
        flock -n 9 || exit 0
        # network-online.target can be reached before DNS actually resolves
        # (Persistent= catch-up runs right after boot/resume); wait for it.
        for _ in $(seq 60); do
          ${pkgs.getent}/bin/getent hosts api.github.com >/dev/null 2>&1 && break
          sleep 5
        done
        runuser -u rupan -- nix flake update --flake "path:$repo"
        # Gate on eval before committing or switching: a broken unstable bump
        # should revert the lock and fail loudly, not break the rebuild.
        if ! runuser -u rupan -- nix eval --no-write-lock-file \
            "path:$repo#nixosConfigurations.laptop.config.system.build.toplevel.drvPath" >/dev/null; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "updated inputs fail eval; flake.lock reverted" >&2
          exit 1
        fi
        if ! runuser -u rupan -- git -C "$repo" diff --quiet -- flake.lock; then
          runuser -u rupan -- git -C "$repo" commit -m "flake.lock: weekly auto-update" -- flake.lock
        fi
        ${lib.getExe pkgs.nixos-rebuild} switch --flake "path:$repo#laptop"
      '';
    };

    systemd.services.nixos-ai-tools-auto-update = {
      description = "Update AI tool flake inputs, commit lock file, and rebuild";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        config.nix.package
        pkgs.git
        pkgs.util-linux
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
      script = ''
        repo=/home/rupan/nixos
        exec 9>/run/nixos-auto-update.lock
        flock -n 9 || exit 0
        for _ in $(seq 60); do
          ${pkgs.getent}/bin/getent hosts api.github.com >/dev/null 2>&1 && break
          sleep 5
        done
        runuser -u rupan -- nix flake update --flake "path:$repo" \
          claude-code-nix codex-cli-nix code-cursor-nix
        if ! runuser -u rupan -- nix eval --no-write-lock-file \
            "path:$repo#nixosConfigurations.laptop.config.system.build.toplevel.drvPath" >/dev/null; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "updated AI tool inputs fail eval; flake.lock reverted" >&2
          exit 1
        fi
        if ! runuser -u rupan -- git -C "$repo" diff --quiet -- flake.lock; then
          runuser -u rupan -- git -C "$repo" commit -m "flake.lock: daily ai tools auto-update" -- flake.lock
        fi
        ${lib.getExe pkgs.nixos-rebuild} switch --flake "path:$repo#laptop"
      '';
    };

    systemd.timers.nixos-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    systemd.timers.nixos-ai-tools-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
