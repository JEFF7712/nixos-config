{ config }:

let
  preservedFiles = map (entry: entry.file) config.preservation.preserveAt."/persist".files;
  userServices = config.home-manager.users.rupan.systemd.user.services;
  userTimers = config.home-manager.users.rupan.systemd.user.timers;
in
assert !config.services.openssh.enable;
assert config.services.smartd.enable;
assert config.services.smartd.autodetect;
assert config.services.smartd.notifications.systembus-notify.enable;
assert config.services.userborn.enable;
assert config.services.userborn.passwordFilesLocation == "/persist/etc";
assert !builtins.elem "/etc/shadow" preservedFiles;
assert !builtins.elem "/etc/gshadow" preservedFiles;
assert config.environment.etc.subuid.text == "rupan:100000:65536\n";
assert config.environment.etc.subgid.text == "rupan:100000:65536\n";
assert userServices ? system-update-failure-notify;
assert userTimers ? system-update-failure-notify;
assert userTimers.system-update-failure-notify.Install.WantedBy == [ "graphical-session.target" ];
true
