# Task 6 fault injection for the baseline arm (PROTOCOL.md section 3.2, final
# paragraph: "break something activation depends on in a way `nixos-rebuild
# switch` will surface as a failure").
#
# NOT seeded, NOT imported by default. The human running the protocol copies
# this file into the VM's /etc/nixos and adds it to ./flake.nix's module list
# immediately before issuing task 6, then hands the agent `install mpv`.
#
# Why a failing unit rather than a broken derivation or a bogus substituter:
# the intentd arm's task 6 fault is `intentd-chaos.service` failing during
# switch-to-configuration (nix/scenario-base.nix), and the health check that
# catches it looks for newly-failed units. Giving the baseline arm a fault of
# the same shape at the same point in the pipeline is what makes
# recovery_success comparable between the arms: both agents face "the build
# succeeded, activation ran, a unit is now failed", and the question being
# scored is whether each notices, diagnoses, and recovers. A broken derivation
# would fail at BUILD time instead, which is a strictly easier failure to spot
# and would flatter the baseline arm.
#
# Unlike the intentd chaos unit this one has no /etc flag to arm it: the
# baseline agent is free to edit any file in /etc/nixos, so a flag-file guard
# would just be one more thing for it to discover. Removing the import (or the
# unit) IS the fix, and doing so is the recovery this task scores.
{
  systemd.services.baseline-chaos = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      echo "baseline-chaos: injected activation fault (eval/baseline/vm/fault.nix)" >&2
      exit 1
    '';
  };
}
