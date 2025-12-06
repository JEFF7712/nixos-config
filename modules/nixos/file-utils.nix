{ pkgs, lib, config, ... }: {
  options.file-utils.enable = lib.mkEnableOption "file utils";

  config = lib.mkIf config.file-utils.enable {
    
    environment.systemPackages = [
      pkgs.unzip
    ];

  };
}
