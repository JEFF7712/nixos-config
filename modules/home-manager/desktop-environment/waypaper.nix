{ pkgs, lib, config, ... }: {
  options.waypaper.enable = lib.mkEnableOption "waypaper gui";

  config = lib.mkIf config.waypaper.enable {
    home.packages = with pkgs; [
      waypaper
    ];

    systemd.user.services.wallpaper-cycler = {
      Unit = {
        Description = "Cycle wallpaper randomly using waypaper";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.waypaper}/bin/waypaper --random";
      };
    };

    systemd.user.timers.wallpaper-cycler = {
      Unit = {
        Description = "Timer to cycle wallpaper every hour";
      };
      Timer = {
        OnBootSec = "5m"; 
        OnUnitActiveSec = "1h"; 
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
