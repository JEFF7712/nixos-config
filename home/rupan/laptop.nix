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
    papirus-icon-theme
    colloid-icon-theme
    hyprlock
    tela-icon-theme
    whitesur-icon-theme
    maple-mono-nf
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
  serena.enable = true;
  dev.enable = true;
  xhisper.enable = true;
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
  ) (builtins.readDir ../scripts);

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/hypr/hyprlock.conf";

  # matugen templates + config for the wallpaper-driven `tinted` profile.
  # Out-of-store so template edits re-theme on the next wallpaper change with
  # no rebuild. apply_wallpaper_theme invokes matugen against this config.
  xdg.configFile."matugen".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/matugen";

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
