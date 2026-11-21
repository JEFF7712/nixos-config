{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.matrix-playback.enable = lib.mkEnableOption "push Spotify MPRIS playback state to the LED matrix over WebSocket";

  config = lib.mkIf config.matrix-playback.enable {
    systemd.user.services.matrix-playback = {
      Unit = {
        Description = "Push Spotify playback state to the LED matrix";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.matrix-playback;
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.playerctl ]}" ];
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
