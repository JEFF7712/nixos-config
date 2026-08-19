{
  lib,
  config,
  ...
}:

let
  cfg = config.focusMode;
in
{
  options.focusMode = {
    enable = lib.mkEnableOption "a scoped polkit rule letting the desktop user start or stop the NixOS auto-update timer while focus/performance mode is active, so a background rebuild cannot tank a session";

    user = lib.mkOption {
      type = lib.types.str;
      default = "rupan";
      description = "Desktop user granted the scoped polkit rule for auto-update units.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == ${builtins.toJSON cfg.user}) {
          var unit = action.lookup("unit");
          var verb = action.lookup("verb");
          if (unit == "nixos-auto-update.timer" &&
              (verb == "start" || verb == "stop")) {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };
}
