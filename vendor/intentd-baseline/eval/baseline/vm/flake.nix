# Baseline arm VM (eval/baseline/PROTOCOL.md section 3.1).
#
# A separate flake from the repo root's on purpose. PROTOCOL section 3.1 step 1
# is explicit that this VM must not ship with intentd or the product-owned
# flake template, and the cleanest way to guarantee that is for the baseline
# image to have no path into intentd's flake at all, rather than a `checks`
# attribute next to the intentd VMs that could grow one by accident.
#
# Build and boot:
#   nix build ./eval/baseline/vm --print-out-paths --no-link
#   $(nix build ./eval/baseline/vm --print-out-paths --no-link)/bin/run-baseline-vm
#
# See ../RUNBOOK.md for the full session procedure.
{
  description = "Plain NixOS VM for the comparative baseline arm (no intentd)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/e7a3ca8092b61ff85b6a45bf863ea2b2d6a661b3";

  inputs.nix-agent = {
    url = "github:JEFF7712/nix-agent/317334c76aa07ade539918014b977685501f7aaa";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-agent,
    }:
    {
      nixosConfigurations.baseline = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nix-agent; };
        modules = [
          ./configuration.nix
          ./agent-harness.nix
          ./vm-node.nix
          ./seed.nix
        ];
      };

      checks.x86_64-linux.privilege-boundary = import ./privilege-boundary.nix {
        inherit nixpkgs nix-agent;
        baselineModules = [
          ./configuration.nix
          ./agent-harness.nix
          ./seed.nix
        ];
      };

      packages.x86_64-linux.default = self.nixosConfigurations.baseline.config.system.build.vm;
    };
}
