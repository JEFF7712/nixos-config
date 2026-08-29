{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:

let
  driverPackage = inputs.asus-numberpad-driver.packages.${pkgs.stdenv.hostPlatform.system}.default;
  numberpad = config.services.asus-numberpad-driver;
  stateDirectory = "/var/lib/asus-numberpad-driver";
  waylandSocket = "${numberpad.runtimeDir}${numberpad.waylandDisplay}";
in
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

    systemd.services.asus-numberpad-driver = {
      wantedBy = lib.mkForce [ ];
      preStart = ''
        if [[ ! -e ${stateDirectory}/numberpad_dev ]]; then
          install --mode=0644 /etc/asus-numberpad-driver/numberpad_dev ${stateDirectory}/numberpad_dev
        fi
      '';
      serviceConfig = {
        StateDirectory = "asus-numberpad-driver";
        ExecCondition = "${pkgs.coreutils}/bin/test -S ${waylandSocket}";
        ExecStart = lib.mkForce "${driverPackage}/share/asus-numberpad-driver/numberpad.py ${numberpad.layout} ${stateDirectory}/";
      };
    };

    systemd.paths.asus-numberpad-driver = {
      wantedBy = [ "paths.target" ];
      pathConfig.PathExists = waylandSocket;
    };
  };
}
