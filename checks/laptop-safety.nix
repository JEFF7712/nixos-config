{ config }:

let
  preservedFiles = map (entry: entry.file) config.preservation.preserveAt."/persist".files;
  preservedDirectories = map (
    entry: entry.directory
  ) config.preservation.preserveAt."/persist".directories;
  numberpadService = config.systemd.services.asus-numberpad-driver;
  numberpadPath = config.systemd.paths.asus-numberpad-driver;
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
assert builtins.elem "/etc/subuid" preservedFiles;
assert builtins.elem "/etc/subgid" preservedFiles;
assert builtins.elem "/var/lib/asus-numberpad-driver" preservedDirectories;
assert numberpadService.serviceConfig.StateDirectory == "asus-numberpad-driver";
assert numberpadService.wantedBy == [ ];
assert numberpadPath.wantedBy == [ "paths.target" ];
assert numberpadPath.pathConfig.PathExists == "/run/user/1000/wayland-1";
assert
  builtins.match ".*/test -S /run/user/1000/wayland-1" numberpadService.serviceConfig.ExecCondition
  != null;
assert
  builtins.match ".*/numberpad.py up5401ea /var/lib/asus-numberpad-driver/" numberpadService.serviceConfig.ExecStart
  != null;
assert builtins.elem "i915" config.boot.initrd.kernelModules;
assert config.boot.lanzaboote.configurationLimit <= 4;
assert userServices ? system-update-failure-notify;
assert userTimers ? system-update-failure-notify;
assert userTimers.system-update-failure-notify.Install.WantedBy == [ "graphical-session.target" ];
true
