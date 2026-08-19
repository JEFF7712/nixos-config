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
    extraPathPackages = with pkgs; [
      findutils
      gawk
      gnused
      hyprlock
      jq
      niri
    ];
    # Stasis 1.5 on a laptop only uses default.ac / default.battery, and it
    # replaces any rune missing current knobs (e.g. monitor_media) with the
    # bootstrap plan (swaylock, no lid_close_action). Keep globals under
    # default: and the idle plan under ac:/battery:.
    extraConfig = ''
      default:
        enable_loginctl_integration true
        enable_dbus_inhibit true
        monitor_media true
        ignore_remote_media true
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
  noctalia.enable = true;
  programs.noctalia.settings = {
    desktopWidgets.monitorWidgets = [
      {
        name = "DP-7";
        widgets = [ ];
      }
      {
        name = "DP-6";
        widgets = [
          {
            id = "Clock";
            x = 740;
            y = 100;
            scale = 3;
            format = "h:mm AP\\nd MMMM yyyy";
            clockStyle = "minimal";
            showBackground = false;
            useCustomFont = false;
            customFont = "";
            usePrimaryColor = false;
          }
          {
            id = "MediaPlayer";
            x = 440;
            y = 420;
            scale = 2.834;
            hideMode = "visible";
            showBackground = false;
            visualizerType = "linear";
            visualizerVisibility = "always";
          }
          {
            id = "Weather";
            x = 580;
            y = 780;
            scale = 3;
            showBackground = false;
          }
        ];
      }
    ];
    location = {
      name = "Madison, WI";
      analogClockInCalendar = false;
      firstDayOfWeek = -1;
      showCalendarEvents = true;
      showCalendarWeather = true;
      showWeekNumberInCalendar = false;
      use12hourFormat = true;
      useFahrenheit = true;
      weatherEnabled = true;
      weatherShowEffects = true;
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
