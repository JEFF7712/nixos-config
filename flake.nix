{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
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
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deepagents = {
      url = "github:langchain-ai/deepagents";
      flake = false;
    };
    nix-agent.url = "github:JEFF7712/nix-agent?ref=v0.1.3";
    globalprotect-openconnect.url = "github:yuezk/GlobalProtect-openconnect";
    niri-blur = {
      url = "github:niri-wm/niri?ref=refs/heads/wip/branch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, nix-vscode-extensions, nixvim, globalprotect-openconnect,... }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-37.10.3"
        ];
        overlays = [
          nix-vscode-extensions.overlays.default
          inputs.niri-blur.overlays.default
        ];
      };

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      mkSystem = host: userModule: nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = { inherit inputs pkgs-stable; };
        modules = [
          ./hosts/${host}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs pkgs-stable; };
            home-manager.backupFileExtension = "backup";
            home-manager.users.rupan = import userModule;
          }
        ];
      };

    in {
      nixosConfigurations = {
        laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
        iso = mkSystem "iso" ./home/rupan/laptop.nix;
      };
  };
}
