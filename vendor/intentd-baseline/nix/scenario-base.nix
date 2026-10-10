{ modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    (modulesPath + "/testing/test-instrumentation.nix")
  ];
  system.stateVersion = "25.11";
  # After the first switch, /etc/nix/nix.conf comes from the ACTIVE candidate,
  # not the test node. Later in-VM hermetic builds run under this config, so
  # the offline flake settings must ride along in every candidate.
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = lib.mkForce [ ];
    flake-registry = "";
  };
  environment.etc."intentd/machine-profile.json".text = builtins.toJSON {
    profile_id = "intentd-vm-v1";
    certified = true;
    graphics_backend = "intentd-vm";
    intel_pci = "0000:00:02.0";
    nvidia_pci = "0000:01:00.0";
    critical_units = [ "intentd-display-ready.service" ];
    display_unit = "intentd-display-ready.service";
    root_reserve_bytes = 268435456;
    esp_reserve_bytes = 134217728;
  };
  users.users.wedge = {
    isNormalUser = true;
    initialPassword = "wedge";
  };
  # M4 Task 6 chaos mechanism: fails iff /etc/intentd-chaos exists. Type is
  # oneshot with the default RemainAfterExit=false, so the unit goes back to
  # "inactive" the moment it finishes; switch-to-configuration always issues
  # a "start" job against multi-user.target (see collect_unit_changes in
  # switch-to-configuration-ng, the active-target branch runs unconditionally
  # on every switch), and systemd resolves that job against the target's
  # Wants=, which restarts any wanted-but-inactive unit -- including this one.
  # So every switch re-checks the flag's state at that moment, with no extra
  # wiring needed to "trigger" it.
  systemd.services.intentd-chaos = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      if [ -e /etc/intentd-chaos ]; then
        echo "intentd-chaos: chaos flag present, failing" >&2
        exit 1
      fi
      exit 0
    '';
  };
}
