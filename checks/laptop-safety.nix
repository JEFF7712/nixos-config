{ config }:

let
  preservedFiles = map (entry: entry.file) config.preservation.preserveAt."/persist".files;
  preservedDirectories = map (
    entry: entry.directory
  ) config.preservation.preserveAt."/persist".directories;
  numberpadService = config.systemd.services.asus-numberpad-driver;
  numberpadPath = config.systemd.paths.asus-numberpad-driver;
  cominService = config.systemd.services.comin;
  cominRemotes = config.services.comin.remotes;
  nixDaemon = config.systemd.services.nix-daemon;
  nvidiaCdi = config.systemd.services.nvidia-container-toolkit-cdi-generator;
  userServices = config.home-manager.users.rupan.systemd.user.services;
  userTimers = config.home-manager.users.rupan.systemd.user.timers;
  quickshellService = userServices.quickshell-bar;
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
assert !config.auto-update.enable;
assert builtins.elem "/var/lib/comin" preservedDirectories;
assert builtins.elem "/var/lib/nixos-deploy" preservedDirectories;
assert builtins.match ".*max-jobs = 0\n.*" cominService.environment.NIX_CONFIG != null;
assert
  builtins.match ".*always-allow-substitutes = true\n.*" cominService.environment.NIX_CONFIG != null;
assert builtins.all (
  remote:
  remote.branches.main.name == "deploy/laptop"
  && remote.branches.testing.name == "deploy/laptop-testing"
) cominRemotes;
assert nixDaemon.serviceConfig.CPUWeight == 25;
assert nixDaemon.serviceConfig.IOWeight == 25;
assert nixDaemon.serviceConfig.MemoryHigh == "22G";
assert nixDaemon.serviceConfig.MemoryMax == "25G";
assert nixDaemon.serviceConfig.TasksMax == 4096;
assert nvidiaCdi.wantedBy == [ ];
assert builtins.elem "podman.service" nvidiaCdi.requiredBy;
assert nvidiaCdi.serviceConfig.ExecStartPre == [ ];
assert
  builtins.match ".*restart nvidia-container-toolkit-cdi-generator.service.*" config.services.udev.extraRules
  != null;
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
assert quickshellService.Service.Restart == "on-failure";
assert quickshellService.Service.RestartSec == 2;
assert quickshellService.Service.StandardOutput == "journal";
assert quickshellService.Service.StandardError == "journal";
assert !(quickshellService ? Install);
assert config.intentd-host.enable;
assert builtins.elem "/var/lib/intentd" preservedDirectories;
assert config.services.intentd.reliability.journalCredential == "/var/lib/intentd/journal.key";
assert config.systemd.services.intentd-state-init.serviceConfig.StateDirectoryMode == "0700";
assert builtins.elem "intentd-state-init.service"
  config.systemd.services.intentd-boot-guard.requires;
assert builtins.elem "intentd-baseline-adopt.service"
  config.systemd.services.intentd-boot-guard.requires;
assert builtins.elem "intentd-baseline-adopt.service"
  config.systemd.services.intentd-boot-guard.after;
assert
  config.systemd.services.intentd-baseline-adopt.unitConfig.ConditionPathExists
  == "!/var/lib/intentd/journal.jsonl";
assert builtins.elem "intentd-display-ready.service"
  config.systemd.services.intentd-boot-guard.after;
assert config.boot.lanzaboote.bootCounting.initialTries == 1;
assert config.systemd.targets.boot-complete.unitConfig.X-OnlyManualStart;
assert config.systemd.services.intentd-boot-guard.unitConfig.X-OnlyManualStart;
assert !config.systemd.services.intentd-boot-guard.restartIfChanged;
assert config.systemd.services.intentd-baseline-adopt.unitConfig.X-OnlyManualStart;
assert !config.systemd.services.intentd-baseline-adopt.restartIfChanged;
assert
  config.systemd.services.intentd-boot-guard.serviceConfig.ExecCondition
  == config.systemd.services.intentd-baseline-adopt.serviceConfig.ExecCondition;
true
