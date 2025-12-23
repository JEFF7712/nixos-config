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

      devShells.${system} = {
        cbe = pkgs.mkShell {
          packages = [ pythonEnv pkgs.openblas ];
          shellHook = ''echo "Welcome to the CBE Development Shell."'';
        };
        homelab = pkgs.mkShell {
          packages = with pkgs; [ 
            kubectl
            terraform
            terragrunt
            ansible
            fluxcd
            (stdenv.mkDerivation {
              pname = "talosctl";
              version = "1.11.6";
              src = fetchurl {
                url = "https://github.com/siderolabs/talos/releases/download/v1.11.6/talosctl-linux-amd64";
                hash = "sha256-0d6gql2wm54cp8pqxr8m6lvffql8im6y3rl1680hiawwbxffyj52="; # Ensure SRI format
              };
              phases = [ "installPhase" ];
              installPhase = ''
                mkdir -p $out/bin
                cp $src $out/bin/talosctl
                chmod +x $out/bin/talosctl
              '';
            })
          ];
          shellHook = ''echo "Welcome to the homelab Development Shell."'';
        };

        default = self.devShells.${system}.cbe;
      };
    };
  };
}
