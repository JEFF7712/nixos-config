{
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [ inputs.asus-numberpad-driver.nixosModules.default ];

  options.asus-numpad.enable = lib.mkEnableOption "ASUS touchpad numpad overlay";

  config = lib.mkIf config.asus-numpad.enable {
    services.asus-numberpad-driver = {
      enable = true;
      # UX3404VC maps to this layout in upstream laptop_numberpad_layouts.
      layout = "up5401ea";
      wayland = true;
      waylandDisplay = "wayland-1";
      runtimeDir = "/run/user/1000/";
    };
  };
}
