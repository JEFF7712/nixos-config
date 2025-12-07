{ pkgs, lib, config, ... }: {

  options.mako.enable = lib.mkEnableOption "mako";

  config = lib.mkIf config.mako.enable {
    services.mako = {
      enable = true;
      
      font = "JetBrains Mono 10"; 
 
      settings = {
        "background-color" = "#1e1e2e";
        "text-color" = "#cdd6f4";
        "border-color" = "#89b4fa";
        "border-size" = 2;
        "border-radius" = 5;
        width = 300;
        height = 150;
        margin = "10";
        padding = "15";
        "default-timeout" = 5000;
        layer = "overlay";
        anchor = "top-right";
      };
    };
  };
}
