{ pkgs, lib, config, ... }: {
  options.waybar.enable = lib.mkEnableOption "waybar status bar";

  config = lib.mkIf config.waybar.enable {
    programs.waybar = {
      enable = true;
    };  
    
  xdg.configFile."waybar".source = ../configs/waybar;
    
  };
}
