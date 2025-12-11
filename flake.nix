{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, spicetify-nix, ... }@inputs:     
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    python = pkgs.python311;
  in {

    nixosConfigurations = {
      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	      specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop/configuration.nix
          home-manager.nixosModules.home-manager 
	  {
	    home-manager.useGlobalPkgs = true;
	    home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "backup";
	    home-manager.users.rupan = import ./home/rupan/laptop.nix;
	  }
        ];
      };

      workmachine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
	        modules = [
	  ./hosts/workmachine/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.rupan = import ./home/rupan/workmachine.nix;
          }
	];
      };

      homelab = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/homelab/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.rupan = import ./home/rupan/homelab.nix;
          }
        ];
      };
    };

    devShells.${system} = {
      python = pkgs.mkShell {
        packages = [
          (python.withPackages (ps: with ps; [
            ps.numpy
            ps.pandas
            ps.scikit-learn
            ps.requests
	    ps.matplotlib
            ps.openpyxl
          ]))
          pkgs.openblas
        ];

        shellHook = ''
          echo "Welcome to the Python Development Shell."
        '';
      };

      # Add more shells here
      default = self.devShells.${system}.python;
    };
  };
}
