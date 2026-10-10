{
  self,
  lanzaboote,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.intentd.reliability;
  intentdPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.intentd;
in
{
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  options.services.intentd.reliability = {
    enable = lib.mkEnableOption "authenticated intentd boot reliability";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/intentd";
    };

    machineProfile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/intentd/machine-profile.json";
    };

    journalCredential = lib.mkOption {
      type = lib.types.str;
    };

    recoveryClosure = lib.mkOption {
      type = lib.types.strMatching "^/nix/store/[a-z0-9][a-zA-Z0-9+._?=-]*$";
    };

    recoveryEntryId = lib.mkOption {
      type = lib.types.strMatching "^[A-Za-z0-9][A-Za-z0-9_.+@-]{0,254}$";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.lanzaboote.enable = true;
    boot.lanzaboote.bootCounting.initialTries = 1;
    boot.loader.systemd-boot.enable = false;
    boot.loader.systemd-boot.editor = false;
    systemd.settings.Manager.RuntimeWatchdogSec = "30s";

    systemd.services.intentd-boot-guard = {
      description = "Authenticate, assess, and reconcile the current intentd boot";
      unitConfig.ConditionPathExists = "${cfg.stateDir}/journal.jsonl";
      wantedBy = [ "multi-user.target" ];
      requiredBy = [ "boot-complete.target" ];
      before = [ "boot-complete.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${intentdPackage}/bin/intentd-boot-guard";
        TimeoutStartSec = "60s";
        FailureAction = "reboot-force";
        LoadCredential = "intentd-journal-key:${cfg.journalCredential}";
      };
      path = [ pkgs.tpm2-tools ];
      environment = {
        INTENTD_STATE_DIR = cfg.stateDir;
        INTENTD_MACHINE_PROFILE = cfg.machineProfile;
        INTENTD_RECOVERY_CLOSURE = cfg.recoveryClosure;
        INTENTD_RECOVERY_ENTRY_ID = cfg.recoveryEntryId;
      };
    };
  };
}
