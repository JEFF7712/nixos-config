{ config }:

let
  userServices = config.home-manager.users.rupan.systemd.user.services;
  userTimers = config.home-manager.users.rupan.systemd.user.timers;
in
assert !config.services.openssh.enable;
assert config.services.smartd.enable;
assert config.services.smartd.autodetect;
assert config.services.smartd.notifications.systembus-notify.enable;
assert userServices ? system-update-failure-notify;
assert userTimers ? system-update-failure-notify;
assert userTimers.system-update-failure-notify.Install.WantedBy == [ "graphical-session.target" ];
true
