{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.hass.enable = lib.mkEnableOption "Home Assistant Quickshell bridge (hass-bridge + secret-tool)";

  config = lib.mkIf config.hass.enable {
    home.packages = with pkgs; [
      hass-bridge
      libsecret
    ];
  };
}
