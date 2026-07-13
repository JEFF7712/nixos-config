{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.auto-update.enable = lib.mkEnableOption "weekly flake input update plus hourly AI tool updates";

  # Replaces system.autoUpgrade, which is channel-based unless given a flake
  # and whose documented --update-input flags were removed from Nix >= 2.22.
  # The lock update and commit run as rupan so the repo never collects
  # root-owned files; only the rebuild itself runs as root.
  config = lib.mkIf config.auto-update.enable {
    # Shared advisory lock: the two auto-update services AND `just switch`
    # (justfile) all flock this before rebuilding, so no two full builds ever
    # run at once. Two concurrent builds OOM the ~31G box (see CLAUDE.md).
    # 0664 root:users lets unprivileged `just switch` open it (rupan ∈ users).
    systemd.tmpfiles.rules = [ "f /run/nixos-auto-update.lock 0664 root users -" ];

    systemd.services.nixos-auto-update = {
      description = "Update flake inputs, commit lock file, and rebuild";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        config.nix.package
        pkgs.git
        pkgs.util-linux
        pkgs.coreutils
        pkgs.bash
      ];
      serviceConfig = {
        Type = "oneshot";
        # Persistent= catch-up fires right after boot/resume; don't let the
        # rebuild starve the interactive session. Caps match ~31G RAM /
        # 20-thread i9: leave ~8G for the desktop, use most of the rest.
        Nice = 15;
        IOSchedulingClass = "idle";
        CPUQuota = "1200%";
        MemoryHigh = "18G";
        MemoryMax = "22G";
        TasksMax = 1024;
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
        if runuser -u rupan -- git -C "$repo" diff --quiet -- flake.lock; then
          echo "flake.lock unchanged; skipping rebuild"
          exit 0
        fi
        # Defer a toolchain-cascade bump: eval passes but the closure would
        # rebuild stdenv/glibc and everything downstream from source (uncached
        # nixpkgs tip). Revert and let a later run retry once hydra has cached
        # it, rather than grind for hours. See CLAUDE.md / nix-cascade-guard.
        rc=0
        runuser -u rupan -- "$repo/home/scripts/nix-cascade-guard" \
          "path:$repo#nixosConfigurations.laptop.config.system.build.toplevel" || rc=$?
        if [ "$rc" = 10 ]; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "deferred: nixpkgs bump not yet cached (toolchain cascade); lock reverted, will retry next run" >&2
          exit 0
        elif [ "$rc" != 0 ]; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "cascade-guard error (rc=$rc); lock reverted" >&2
          exit 1
        fi
        runuser -u rupan -- git -C "$repo" commit -m "flake.lock: weekly auto-update" -- flake.lock
        ${lib.getExe pkgs.nixos-rebuild} switch --flake "path:$repo#laptop" \
          --option max-jobs 2 --option cores 8
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
        pkgs.bash
      ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 15;
        IOSchedulingClass = "idle";
        CPUQuota = "1200%";
        MemoryHigh = "18G";
        MemoryMax = "22G";
        TasksMax = 1024;
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
        # Upstream AI flakes sometimes ship a version bump before hashes land
        # (e.g. codex-cli code-mode-host). Soft-defer like cascade-guard so the
        # hourly timer doesn't spam failure notifications; retry next hour.
        if ! runuser -u rupan -- nix eval --no-write-lock-file \
            "path:$repo#nixosConfigurations.laptop.config.system.build.toplevel.drvPath" >/dev/null; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "deferred: updated AI tool inputs fail eval; flake.lock reverted, will retry next run" >&2
          exit 0
        fi
        if runuser -u rupan -- git -C "$repo" diff --quiet -- flake.lock; then
          echo "AI tool flake.lock unchanged; skipping rebuild"
          exit 0
        fi
        # See the weekly service: defer an uncached toolchain-cascade bump
        # instead of rebuilding the world from source.
        rc=0
        runuser -u rupan -- "$repo/home/scripts/nix-cascade-guard" \
          "path:$repo#nixosConfigurations.laptop.config.system.build.toplevel" || rc=$?
        if [ "$rc" = 10 ]; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "deferred: input bump not yet cached (toolchain cascade); lock reverted, will retry next run" >&2
          exit 0
        elif [ "$rc" != 0 ]; then
          runuser -u rupan -- git -C "$repo" checkout -- flake.lock
          echo "cascade-guard error (rc=$rc); lock reverted" >&2
          exit 1
        fi
        runuser -u rupan -- git -C "$repo" commit -m "flake.lock: ai tools auto-update" -- flake.lock
        ${lib.getExe pkgs.nixos-rebuild} switch --flake "path:$repo#laptop" \
          --option max-jobs 2 --option cores 8
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
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
