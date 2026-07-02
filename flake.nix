{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-agent.url = "github:JEFF7712/nix-agent?ref=v0.5.0";
    compchem-cctop = {
      url = "github:JEFF7712/cctop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mercury-cli = {
      url = "github:MercuryTechnologies/mercury-cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    globalprotect-openconnect = {
      url = "github:yuezk/GlobalProtect-openconnect";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stasis = {
      url = "github:saltnpepper97/stasis";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    terax = {
      url = "github:JEFF7712/terax-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    asus-numberpad-driver = {
      url = "github:asus-linux-drivers/asus-numberpad-driver/v7.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      nix-vscode-extensions,
      ...
    }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem = _: {
        treefmt = {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.statix.enable = true;
          programs.deadnix.enable = true;
          programs.qmlformat.enable = true;
          settings.formatter.statix.excludes = [ "hosts/laptop/hardware-configuration.nix" ];
          settings.formatter.deadnix.excludes = [ "hosts/laptop/hardware-configuration.nix" ];
        };
      };

      flake =
        let
          system = "x86_64-linux";
          overlays = import ./overlays {
            inherit nix-vscode-extensions;
          };

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.permittedInsecurePackages = [
              "electron-37.10.3"
              "electron-39.8.10"
              # build-time dep pinned by vesktop; drop once nixpkgs bumps it
              "pnpm-10.29.2"
            ];
            inherit overlays;
          };

          pkgs-stable = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };

          mkSystem =
            host: userModule:
            nixpkgs.lib.nixosSystem {
              inherit system pkgs;
              specialArgs = {
                inherit
                  inputs
                  pkgs-stable
                  self
                  ;
              };
              modules = [
                ./hosts/${host}/configuration.nix
                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = {
                    inherit
                      inputs
                      pkgs-stable
                      self
                      ;
                  };
                  home-manager.backupFileExtension = "backup";
                  home-manager.users.rupan = import userModule;
                }
              ];
            };

        in
        {
          nixosConfigurations = {
            laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
            iso = mkSystem "iso" ./home/rupan/iso.nix;
          };
        };
    };
}
