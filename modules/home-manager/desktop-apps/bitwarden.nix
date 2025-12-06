{ pkgs, lib, config, ... }: {
  options.bitwarden.enable = lib.mkEnableOption "bitwarden desktop";

  config = lib.mkIf config.bitwarden.enable {
    home.packages = with pkgs; [
      bitwarden-desktop    
    ];
  };
}
