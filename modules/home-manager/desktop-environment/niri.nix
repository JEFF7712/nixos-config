{ pkgs, lib, config, ... }: {

  options = {
    niri.enable = lib.mkEnableOption "user niri config"; 
  };

  config = lib.mkIf config.niri.enable {

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard
      rofi
      swww
      waypaper
    ];

    services.mako = {
      enable = true;
      settings = {
        font = "JetBrains Mono 10"; 
        "background-color" = "#101010cc";
        "text-color" = "#eeeeeecc";
        "border-color" = "#303030cc";
        "border-size" = 1;
        "border-radius" = 3;
        width = 400;
        height = 125;
        margin = "10";
        padding = "15";
        "default-timeout" = 5000;
        layer = "overlay";
        anchor = "top-right";
	      "output=DP-1" = {
          width = 500;
	        height = 150;
          font = "JetBrains Mono 12";
        };
      };
    };

    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        screenshots = true;
        indicator = true;
	      effect-scale = 0.5;  
        effect-blur = "7x4";
        effect-vignette = "0.1:0.3";
        indicator-radius = 100; 
        indicator-thickness = 10; 
        inside-color = "00000000"; 
        inside-clear-color = "00000000"; 
        inside-ver-color = "00000000"; 
        inside-wrong-color = "00000000"; 
        key-hl-color = "ffffff"; 
        bs-hl-color = "ffffff"; 
        ring-color = "101010"; 
        ring-wrong-color = "c50000"; 
        ring-ver-color = "1db954"; 
        line-uses-ring = true; 
        line-color = "00000000"; 
        font = "JetBrainsMono Nerd Font"; 
        font-size = 40;  	
        text-color = "00000000"; 
        text-clear-color = "00000000"; 
        text-wrong-color = "00000000"; 
        text-ver-color = "00000000"; 
        separator-color = "00000000"; 
      };
    };

    services.swayidle = {
      enable = true;
      events = {
        before-sleep = "${pkgs.swaylock-effects}/bin/swaylock -fF";
        lock = "${pkgs.swaylock-effects}/bin/swaylock -fF";
      };
      timeouts = [
        { 
          timeout = 300; 
          command = "${pkgs.swaylock-effects}/bin/swaylock -fF"; 
        }
        {
          timeout = 600;
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
    };

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
    
    home.file.".local/bin/wallpaper-random" = {
      executable = true;
      text = ''
        #!/bin/sh
        if [ -d ~/media/images/wallpapers ]; then
          ${pkgs.swww}/bin/swww img $(find ~/media/images/wallpapers -type f | shuf -n 1) --transition-type fade --transition-pos 0.5,0.5 --transition-step 90
        fi
      '';
    };

    programs.waybar = {
      enable = true;
    };  

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
    
    xdg.configFile."waybar".source = ../configs/waybar;
    xdg.configFile."niri/config.kdl".source = ../configs/niri/config.kdl;
    xdg.configFile."rofi".source = ../configs/rofi;

  };
}
