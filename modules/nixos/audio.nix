{ pkgs, lib, config, ... }:

{
  options.audio.enable = lib.mkEnableOption "audio";

  config = lib.mkIf config.audio.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    environment.systemPackages = [ pkgs.pavucontrol ];
  };
}