{
  lib,
  config,
  ...
}:

{
  options.xhisper.enable = lib.mkEnableOption "xhisper-local config + streaming overlay symlinks";

  config = lib.mkIf config.xhisper.enable {
    xdg.configFile."xhisper".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/xhisper";

    xdg.configFile."quickshell-xhisper".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/quickshell-xhisper";
  };
}
