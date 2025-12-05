{ pkgs, lib, config, ... }: {
  options.waypaper.enable = lib.mkEnableOption "waypaper gui";

  config = lib.mkIf config.waypaper.enable {
    home.packages = with pkgs; [
      waypaper
    ];
    
  };
}
