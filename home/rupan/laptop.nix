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
  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    papirus-icon-theme
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
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — symlink home/scripts/ into ~/.local/bin
  home.file.".local/bin" = {
    source = ../scripts;
    recursive = true;
    executable = true;
  };

  # Rofi configs (out-of-store so they're editable without rebuild)
  xdg.configFile."rofi".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/rofi";

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.fish.shellAliases.bnix = "cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push";

  qt.enable = true;
}
