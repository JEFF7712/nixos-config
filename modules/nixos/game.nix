{ pkgs, lib, config, ... }: {

  options.game.enable = lib.mkEnableOption "game";
  config = lib.mkIf config.game.enable {

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    programs.gamemode.enable = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      package = pkgs.steam.override {
        extraArgs = "-system-composer";
      };
    };
    
    programs.xwayland.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      lutris
      heroic
      wineWowPackages.staging
      xwayland-satellite
    ];
  };
}
