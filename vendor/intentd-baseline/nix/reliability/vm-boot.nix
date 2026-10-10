{
  self,
  nixpkgs,
  lanzaboote,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  journalKey = pkgs.writeText "intentd-vm-journal-key" (
    builtins.concatStringsSep "" (
      builtins.genList (index: builtins.substring index 1 "0123456789abcdef0123456789abcdef") 32
    )
  );
  machineProfile = pkgs.writeText "intentd-vm-machine-profile.json" (
    builtins.toJSON {
      profile_id = "intentd-vm-v1";
      certified = true;
      graphics_backend = "intentd-vm";
      intel_pci = "0000:00:02.0";
      nvidia_pci = "0000:01:00.0";
      critical_units = [
        "intentd-display-ready.service"
        "intentd-critical-ready.service"
      ];
      display_unit = "intentd-display-ready.service";
      root_reserve_bytes = 268435456;
      esp_reserve_bytes = 134217728;
    }
  );
  test = pkgs.testers.runNixOSTest {
    name = "intentd-authenticated-boot";
    globalTimeout = 20 * 60;
    nodes.machine =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        candidateClosures = {
          integrated = config.specialisation.integrated.configuration.system.build.toplevel;
          hybrid = config.specialisation.hybrid.configuration.system.build.toplevel;
          unhealthy = config.specialisation.unhealthy.configuration.system.build.toplevel;
          critfail = config.specialisation.critfail.configuration.system.build.toplevel;
          powerloss = config.specialisation.powerloss.configuration.system.build.toplevel;
          recovery = config.specialisation.recovery.configuration.system.build.toplevel;
        };
        python = pkgs.python312;
        pythonEnv = python.withPackages (pythonPackages: [
          pythonPackages.pydantic
          pythonPackages.textual
        ]);
        intentdPackage = self.packages.${system}.intentd;
        vmDriver = pkgs.writeShellApplication {
          name = "intentd-vm-driver";
          text = ''
            export PYTHONPATH=${intentdPackage}/${python.sitePackages}
            export INTENTD_JOURNAL_KEY_FILE=/var/lib/intentd/journal.key
            export INTENTD_CANDIDATE_INTEGRATED=${candidateClosures.integrated}
            export INTENTD_CANDIDATE_HYBRID=${candidateClosures.hybrid}
            export INTENTD_CANDIDATE_UNHEALTHY=${candidateClosures.unhealthy}
            export INTENTD_CANDIDATE_CRITFAIL=${candidateClosures.critfail}
            export INTENTD_CANDIDATE_POWERLOSS=${candidateClosures.powerloss}
            export INTENTD_CANDIDATE_RECOVERY=${candidateClosures.recovery}
            exec ${pythonEnv}/bin/python ${self}/nix/reliability/vm-driver.py "$@"
          '';
        };
      in
      {
        imports = [
          "${lanzaboote}/nix/tests/lanzaboote/common/lanzaboote.nix"
          self.nixosModules.reliability
        ];

        lanzabooteTest.persistentRoot = true;
        boot.lanzaboote.sortKey = "intentd-base";
        systemd.targets.boot-complete.after = [ "multi-user.target" ];

        boot.kernelModules = [ "tpm_tis" ];
        environment.systemPackages = [ pkgs.tpm2-tools ];
        virtualisation.qemu.options = [
          "-chardev socket,id=chrtpm,path=/tmp/intentd-swtpm/swtpm-sock"
          "-tpmdev emulator,id=tpm0,chardev=chrtpm"
          "-device tpm-tis,tpmdev=tpm0"
        ];

        services.intentd.reliability = {
          enable = true;
          stateDir = "/var/lib/intentd";
          machineProfile = "/etc/intentd/machine-profile.json";
          journalCredential = "/var/lib/intentd/journal.key";
          recoveryClosure = "/nix/store/00000000000000000000000000000000-intentd-recovery";
          recoveryEntryId = "intentd-recovery.efi";
        };

        systemd.services.intentd-display-ready = {
          description = "Deterministic intentd VM display evidence";
          wantedBy = [ "multi-user.target" ];
          before = [ "intentd-boot-guard.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = "true";
        };

        systemd.services.intentd-critical-ready = {
          description = "Deterministic intentd VM critical-service evidence";
          wantedBy = [ "multi-user.target" ];
          before = [ "intentd-boot-guard.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = "true";
        };

        specialisation = {
          integrated.configuration = {
            boot.lanzaboote.sortKey = lib.mkForce "intentd-candidate-integrated";
            environment.etc."intentd-generation".text = "integrated\n";
          };
          hybrid.configuration = {
            boot.lanzaboote.sortKey = lib.mkForce "intentd-candidate-hybrid";
            environment.etc."intentd-generation".text = "hybrid\n";
          };
          unhealthy.configuration = {
            boot.lanzaboote.sortKey = lib.mkForce "intentd-candidate-unhealthy";
            environment.etc."intentd-generation".text = "unhealthy\n";
            systemd.services.intentd-display-ready.script = lib.mkForce "false";
          };
          critfail.configuration = {
            boot.lanzaboote.sortKey = lib.mkForce "intentd-candidate-critfail";
            environment.etc."intentd-generation".text = "critfail\n";
            systemd.services.intentd-critical-ready.script = lib.mkForce "false";
          };
          powerloss.configuration = {
            boot.lanzaboote.sortKey = lib.mkForce "intentd-candidate-powerloss";
            environment.etc."intentd-generation".text = "powerloss\n";
            systemd.services.intentd-test-boot-barrier = {
              description = "Hold the intentd VM before boot reconciliation";
              requiredBy = [ "intentd-boot-guard.service" ];
              before = [ "intentd-boot-guard.service" ];
              serviceConfig.Type = "oneshot";
              script = "sleep 300";
            };
          };
          recovery.configuration = {
            imports = [
              (import ./recovery.nix {
                inherit self lanzaboote;
                includeLanzaboote = false;
              })
            ];
            environment.etc."intentd-generation".text = "recovery\n";
            systemd.services.intentd-boot-guard.enable = lib.mkForce false;
          };
        };

        environment.etc."intentd/machine-profile.json".source = machineProfile;
        systemd.tmpfiles.rules = [
          "d /var/lib/intentd 0700 root root -"
          "C /var/lib/intentd/journal.key 0600 root root - ${journalKey}"
        ];

        nix.settings.substituters = lib.mkForce [ ];
        virtualisation.mountHostNixStore = false;
        image.repart.partitions = {
          esp.repartConfig.SizeMinBytes = lib.mkForce "512M";
          root.repartConfig.SizeMinBytes = lib.mkForce "1G";
          "nix-store".storePaths = [ vmDriver ];
        };
        system.build.intentdVmDriver = vmDriver;
      };

    testScript =
      { nodes, ... }:
      let
        vmDriver = nodes.machine.system.build.intentdVmDriver;
      in
      (import ./swtpm-prestart.nix { inherit pkgs; })
      + (import "${lanzaboote}/nix/tests/lanzaboote/common/image-helper.nix" {
        inherit (nodes) machine;
      })
      + ''
        import json
        from pathlib import Path

        driver = "${vmDriver}/bin/intentd-vm-driver"

        def run_driver(verb, netns=False):
          prefix = "unshare -n " if netns else ""
          return json.loads(machine.succeed(f"{prefix}{driver} {verb}"))

        def reboot_after_stage(candidate):
          machine.succeed("test -e /run/intentd-reboot-requested")
          machine.succeed("rm /run/intentd-reboot-requested")
          old_boot_id = machine.succeed("cat /proc/sys/kernel/random/boot_id").strip()
          machine.reboot()
          machine.wait_until_succeeds(
            f'test "$(cat /proc/sys/kernel/random/boot_id)" != "{old_boot_id}"'
          )
          return old_boot_id

        def reboot_through_failed_candidate():
          machine.succeed("test -e /run/intentd-reboot-requested")
          machine.succeed("rm /run/intentd-reboot-requested")
          machine.reboot()
          machine.wait_for_console_text(
            "Failed to start Deterministic intentd VM display evidence"
          )
          machine.connect()
          machine.wait_for_console_text("The system will reboot now")
          machine.connected = False
          machine.wait_for_console_text('BdsDxe: starting Boot0002 "UEFI Misc Device"')

        def reboot_through_critfail_candidate():
          machine.succeed("test -e /run/intentd-reboot-requested")
          machine.succeed("rm /run/intentd-reboot-requested")
          machine.reboot()
          machine.wait_for_console_text(
            "Failed to start Deterministic intentd VM critical-service evidence"
          )
          machine.connect()
          machine.wait_for_console_text("The system will reboot now")
          machine.connected = False
          machine.wait_for_console_text('BdsDxe: starting Boot0002 "UEFI Misc Device"')

        def selected_entry():
          return next(
            entry for entry in json.loads(machine.succeed("bootctl list --json=short"))
            if entry["isSelected"]
          )

        machine.start(allow_reboot=True)
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("boot-complete.target")

        with subtest("provision TPM NV rollback counter"):
          machine.succeed("test -c /dev/tpm0")
          machine.succeed(
            "tpm2_nvdefine 0x01800001 -C o -s 8"
            " -a 'ownerread|ownerwrite|authread|authwrite|no_da|orderly|nt=counter'"
          )
          # A freshly defined counter reads NV-uninitialized until the first
          # increment, so provisioning consumes value 1 up front.
          machine.succeed("tpm2_nvincrement 0x01800001 -C o")
          machine.succeed("tpm2_nvread 0x01800001 -C o -o /tmp/intentd-nv-check.bin")
          assert machine.succeed("od -A d -t x1 /tmp/intentd-nv-check.bin").strip() == (
            "0000000 00 00 00 00 00 00 00 01\n0000008"
          )

        with subtest("seed authenticated blessed anchor"):
          seed = run_driver("seed-blessed")
          assert seed["artifact"]["closure_path"] == machine.succeed(
            "readlink -f /run/current-system"
          ).strip()

        with subtest("integrated candidate is health-gated and blessed"):
          machine.fail("command -v claude")
          machine.succeed("test \"$(env | grep -c ANTHROPIC)\" = 0")
          candidate = run_driver("stage-integrated", netns=True)
          reboot_after_stage(candidate)
          machine.wait_for_unit("boot-complete.target")
          machine.succeed("grep -qx integrated /etc/intentd-generation")
          status = run_driver("status")
          assert status["blessed_txn"] == candidate["id"]
          assert status["active_txn"] == candidate["id"]
          assert status["blessed"]["nv_counter"] == 2
          assert status["boot_outcome"]["healthy"] is True
          assert status["boot_outcome"]["health"]["root_free_bytes"] >= 268_435_456
          assert status["boot_outcome"]["health"]["esp_free_bytes"] >= 134_217_728
          assert json.loads(machine.succeed("bootctl list --json=short"))

        with subtest("hybrid candidate is blessed and loses its counter"):
          candidate = run_driver("stage-hybrid")
          reboot_after_stage(candidate)
          machine.wait_for_unit("boot-complete.target")
          machine.wait_for_unit("systemd-bless-boot.service")
          machine.succeed("grep -qx hybrid /etc/intentd-generation")
          status = run_driver("status")
          assert status["blessed_txn"] == candidate["id"]
          assert status["blessed"]["nv_counter"] == 3
          selected = selected_entry()
          assert "+" not in Path(selected["path"]).name

        with subtest("failed display health quarantines and returns to blessed"):
          prior = run_driver("status")
          failed = run_driver("stage-unhealthy")
          reboot_through_failed_candidate()
          machine.wait_until_succeeds(
            f'test "$(readlink -f /run/current-system)" = "{prior["booted_closure"]}"',
            timeout=120,
          )
          machine.succeed(
            "test \"$(systemctl show -p Result --value intentd-boot-guard.service)\" = success"
          )
          status = run_driver("status")
          assert status["active_txn"] == status["blessed_txn"]
          assert status["booted_closure"] == prior["booted_closure"]
          assert status["failed_txn"]["status"] == "aborted"
          assert status["failed_txn"]["boot_outcome"]["quarantined"] is True
          assert status["failed_txn"]["boot_outcome"]["recovered"] is False

        with subtest("failed critical service quarantines and returns to blessed"):
          prior = run_driver("status")
          failed = run_driver("stage-critfail")
          reboot_through_critfail_candidate()
          machine.wait_until_succeeds(
            f'test "$(readlink -f /run/current-system)" = "{prior["booted_closure"]}"',
            timeout=180,
          )
          machine.wait_for_unit("multi-user.target")
          machine.succeed(
            "test \"$(systemctl show -p Result --value intentd-boot-guard.service)\" = success"
          )
          status = run_driver("status")
          assert status["active_txn"] == status["blessed_txn"] == prior["blessed_txn"]
          assert status["pending_txn"] is None
          assert status["booted_closure"] == prior["booted_closure"]
          assert status["failed_txn"]["status"] == "aborted"
          assert status["failed_txn"]["boot_outcome"]["quarantined"] is True
          assert status["failed_txn"]["boot_outcome"]["recovered"] is False
          assert "intentd-critical-ready.service" in " ".join(
            status["failed_txn"]["boot_outcome"]["failures"]
          )

        with subtest("power loss before blessing falls back on the same image"):
          pending = run_driver("stage-powerloss")
          machine.succeed("test -e /run/intentd-reboot-requested")
          machine.succeed("rm /run/intentd-reboot-requested")
          machine.reboot()
          machine.wait_until_succeeds(
            "test \"$(systemctl show -p ActiveState --value intentd-test-boot-barrier.service)\" = activating"
          )
          first_entry = selected_entry()
          first_closure = machine.succeed("readlink -f /run/current-system").strip()
          assert first_entry["id"] == pending["boot_plan"]["candidate"]["entry_id"]
          assert first_closure == pending["boot_plan"]["candidate"]["closure_path"]
          machine.crash()
          ensure_swtpm()
          machine.start(allow_reboot=True)
          machine.wait_for_unit("multi-user.target")
          machine.wait_until_succeeds(
            "test \"$(systemctl show -p Result --value intentd-boot-guard.service)\" = success"
          )
          recovered_entry = selected_entry()
          recovered_closure = machine.succeed("readlink -f /run/current-system").strip()
          status = run_driver("status")
          assert recovered_entry["id"] == pending["boot_plan"]["prior_blessed"]["entry_id"]
          assert recovered_closure == pending["boot_plan"]["prior_blessed"]["closure_path"]
          assert status["active_txn"] == status["blessed_txn"]
          assert status["pending_txn"] is None
          assert status["failed_txn"]["boot_outcome"]["recovered"] is True
          assert status["failed_txn"]["boot_outcome"]["quarantined"] is True
          assert status["failed_txn"]["boot_outcome"]["failures"] == [
            "candidate interrupted before blessing"
          ]

        with subtest("recovery console reselects the blessed generation"):
          healthy = run_driver("status")
          recovery = run_driver("oneshot-recovery")
          assert recovery["entry_id"] != ""
          machine.reboot()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("test -e /run/intentd-recovery")
          machine.succeed(
            "test \"$(systemctl show -p Result --value intentd-recovery-console.service)\" = success"
          )
          machine.fail("command -v claude")
          machine.succeed("test \"$(env | grep -c ANTHROPIC)\" = 0")
          console = "/run/current-system/sw/bin/intentd-recovery-console"
          key = "INTENTD_JOURNAL_KEY_FILE=/var/lib/intentd/journal.key"
          inspect = json.loads(machine.succeed(f"{key} {console} inspect"))
          assert inspect["journal_ok"] is True
          assert inspect["blessed_closure"] == healthy["booted_closure"]
          assert inspect["pending_txn"] is None
          selected = json.loads(machine.succeed(f"{key} {console} select-blessed"))
          assert selected["selected"] != ""
          machine.reboot()
          machine.wait_until_succeeds(
            f'test "$(readlink -f /run/current-system)" = "{healthy["booted_closure"]}"',
            timeout=180,
          )
          machine.wait_for_unit("multi-user.target")
          machine.succeed(
            "test \"$(systemctl show -p Result --value intentd-boot-guard.service)\" = success"
          )
          status = run_driver("status")
          assert status["booted_closure"] == healthy["booted_closure"]
          assert status["blessed_txn"] == healthy["blessed_txn"] == status["active_txn"]
          assert status["pending_txn"] is None

        machine.shutdown()
        if swtpm is not None and swtpm.poll() is None:
            swtpm.terminate()
      '';
  };
in
{
  inherit test;
}
