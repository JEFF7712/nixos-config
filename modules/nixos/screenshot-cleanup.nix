{ lib, config, ... }:

{
  options.screenshot-cleanup.enable = lib.mkEnableOption "automatic screenshot cleanup";

  config = lib.mkIf config.screenshot-cleanup.enable {
    systemd.tmpfiles.rules = [
      "e /home/rupan/media/images/screenshots - - - 30d"
    ];
  };
}
