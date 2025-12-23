{ config, pkgs, ... }:

{
  home.username = "rupan";
  home.homeDirectory = "/home/rupan";
  home.stateVersion = "25.11"; 
  home.packages = [
    
  ];

  home.file = {
  };

  home.sessionVariables = {
    EDITOR = "nano";
  };

  programs.home-manager.enable = true;
}
