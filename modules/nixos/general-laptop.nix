{
  lib,
  config,
  ...
}:

{
  options.general-laptop.enable = lib.mkEnableOption "enables general laptop utils";

  config = lib.mkIf config.general-laptop.enable {
    services.libinput.enable = true;
    # Thunderbolt authorization; without boltd a dock sits unauthorized.
    services.hardware.bolt.enable = true;
  };
}
