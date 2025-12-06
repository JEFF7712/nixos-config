{ pkgs, lib, config, ... }: {
  options.swaylock.enable = lib.mkEnableOption "swaylock";

  config = lib.mkIf config.swaylock.enable {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        clock = true;
        datestr = "%a, %B %e";
        timestr = "%k:%M";
        screenshots = true;
        fade-in = 0.2;
      
        # Visual Ring Config
        indicator = true;
        indicator-radius = 100;
        indicator-thickness = 7;
        effect-blur = "7x5";
        effect-vignette = "0.5:0.5";
        ring-color = "3b4252";
        key-hl-color = "88c0d0";
      };
    };

    services.swayidle = {
      enable = true;
      events = [
        { event = "before-sleep"; command = "${pkgs.swaylock-effects}/bin/swaylock -fF"; }
        { event = "lock"; command = "${pkgs.swaylock-effects}/bin/swaylock -fF"; }
      ];
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
  };
}
