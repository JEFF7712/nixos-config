{
  description = "intentd: intent control layer for NixOS (Stage 1 wedge)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      lanzaboote,
    }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );
    in
    {
      nixosModules.reliability = import ./nix/reliability/module.nix {
        inherit self lanzaboote;
      };
      nixosModules.reliabilityRecovery = import ./nix/reliability/recovery.nix {
        inherit self lanzaboote;
      };
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            python312
            uv
            ruff
            pyright
          ];
        };
      });
      packages = forAllSystems (pkgs: rec {
        intentd = pkgs.python312Packages.buildPythonApplication {
          pname = "intentd";
          version = "0.1.0";
          pyproject = true;
          src = self;
          build-system = [ pkgs.python312Packages.hatchling ];
          dependencies = [
            pkgs.python312Packages.pydantic
            pkgs.python312Packages.textual
          ];
          pythonImportsCheck = [ "intentd" ];
        };
        default = intentd;
      });
      checks.x86_64-linux.vm-smoke = (import ./nix/vm-smoke.nix { inherit self nixpkgs; }).test;
      checks.x86_64-linux.vm-scenarios = (import ./nix/vm-scenarios.nix { inherit self nixpkgs; }).test;
      checks.x86_64-linux.vm-cli = (import ./nix/vm-cli.nix { inherit self nixpkgs; }).test;
      checks.x86_64-linux.vm-baseline-pilot =
        (import ./nix/vm-baseline-pilot.nix { inherit self nixpkgs; }).test;
      checks.x86_64-linux.vm-boot-counting =
        (import ./nix/reliability/vm-boot-counting.nix {
          inherit self nixpkgs lanzaboote;
        }).test;
      checks.x86_64-linux.vm-boot =
        (import ./nix/reliability/vm-boot.nix {
          inherit self nixpkgs lanzaboote;
        }).test;
    };
}
