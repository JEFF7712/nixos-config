{ pkgs, lib, config, ... }: {

  options = {
    niri.enable = lib.mkEnableOption "user niri config"; 
  };

  config = lib.mkIf config.niri.enable {

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard
    ];

  xdg.configFile."niri/config.kdl".source = ../configs/niri/config.kdl;
  };
}
