{ pkgs, lib, config, ... }: {
  options.swww.enable = lib.mkEnableOption "swww wallpaper daemon";

  config = lib.mkIf config.swww.enable {
    home.packages = with pkgs; [
      swww
    ];

    systemd.user.services.swww = {
      Unit = {
        Description = "Wayland wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
    
    # Script to set a random wallpaper
    home.file.".local/bin/wallpaper-random" = {
      executable = true;
      text = ''
        #!/bin/sh
        if [ -d ~/media/images/wallpapers ]; then
          ${pkgs.swww}/bin/swww img $(find ~/media/images/wallpapers -type f | shuf -n 1) --transition-type grow --transition-pos 0.5,0.5 --transition-step 90
        fi
      '';
    };
  };
}
