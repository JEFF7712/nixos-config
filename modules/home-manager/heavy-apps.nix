{ pkgs, lib, config, ... }: {

  options.heavy-apps.enable = lib.mkEnableOption "heavy-apps";
  config = lib.mkIf config.heavy-apps.enable {

    home.packages = with pkgs; [
      davinci-resolve
      bitwarden-desktop
      libreoffice-qt-fresh  
      netflix
      chromium
      obs-studio
      localsend
      tor-browser
      feishin
      aonsoku
      gimp2
      vlc
      avidemux
    ];
  };
}
