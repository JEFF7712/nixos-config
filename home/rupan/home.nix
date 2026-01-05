{ config, pkgs, ... }:

{
  home.username = "rupan";
  home.homeDirectory = "/home/rupan";
  home.stateVersion = "25.11";

  home.sessionVariables.EDITOR = "nano";

  programs.home-manager.enable = true;
}
