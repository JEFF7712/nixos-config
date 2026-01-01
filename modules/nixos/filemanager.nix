{ pkgs, lib, config, ... }: {
  options.filemanager.enable = lib.mkEnableOption "thunar file manager";

  config = lib.mkIf config.filemanager.enable {
    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    programs.xfconf.enable = true;
    services.gvfs.enable = true; 
    services.tumbler.enable = true; 

    xdg.mime.defaultApplications = {
      "inode/directory" = "thunar.desktop";
    };
  };
}
