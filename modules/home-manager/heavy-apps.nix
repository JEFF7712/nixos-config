{
  pkgs,
  lib,
  config,
  pkgs-stable,
  ...
}:

let
  cfg = config.heavy-apps;
in
{
  options.heavy-apps = {
    media.enable = lib.mkEnableOption "heavy media apps (DaVinci, OBS, VLC, ...)";
    office.enable = lib.mkEnableOption "heavy office apps (LibreOffice, GIMP, Bitwarden)";
    comms.enable = lib.mkEnableOption "heavy comms apps (Telegram, Slack, browsers, ...)";
    science.enable = lib.mkEnableOption "heavy science apps (OVITO, Avogadro)";
  };

  config = {
    home.packages =
      lib.optionals cfg.media.enable (
        with pkgs;
        [
          davinci-resolve
          obs-studio
          vlc
          avidemux
          feishin
          f3d
        ]
      )
      ++ lib.optionals cfg.office.enable (
        with pkgs;
        [
          libreoffice-qt-fresh
          bitwarden-desktop
          pkgs-stable.gimp2
        ]
      )
      ++ lib.optionals cfg.comms.enable (
        with pkgs;
        [
          telegram-desktop
          slack
          tor-browser
          google-chrome
          localsend
        ]
      )
      ++ lib.optionals cfg.science.enable (
        with pkgs;
        [
          ovito
          pkgs-stable.avogadro2
        ]
      );
  };
}
