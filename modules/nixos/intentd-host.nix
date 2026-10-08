{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  recovery = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [ ../../hosts/laptop/intentd-recovery.nix ];
  };
  recoveryClosure = recovery.config.system.build.toplevel;
in
{
  # secureboot.nix already imports the Lanzaboote wrapper and its package override.
  imports = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      (inputs.intentd.nixosModules.reliability { inherit config lib pkgs; }) // { imports = [ ]; }
    )
  ];

  options.intentd-host.enable = lib.mkEnableOption "intentd reliability on the UX3404VC";

  config = lib.mkIf config.intentd-host.enable {
    assertions = [
      {
        assertion = config.impermanence.enable && config.secureboot.enable;
        message = "intentd-host requires persistent state and Secure Boot.";
      }
    ];
    services.intentd.reliability = {
      enable = true;
      journalCredential = "/var/lib/intentd/journal.key";
      recoveryClosure = "${recoveryClosure}";
      recoveryEntryId = "intentd-recovery.efi";
    };
    environment.systemPackages = [
      inputs.intentd.packages.${pkgs.stdenv.hostPlatform.system}.intentd
      pkgs.tpm2-tools
    ];
    environment.etc."intentd/machine-profile.json".text = builtins.toJSON {
      profile_id = "ux3404vc-v1";
      certified = true;
      graphics_backend = "ux3404vc";
      intel_pci = "0000:00:02.0";
      nvidia_pci = "0000:01:00.0";
      critical_units = [
        "intentd-display-ready.service"
        "greetd.service"
        "systemd-udevd.service"
      ];
      display_unit = "intentd-display-ready.service";
      root_reserve_bytes = 10737418240;
      esp_reserve_bytes = 134217728;
    };
    environment.etc."intentd/initial-state.json".text = builtins.toJSON {
      apps = [ ];
      graphics_profile = if config.nvidia.enable then "hybrid-nvidia" else "integrated";
    };
    environment.etc."intentd/host-flake.lock".source = "${inputs.self}/flake.lock";
    preservation.preserveAt."/persist".directories = [
      {
        directory = "/var/lib/intentd";
        mode = "0700";
      }
    ];
    systemd.tmpfiles.rules = [
      "d /var/lib/intentd/gcroots 0700 root root -"
      "L+ /var/lib/intentd/gcroots/recovery - - - - ${recoveryClosure}"
      "L+ /nix/var/nix/gcroots/intentd-recovery - - - - ${recoveryClosure}"
    ];
    systemd.services.intentd-state-init = {
      description = "Provision the persistent intentd journal credential";
      wantedBy = [ "multi-user.target" ];
      before = [ "intentd-boot-guard.service" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
        StateDirectory = "intentd";
        StateDirectoryMode = "0700";
      };
      path = [ pkgs.coreutils ];
      script = ''
        key=/var/lib/intentd/journal.key
        if [ ! -e "$key" ]; then
          test ! -e /var/lib/intentd/journal.jsonl
          temporary=$(mktemp /var/lib/intentd/.journal-key.XXXXXX)
          head -c 32 /dev/urandom > "$temporary"
          chmod 0600 "$temporary"
          mv -T "$temporary" "$key"
        fi
        test "$(stat -c '%u:%a:%s' "$key")" = '0:600:32'
      '';
    };
    systemd.services.intentd-display-ready = {
      description = "Verify the UX3404VC internal display scanout";
      wantedBy = [ "multi-user.target" ];
      requires = [ "greetd.service" ];
      after = [ "greetd.service" ];
      before = [ "intentd-boot-guard.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "40s";
      };
      path = [ pkgs.coreutils ];
      script = ''
        test "$(cat /sys/class/dmi/id/product_name)" = 'Zenbook UX3404VC_UX3404VC'
        test "$(cat /sys/bus/pci/devices/0000:00:02.0/vendor)" = 0x8086
        test "$(cat /sys/bus/pci/devices/0000:00:02.0/device)" = 0xa7a0
        test "$(cat /sys/bus/pci/devices/0000:01:00.0/vendor)" = 0x10de
        test "$(cat /sys/bus/pci/devices/0000:01:00.0/device)" = 0x25ab
        for attempt in $(seq 1 30); do
          for connector in /sys/class/drm/card*-eDP-*; do
            if [ -r "$connector/status" ] && [ -r "$connector/enabled" ] &&
              [ "$(cat "$connector/status")" = connected ] &&
              [ "$(cat "$connector/enabled")" = enabled ]; then
              exit 0
            fi
          done
          sleep 1
        done
        exit 1
      '';
    };
    systemd.services.intentd-boot-guard = {
      requires = [
        "intentd-state-init.service"
        "intentd-baseline-adopt.service"
      ];
      wants = [ "intentd-display-ready.service" ];
      after = [
        "intentd-state-init.service"
        "intentd-baseline-adopt.service"
        "intentd-display-ready.service"
        "greetd.service"
        "systemd-udevd.service"
      ];
      path = [ pkgs.systemd ];
    };
    systemd.services.intentd-baseline-adopt = {
      description = "Authenticate the first physical intentd boot baseline";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "intentd-state-init.service"
        "intentd-display-ready.service"
      ];
      after = [
        "intentd-state-init.service"
        "intentd-display-ready.service"
        "local-fs.target"
      ];
      before = [ "intentd-boot-guard.service" ];
      unitConfig.ConditionPathExists = "!/var/lib/intentd/journal.jsonl";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${
          inputs.intentd.packages.${pkgs.stdenv.hostPlatform.system}.intentd
        }/bin/intentd-adopt-baseline";
        UMask = "0077";
        TimeoutStartSec = "60s";
      };
      path = [
        pkgs.systemd
        pkgs.tpm2-tools
      ];
    };
    systemd.targets.boot-complete.after = [ "multi-user.target" ];
    system.build.intentdRecovery = recoveryClosure;
    security.sudo.extraRules = [
      {
        users = [ "rupan" ];
        commands = [
          {
            command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake ${config.repoPath}\\#laptop";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
