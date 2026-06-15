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
      Allow the desktop user to pause the nixos auto-update timer while the
      runtime focus/performance mode is active, via a scoped polkit rule
      (no sudo, no password), so a background rebuild can't tank a session.
    '';
  };

  config = lib.mkIf config.focusMode.enable {
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "rupan") {
          var unit = action.lookup("unit");
          if (unit == "nixos-auto-update.timer") {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };
}
