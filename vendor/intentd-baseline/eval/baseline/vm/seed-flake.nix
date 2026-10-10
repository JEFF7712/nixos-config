# Becomes /etc/nixos/flake.nix inside the VM (copied by ./seed.nix).
#
# This is the flake the agent under test operates on. It is deliberately the
# minimal shape PROTOCOL.md section 3.1 step 1 describes, and it pins the same
# nixpkgs rev as intentd's own flake.lock: the comparison is invalid if the
# baseline arm resolves a different nixpkgs than the intentd arm evaluated
# against, so the rev is written out literally rather than tracking a channel.
#
# It differs from ../flake.nix in exactly one way: no ./seed.nix module. Once
# /etc/nixos exists there is nothing left to seed, and leaving the seeding
# unit in the agent's own configuration would put a file-writing systemd
# service in a "plain NixOS" machine that a real user would not have.
{
  description = "Baseline arm NixOS configuration (eval/baseline/PROTOCOL.md)";

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
        ];
      };
    };
}
