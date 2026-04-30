{
  pkgs,
  lib,
  config,
  pkgs-stable,
  ...
}:

{
  options.heavy-apps.enable = lib.mkEnableOption "heavy-apps";

  config = lib.mkIf config.heavy-apps.enable {

    home.packages = with pkgs; [
      davinci-resolve
      bitwarden-desktop
      libreoffice-qt-fresh
      obs-studio
      localsend
      tor-browser
      feishin
      pkgs-stable.gimp2
      vlc
      avidemux
      telegram-desktop
      obsidian
      ovito
      pkgs-stable.avogadro2
      slack
      f3d
      google-chrome
    ];
  };
}
