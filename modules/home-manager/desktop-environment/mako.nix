{ pkgs, lib, config, ... }: {

  options.mako.enable = lib.mkEnableOption "mako";

  config = lib.mkIf config.mako.enable {
    services.mako = {
      enable = true;
      
      font = "JetBrains Mono 10"; 
 
      settings = {
        "background-color" = "#101010cc";
        "text-color" = "#eeeeeecc";
        "border-color" = "#303030cc";
        "border-size" = 1;
        "border-radius" = 3;
        width = 300;
        height = 150;
        margin = "10";
        padding = "15";
        "default-timeout" = 5000;
        layer = "overlay";
        anchor = "top-right";
	"output=DP-1" = {
          width = 400;
          font = "JetBrains Mono 12";
        };
      };
    };
  };
}
