{ pkgs, lib, config, ... }: {
  options.localsend.enable = lib.mkEnableOption "local send";

  config = lib.mkIf config.localsend.enable {
    home.packages = with pkgs; [
      localsend    
    ];
  };
}
