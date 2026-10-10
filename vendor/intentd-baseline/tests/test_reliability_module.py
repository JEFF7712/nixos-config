import json
import subprocess
from pathlib import Path

import pytest

_ROOT = Path(__file__).resolve().parents[1]


def _eval(expression: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["nix", "eval", "--json", "--impure", "--expr", expression],
        cwd=_ROOT,
        capture_output=True,
        text=True,
        timeout=1800,
    )


def _system(extra_config: str) -> str:
    return f"""
      let
        flake = builtins.getFlake (toString {_ROOT});
        system = flake.inputs.nixpkgs.lib.nixosSystem {{
          system = "x86_64-linux";
          modules = [
            flake.inputs.lanzaboote.nixosModules.lanzaboote
            flake.nixosModules.reliability
            ({{ ... }}: {{
              services.intentd.reliability = {{
                enable = true;
                stateDir = "/var/lib/intentd";
                machineProfile = "/etc/intentd/machine-profile.json";
                journalCredential = "/run/keys/intentd-journal-key";
                {extra_config}
              }};
            }})
          ];
        }};
      in system
    """


@pytest.mark.nix_eval
def test_reliability_module_wires_closed_boot_gate() -> None:
    expression = f"""
      let
        system = {_system('recoveryClosure = "/nix/store/recovery"; recoveryEntryId = "intentd-recovery.efi";')};
        config = system.config;
        service = config.systemd.services.intentd-boot-guard;
      in {{
        before = service.before;
        requiredBy = service.requiredBy;
        wantedBy = service.wantedBy;
        after = service.after;
        serviceConfig = service.serviceConfig;
        environment = service.environment;
        conditionPathExists = service.unitConfig.ConditionPathExists;
        initialTries = config.boot.lanzaboote.bootCounting.initialTries;
        editor = config.boot.loader.systemd-boot.editor;
        lanzabooteEnabled = config.boot.lanzaboote.enable;
        watchdog = config.systemd.settings.Manager.RuntimeWatchdogSec;
      }}
    """

    result = _eval(expression)

    assert result.returncode == 0, result.stderr
    config = json.loads(result.stdout)
    assert config["before"] == ["boot-complete.target"]
    assert config["requiredBy"] == ["boot-complete.target"]
    assert config["wantedBy"] == ["multi-user.target"]
    assert config["after"] == ["local-fs.target"]
    service_config = config["serviceConfig"]
    assert service_config["Type"] == "oneshot"
    assert service_config["TimeoutStartSec"] == "60s"
    assert service_config["FailureAction"] == "reboot-force"
    assert service_config["LoadCredential"].startswith("intentd-journal-key:")
    assert config["initialTries"] == 1
    assert config["editor"] is False
    assert config["lanzabooteEnabled"] is True
    assert config["watchdog"] == "30s"
    assert config["conditionPathExists"] == "/var/lib/intentd/journal.jsonl"
    assert "network-online.target" not in config["after"]
    assert {
        key: config["environment"][key]
        for key in (
            "INTENTD_MACHINE_PROFILE",
            "INTENTD_RECOVERY_CLOSURE",
            "INTENTD_RECOVERY_ENTRY_ID",
            "INTENTD_STATE_DIR",
        )
    } == {
        "INTENTD_MACHINE_PROFILE": "/etc/intentd/machine-profile.json",
        "INTENTD_RECOVERY_CLOSURE": "/nix/store/recovery",
        "INTENTD_RECOVERY_ENTRY_ID": "intentd-recovery.efi",
        "INTENTD_STATE_DIR": "/var/lib/intentd",
    }


@pytest.mark.nix_eval
@pytest.mark.parametrize(
    ("partial", "missing_environment"),
    [
        ('recoveryEntryId = "intentd-recovery.efi";', "INTENTD_RECOVERY_CLOSURE"),
        ('recoveryClosure = "/nix/store/recovery";', "INTENTD_RECOVERY_ENTRY_ID"),
    ],
)
def test_recovery_identity_options_are_required(partial: str, missing_environment: str) -> None:
    expression = (
        f"({_system(partial)}).config.systemd.services.intentd-boot-guard.environment."
        f'"{missing_environment}"'
    )

    result = _eval(expression)

    assert result.returncode != 0
    assert "services.intentd.reliability.recovery" in result.stderr


@pytest.mark.nix_eval
def test_recovery_module_is_fixed_non_networked_and_not_boot_counted() -> None:
    expression = f"""
      let
        flake = builtins.getFlake (toString {_ROOT});
        system = flake.inputs.nixpkgs.lib.nixosSystem {{
          system = "x86_64-linux";
          modules = [ flake.nixosModules.reliabilityRecovery ];
        }};
        config = system.config;
      in {{
        sortKey = config.boot.lanzaboote.sortKey;
        initialTries = config.boot.lanzaboote.bootCounting.initialTries;
        editor = config.boot.loader.systemd-boot.editor;
        useDHCP = config.networking.useDHCP;
        networkOnlineWantedBy = config.systemd.targets.network-online.wantedBy;
        rootPassword = config.users.users.root.hashedPassword;
        rootShell = config.users.users.root.shell;
        markerWantedBy = config.systemd.services.intentd-recovery-marker.wantedBy;
        consoleWantedBy = config.systemd.services.intentd-recovery-console.wantedBy;
        consoleExec =
          config.systemd.services.intentd-recovery-console.serviceConfig.ExecStart;
        packages = map flake.inputs.nixpkgs.lib.getName config.environment.systemPackages;
      }}
    """

    result = _eval(expression)

    assert result.returncode == 0, result.stderr
    config = json.loads(result.stdout)
    assert config["editor"] is False
    assert config["initialTries"] == 0
    assert config["markerWantedBy"] == ["multi-user.target"]
    assert config["networkOnlineWantedBy"] == []
    assert config["rootPassword"] == "!"
    assert config["rootShell"].endswith("/bin/nologin")
    assert config["sortKey"] == "intentd-recovery"
    assert config["useDHCP"] is False
    assert "intentd-journal-inspect" in config["packages"]
    assert "intentd-recovery-console" in config["packages"]
    assert "intentd" not in config["packages"]
    assert config["consoleWantedBy"] == ["multi-user.target"]
    assert config["consoleExec"].endswith("/bin/intentd-recovery-console inspect")
