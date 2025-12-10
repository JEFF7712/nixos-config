{ pkgs, lib, config, ... }: {
  options.notion.enable = lib.mkEnableOption "notion";

  config = lib.mkIf config.notion.enable {
    home.packages = with pkgs; [
      notion
    ];  
  };
}
