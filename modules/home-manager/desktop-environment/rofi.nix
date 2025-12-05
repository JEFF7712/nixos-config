{ pkgs, lib, config, ... }: {

  options.rofi.enable = lib.mkEnableOption "rofi";

  config = lib.mkIf config.rofi.enable {
    home.packages = [
      pkgs.rofi
    ];    

    xdg.configFile."rofi".source = ../configs/rofi;    
  };
}
