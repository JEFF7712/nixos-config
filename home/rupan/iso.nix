{
  pkgs,
  inputs,
  lib,
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
  cli-toys.enable = true;
  cli-tools.enable = true;
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — symlink home/scripts/ into ~/.local/bin
  home.file.".local/bin" = {
    source = ../scripts;
    recursive = true;
    executable = true;
  };

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
