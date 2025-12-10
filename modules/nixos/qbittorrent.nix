{ pkgs, lib, config, ... }: {
  options.qbittorrent.enable = lib.mkEnableOption "qbittorrent";

  config = lib.mkIf config.qbittorrent.enable {
    services.qbittorrent.enable = true;
  };
}
