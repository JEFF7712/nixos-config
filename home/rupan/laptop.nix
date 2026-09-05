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
    # silent no-op, missing `noctalia-shell` made lock fail-open on that profile.
    extraPathPackages = [
      config.programs.noctalia.package
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

  home.packages = with pkgs; [
    ibm-plex
    inter
    noto-fonts
    source-sans-pro
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
    maple-mono-nf
  ];

  niri.enable = true;
  bluetooth.enable = true;
  noctalia.enable = true;
  programs.noctalia.settings = {
    location = {
      address = "Madison, WI";
    };
    shell = {
      time_format = "{:%-I:%M %p}";
    };
    weather = {
      enabled = true;
      refresh_minutes = 30;
      unit = "fahrenheit";
      effects = true;
    };
    control_center.calendar = {
      show_events_card = true;
      show_week_numbers = false;
    };
    desktop_widgets.widget = {
      dp6_clock = {
        type = "clock";
        output = "DP-6";
        cx = 740.0;
        cy = 100.0;
        settings = {
          clock_style = "digital";
          format = "{:%-I:%M %p}\n{:%-d %B %Y}";
          color = "on_surface";
        };
      };
      dp6_media = {
        type = "media_player";
        output = "DP-6";
        cx = 440.0;
        cy = 420.0;
        settings = {
          color = "on_surface";
          hide_when_no_media = false;
        };
      };
      dp6_weather = {
        type = "weather";
        output = "DP-6";
        cx = 580.0;
        cy = 780.0;
        settings = {
          color = "on_surface";
        };
      };
    };
  };
  terminal.enable = true;
  common-apps.enable = true;
  heavy-apps = {
    media.enable = true;
    office.enable = true;
    comms.enable = true;
    science.enable = true;
  };
  obsidian.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;
  ai-tools.enable = true;
  agentConfig.enable = true;
  vicinae.enable = true;
  dev.enable = true;
  xhisper.enable = true;
  systemHealthNotify.enable = true;
  pulseAgent.enable = false;
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — out-of-store symlinks into ~/.local/bin so edits apply without
  # rebuild and `readlink -f` resolves back into the repo (profile-common
  # derives REPO_HOME from it).
  home.file = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".local/bin/${name}" {
      source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/scripts/${name}";
      # New scripts get hand-made symlinks before the first rebuild that
      # manages them; overwrite instead of aborting activation.
      force = true;
    }
  ) (lib.filterAttrs (_: type: type == "regular") (builtins.readDir ../scripts));

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/hypr/hyprlock.conf";

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
