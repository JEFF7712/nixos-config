{
  lib,
  config,
  ...
}:

{
  options.xhisper.enable = lib.mkEnableOption "xhisper-local config + popup symlinks";

  config = lib.mkIf config.xhisper.enable {
    xdg.configFile."xhisper".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/xhisper";

    xdg.configFile."quickshell-xhisper-popup".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/quickshell-xhisper-popup";
  };
}
