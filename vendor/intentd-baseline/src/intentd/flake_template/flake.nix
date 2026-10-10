{
  description = "intentd product-owned system flake (Stage 1 wedge)";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }: {
    nixosConfigurations.intentd = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./base.nix
        ./generated.nix
      ];
    };
  };
}
