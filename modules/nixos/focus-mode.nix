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
    enable = lib.mkEnableOption "a scoped polkit rule letting the desktop user pause or stop NixOS auto-update timers while focus/performance mode is active, so a background rebuild cannot tank a session";

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
          if (unit == "nixos-auto-update.timer" ||
              unit == "nixos-auto-update.service" ||
              unit == "nixos-ai-tools-auto-update.timer" ||
              unit == "nixos-ai-tools-auto-update.service") {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };
}
