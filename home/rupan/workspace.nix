{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

{
  home.username = "developer";
  home.homeDirectory = "/home/developer";
  home.stateVersion = "25.11";

  home.sessionVariables.EDITOR = "nvim";
  programs.home-manager.enable = true;

  imports = [
    ../../modules/home-manager/repo-path.nix
    ../../modules/home-manager/terminal.nix
    ../../modules/home-manager/dev.nix
    ../../modules/home-manager/cli/cli-tools.nix
  ];

  terminal.enable = true;
  dev.enable = true;
  cli-tools.enable = true;
}
