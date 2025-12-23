{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-vscode-extensions, ... }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nix-vscode-extensions.overlays.default ];
      };

      mkSystem = host: userModule: nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${host}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "backup";
            home-manager.users.rupan = import userModule;
          }
        ];
      };

      pythonEnv = pkgs.python311.withPackages (ps: with ps; [
        numpy pandas scikit-learn requests matplotlib openpyxl
      ]);

      Shells = import ./shells.nix { inherit pkgs pythonEnv; };

    in {
      nixosConfigurations = {
        laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
        workmachine = mkSystem "workmachine" ./home/rupan/workmachine.nix;
        homelab = mkSystem "homelab" ./home/rupan/homelab.nix;
        iso = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = { inherit inputs self; };
        modules = [
          ./hosts/iso/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.rupan = import ./home/rupan/laptop.nix;
          }
        ];
      };
    };
    devShells.${system} = Shells // {
      default = Shells.cbe;
    };
  };
}
