{ pkgs, lib, config, ... }: {
  options.swaylock.enable = lib.mkEnableOption "swaylock";

  config = lib.mkIf config.swaylock.enable {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        screenshots = true;
        indicator = true;
	effect-scale = 0.5;  
        effect-blur = "7x5";
        effect-vignette = "0.5:0.5";
  	indicator-radius = 160; 
  	indicator-thickness = 20; 
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
