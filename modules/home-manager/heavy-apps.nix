{ pkgs, lib, config, pkgs-stable, ... }:

{
  options.heavy-apps.enable = lib.mkEnableOption "heavy-apps";

  config = lib.mkIf config.heavy-apps.enable {

    home.packages = with pkgs; [
      davinci-resolve
      bitwarden-desktop
      libreoffice-qt-fresh  
      netflix
      obs-studio
      localsend
      tor-browser
      feishin
      gimp2
      vlc
      avidemux
      telegram-desktop
      antigravity
      obsidian
      ovito
      pkgs-stable.avogadro2
      slack
      blender
      f3d
      google-chrome
    ];
  };
}
