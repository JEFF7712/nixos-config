{ pkgs, lib, config, ... }: {
  options.ctls.enable = lib.mkEnableOption "ctls";

  config = lib.mkIf config.ctls.enable {
    environment.systemPackages = [
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.dualsensectl      
    ]; 
  };
}
