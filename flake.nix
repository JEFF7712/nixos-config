{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    treefmt-nix.url = "github:numtide/treefmt-nix";
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
    nix-agent.url = "github:JEFF7712/nix-agent?ref=v0.2.0";
    compchem-cctop = {
      url = "github:JEFF7712/cctop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mercury-cli = {
      url = "github:MercuryTechnologies/mercury-cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    globalprotect-openconnect.url = "github:yuezk/GlobalProtect-openconnect";
    niri-blur = {
      url = "github:niri-wm/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stasis = {
      url = "github:saltnpepper97/stasis";
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
      nixvim,
      globalprotect-openconnect,
      ...
    }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { pkgs, ... }:
        {
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };
        };

      flake =
        let
          system = "x86_64-linux";

          aioboto3TestFixOverlay =
            final: prev:
            let
              pythonOverrides =
                pyFinal: pyPrev: {
                  aioboto3 = pyPrev.aioboto3.overridePythonAttrs (old: {
                    disabledTests = (old.disabledTests or [ ]) ++ [
                      "test_dynamo_resource_query"
                      "test_dynamo_resource_put"
                      "test_dynamo_resource_batch_write_flush_on_exit_context"
                      "test_dynamo_resource_batch_write_flush_amount"
                      "test_flush_doesnt_reset_item_buffer"
                      "test_dynamo_resource_property"
                      "test_dynamo_resource_waiter"
                    ];
                  });
                  fastmcp = pyPrev.fastmcp.overridePythonAttrs (old: {
                    doCheck = false;
                  });
                };
            in
            {
              python313Packages = prev.python313Packages.overrideScope pythonOverrides;
              python3Packages = final.python313Packages;
            };

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.permittedInsecurePackages = [
              "electron-37.10.3"
            ];
            overlays = [
              aioboto3TestFixOverlay
              nix-vscode-extensions.overlays.default
              inputs.niri-blur.overlays.default
            ];
          };

          pkgs-stable = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };

          mkSystem =
            host: userModule:
            nixpkgs.lib.nixosSystem {
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

        in
        {
          nixosConfigurations = {
            laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
            iso = mkSystem "iso" ./home/rupan/iso.nix;
          };
        };
    };
}
