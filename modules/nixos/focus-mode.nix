{
  lib,
  config,
  ...
}:

{
  options.focusMode.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Allow the desktop user to pause or stop NixOS auto-update timers and
      services while focus/performance mode is active, via a scoped polkit
      rule (no sudo, no password), so a background rebuild can't tank a session.
    '';
  };

  config = lib.mkIf config.focusMode.enable {
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "rupan") {
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
