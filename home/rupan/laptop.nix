{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./home.nix
    (inputs.import-tree ../../modules/home-manager)
    inputs.stasis.homeModules.default
  ];

  services.stasis = {
    enable = true;
    # Stasis PATH is only this list; missing `stasis` made lid-close inhibit a
    # silent no-op.
    extraPathPackages = [
      config.services.stasis.package
    ]
    ++ (with pkgs; [
      findutils
      gawk
      gnused
      hyprlock
      jq
      niri
      procps # pgrep, for lid-close-action's lock barrier
    ]);
    # Stasis 1.5 only uses default.ac / default.battery; missing knobs get the
    # bootstrap plan (swaylock, no lid_close_action).
    extraConfig = ''
      default:
        enable_loginctl_integration true
        enable_dbus_inhibit true
        monitor_media true
        ignore_remote_media true
        # Empty: browser autoplay is idle-inhibit, not stay-awake.
        suspend_inhibit_media [ ]
        inhibit_apps [
          "vlc"
          "mpv"
          r"steam_app_.*"
        ]
        suspend_inhibit_apps [ ]
        prepare_sleep_command "/home/rupan/.local/bin/lock-screen"
        lid_close_action "/home/rupan/.local/bin/lid-close-action"
        ac:
          lock_screen:
            timeout 300
            command "/home/rupan/.local/bin/lock-screen"
          end
          suspend:
            timeout 600
            command "systemctl suspend"
          end
        end
        battery:
          lock_screen:
            timeout 120
            command "/home/rupan/.local/bin/lock-screen"
          end
          suspend:
            timeout 180
            command "systemctl suspend"
          end
        end
      end
    '';
  };

  # The daemon once exited 0 on an I/O error and stayed dead:
  # Restart=on-failure ignores clean exits, which silently broke the bar
  # inhibit switch and auto-lock. Always restart; explicit target stops
  # on logout are still honored, but `stasis stop` while logged in will
  # be restarted.
  systemd.user.services.stasis.Service = {
    Restart = lib.mkForce "always";
    RestartSec = 2;
  };

  # Stasis can deadlock after a child crash (hyprlock segfault leaves the
  # daemon's IPC loop stuck on a futex). The process stays alive so
  # Restart=always never fires. This watchdog pings `stasis info` every 60 s
  # and restarts the service when it times out, recovering in ≤ 1 minute.
  systemd.user.services.stasis-watchdog = {
    Unit = {
      Description = "Stasis liveness watchdog";
      PartOf = [ "stasis.service" ];
      After = [ "stasis.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "stasis-watchdog" ''
          if ! timeout 5 stasis info >/dev/null 2>&1; then
            echo "stasis unresponsive, restarting" >&2
            systemctl --user restart stasis.service
          fi
        ''
      );
    };
  };
  systemd.user.timers.stasis-watchdog = {
    Unit = {
      Description = "Stasis liveness watchdog timer";
      PartOf = [ "stasis.service" ];
    };
    Timer = {
      OnActiveSec = "60s";
      OnUnitActiveSec = "60s";
    };
    Install.WantedBy = [ "stasis.service" ];
  };

  home.packages = with pkgs; [
    ibm-plex
    inter
    noto-fonts
    source-sans-pro
    cm_unicode
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    papirus-icon-theme
    colloid-icon-theme
    hyprlock
    tela-icon-theme
    whitesur-icon-theme
    maple-mono.NF
  ];

  niri.enable = true;
  quickshell.enable = true;
  bluetooth.enable = true;
  hass.enable = true;
  matrix-playback.enable = true;
  terminal.enable = true;
  nixvim.enable = true;
  common-apps.enable = true;
  heavy-apps = {
    media.enable = true;
    office.enable = true;
    comms.enable = true;
    science.enable = true;
  };
  obsidian.enable = true;
  streamcontroller.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;
  ai-tools.enable = true;
  agentConfig.enable = true;
  vicinae.enable = true;
  dev.enable = true;
  systemHealthNotify.enable = true;
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — out-of-store symlinks into ~/.local/bin so edits apply without
  # rebuild and `readlink -f` resolves back into the repo (profile-common
  # derives REPO_HOME from it). Root-only system unit helpers stay off user PATH.
  home.file =
    let
      systemOnlyScripts = [
        "homelab-network-event"
        "preserve-management-profile"
        "prune-old-roots"
      ];
    in
    lib.mapAttrs'
      (
        name: _:
        lib.nameValuePair ".local/bin/${name}" {
          source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/scripts/${name}";
          # New scripts get hand-made symlinks before the first rebuild that
          # manages them; overwrite instead of aborting activation.
          force = true;
        }
      )
      (
        lib.filterAttrs (name: type: type == "regular" && !builtins.elem name systemOnlyScripts) (
          builtins.readDir ../scripts
        )
      );

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/hypr/hyprlock.conf";

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
