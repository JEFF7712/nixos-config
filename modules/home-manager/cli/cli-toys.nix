{ pkgs, lib, config, ... }:

{
  options.cli-toys.enable = lib.mkEnableOption "cli toys";

  config = lib.mkIf config.cli-toys.enable {
    home.packages = with pkgs; [
      fastfetch  
      cmatrix    
      pipes-rs      
      cbonsai    
      sl         
      cava
    ];
  };
}
