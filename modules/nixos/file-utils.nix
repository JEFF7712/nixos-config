{ pkgs, lib, config, ... }:

{
  options.file-utils.enable = lib.mkEnableOption "file utils";

  config = lib.mkIf config.file-utils.enable {
    environment.systemPackages = with pkgs; [
      unzip
      libimobiledevice
      ifuse
    ];

    services.usbmuxd.enable = true;
  };
}
