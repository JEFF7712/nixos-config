{ pkgs, lib, config, ... }: {
  options.filemanager.enable = lib.mkEnableOption "thunar file manager";

  config = lib.mkIf config.filemanager.enable {
    programs.thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    services.gvfs.enable = true; 
    services.tumbler.enable = true; 
  };
}
