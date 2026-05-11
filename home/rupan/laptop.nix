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
    extraConfig = ''
      default:
        lock_screen:
          timeout 300
          command "lock-screen"
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
    papirus-icon-theme
    swaylock-effects
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
  dev.enable = true;
  pulseAgent.enable = false;
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — symlink home/scripts/ into ~/.local/bin
  home.file.".local/bin" = {
    source = ../scripts;
    recursive = true;
    executable = true;
  };

  # Rofi configs (out-of-store so they're editable without rebuild)
  xdg.configFile."rofi".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/rofi";

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
