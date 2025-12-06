{ pkgs, lib, config, ... }: {
  options.bitwarden-cli.enable = lib.mkEnableOption "bitwarden-cli";

  config = lib.mkIf config.bitwarden-cli.enable {
    home.packages = with pkgs; [
      bitwarden-cli    
    ];
  };
}
