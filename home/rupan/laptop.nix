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
    ];
    extraConfig = ''
      default:
        enable_loginctl true
        enable_dbus_inhibit false
        prepare_sleep_command "/home/rupan/.local/bin/lock-screen"
        lid_close_action "/home/rupan/.local/bin/lock-screen & sleep 1; systemctl suspend"
        lock_screen:
          timeout 300
          command "/home/rupan/.local/bin/lock-screen"
        end
        suspend:
          timeout 600
          command "systemctl suspend"
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
    colloid-icon-theme
    hyprlock
    tela-icon-theme
    whitesur-icon-theme
  ];

  niri.enable = true;
  noctalia.enable = true;
  terminal.enable = true;
  common-apps.enable = true;
  heavy-apps.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;
  ai-tools.enable = true;
  agentConfig.enable = true;
  dev.enable = true;
  xhisper.enable = true;
  pulseAgent.enable = false;
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — symlink home/scripts/ into ~/.local/bin
  home.file.".local/bin" = {
    source = ../scripts;
    recursive = true;
    executable = true;
  };

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/hypr/hyprlock.conf";

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
