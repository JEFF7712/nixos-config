{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    chatgpt-nixpkgs.url = "github:Moraxyc/nixpkgs/chatgpt-linux";
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Master: version tags are stale vs current nixpkgs vmTools (disko #1027).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
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
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    code-cursor-nix = {
      url = "github:jacopone/code-cursor-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Daily LLM agent binaries. Dedicated opencode-nix flakes are archived.
    opencode-nix = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-agent.url = "github:JEFF7712/nix-agent?ref=v0.11.0";
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
    vicinae.url = "github:vicinaehq/vicinae";
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

      perSystem =
        { pkgs, ... }:
        {
          packages.iris-python = pkgs.callPackage ./pkgs/iris-python { };
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.statix.enable = true;
            programs.deadnix.enable = true;
            programs.qmlformat.enable = true;
            # ruff-check off: its default rules move with nixpkgs; hourly auto-update
            # would fail `nix fmt` / CI with no local change. Run `ruff check` by hand.
            programs.ruff-format.enable = true;
            settings.formatter.statix.excludes = [ "hosts/laptop/hardware-configuration.nix" ];
            settings.formatter.deadnix.excludes = [ "hosts/laptop/hardware-configuration.nix" ];
            # ruff-format matches *.py only; this script is python by shebang.
            settings.formatter.ruff-format.includes = [ "home/scripts/merge-ini-section" ];
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
              # pulled by vesktop's build; revisit when nixpkgs bumps vesktop's electron
              "electron-39.8.10"
            ];
            inherit overlays;
          };

          pkgs-stable = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };

          chatgpt-pkgs = import inputs.chatgpt-nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # vmWithDisko passes a module as vmTools `kernel` (nixpkgs 2026-06 / disko #1027).
          disko-patched = pkgs.applyPatches {
            name = "disko-patched";
            src = inputs.disko;
            patches = [ ./patches/disko-vmtools-kernel.patch ];
          };

          mkSystem =
            host: userModule:
            nixpkgs.lib.nixosSystem {
              inherit system pkgs;
              specialArgs = {
                inherit
                  inputs
                  chatgpt-pkgs
                  pkgs-stable
                  self
                  ;
                diskoModule = "${disko-patched}/module.nix";
              };
              modules = [
                ./hosts/${host}/configuration.nix
                inputs.nix-agent.nixosModules.default
                inputs.vicinae.nixosModules.default
                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = {
                    inherit
                      inputs
                      chatgpt-pkgs
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
