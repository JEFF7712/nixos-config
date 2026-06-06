{
  lib,
  config,
  ...
}:

{
  options.xhisper.enable = lib.mkEnableOption "xhisper-local config symlink";

  config = lib.mkIf config.xhisper.enable {
    xdg.configFile."xhisper".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/xhisper";
  };
}
