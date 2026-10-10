{
  self,
  lanzaboote,
  includeLanzaboote ? true,
}:
{
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python312.withPackages (pythonPackages: [ pythonPackages.pydantic ]);
  consoleModules = [
    "__init__.py"
    "boot.py"
    "executor.py"
    "health.py"
    "journal.py"
    "machine.py"
    "policy.py"
    "projection.py"
    "recovery_console.py"
    "registry.py"
    "schema.py"
    "state.py"
    "store.py"
    "tpm.py"
    "txn.py"
  ];
  recoveryConsole =
    pkgs.runCommand "intentd-recovery-console"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin $out/lib/intentd
        for module in ${pkgs.lib.escapeShellArgs consoleModules}; do
          cp ${self}/src/intentd/$module $out/lib/intentd/$module
        done
        makeWrapper ${python}/bin/python $out/bin/intentd-recovery-console \
          --add-flags $out/lib/intentd/recovery_console.py \
          --prefix PYTHONPATH : $out/lib
      '';
  journalInspector =
    pkgs.runCommand "intentd-journal-inspect"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin $out/lib/intentd
        cp ${self}/src/intentd/__init__.py $out/lib/intentd/__init__.py
        cp ${self}/src/intentd/journal.py $out/lib/intentd/journal.py
        cp ${self}/src/intentd/journal_inspect.py $out/lib/intentd/journal_inspect.py
        cp ${self}/src/intentd/schema.py $out/lib/intentd/schema.py
        makeWrapper ${python}/bin/python $out/bin/intentd-journal-inspect \
          --add-flags $out/lib/intentd/journal_inspect.py \
          --prefix PYTHONPATH : $out/lib
      '';
in
{
  imports = lib.optional includeLanzaboote lanzaboote.nixosModules.lanzaboote;

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "virtio_blk"
    "virtio_pci"
  ];
  boot.lanzaboote = {
    enable = true;
    sortKey = lib.mkForce "intentd-recovery";
    bootCounting.initialTries = lib.mkForce 0;
  };
  boot.loader.systemd-boot.enable = false;
  boot.loader.systemd-boot.editor = false;

  networking.useDHCP = false;
  networking.networkmanager.enable = false;
  services.resolved.enable = false;
  systemd.network.enable = false;
  systemd.targets.network-online.wantedBy = lib.mkForce [ ];

  services.getty.autologinUser = null;
  users.users.root = {
    hashedPassword = lib.mkForce "!";
    hashedPasswordFile = lib.mkForce null;
    shell = "${pkgs.shadow}/bin/nologin";
  };

  environment.systemPackages = [
    pkgs.systemd
    journalInspector
    recoveryConsole
  ];

  systemd.services.intentd-recovery-marker = {
    description = "Mark the fixed intentd recovery boot";
    wantedBy = [ "multi-user.target" ];
    before = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/touch /run/intentd-recovery";
    };
  };

  systemd.services.intentd-recovery-console = {
    description = "Report authenticated intentd journal and boot status";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    path = [ pkgs.tpm2-tools ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${recoveryConsole}/bin/intentd-recovery-console inspect";
      RemainAfterExit = true;
    };
    environment = {
      INTENTD_STATE_DIR = "/var/lib/intentd";
      INTENTD_JOURNAL_KEY_FILE = "/var/lib/intentd/journal.key";
    };
  };
}
