{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # The chatgpt-linux branch was deleted when NixOS/nixpkgs#551713 merged;
    # a branch ref makes every `nix flake update` fail.
    chatgpt-nixpkgs.url = "github:Moraxyc/nixpkgs/38964bbbe2d2b277eb2d1659d2be52a082cfa487";
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
    intentd = {
      # Vendored baseline snapshot (vendor/intentd-baseline): the upstream
      # checkout has no remote, and the previous absolute /nix/store path
      # input evaluated only on machines already holding that store path.
      # Refresh vendor/ deliberately and re-lock when rebasing.
      url = "path:./vendor/intentd-baseline";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lanzaboote.follows = "lanzaboote";
    };
    # Master: version tags are stale vs current nixpkgs vmTools (disko #1027).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
    comin = {
      url = "github:nlewo/comin/v0.14.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
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
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Daily LLM agent binaries. Dedicated opencode-nix flakes are archived.
    # Does NOT follow the main nixpkgs: its packages (e.g. fx) need a zig
    # version newer than our pin, so it carries its own newer nixpkgs.
    opencode-nix = {
      url = "github:numtide/llm-agents.nix";
    };
    nix-agent = {
      url = "github:JEFF7712/nix-agent?ref=v0.15.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    vicinae = {
      url = "github:vicinaehq/vicinae";
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
      home-manager,
      nix-vscode-extensions,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      overlays = import ./overlays {
        inherit nix-vscode-extensions;
        inherit (inputs) vicinae;
      };

      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

      chatgpt-pkgs = import inputs.chatgpt-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ system ];
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { self', ... }:
        let
          pythonPackages =
            ps: with ps; [
              numpy
              pandas
              requests
              matplotlib
              openpyxl
              scipy
              plotly
            ];
          pythonEnv = pkgs.python3.withPackages pythonPackages;
          cbeEnv = pkgs.python3.withPackages (
            ps:
            pythonPackages ps
            ++ [
              ps.openmm
              ps.mdtraj
            ]
          );
          mlEnv = pkgs.python3.withPackages (
            ps:
            pythonPackages ps
            ++ (with ps; [
              scikit-learn
              torch
              torch-geometric
              openmm
              mdtraj
              jupyterlab
              virtualenv
            ])
          );
        in
        {
          _module.args.pkgs = pkgs;

          packages.iris-python = pkgs.iris-python;

          devShells = {
            c = pkgs.mkShell {
              packages = with pkgs; [
                bear
                clang
                clang-tools
                cmake
                cppcheck
                gdb
                gcc
                gnumake
                lldb
                ninja
                pkg-config
                valgrind
              ];
              shellHook = ''
                export CC=gcc
                export CXX=g++
                echo "C development shell ready."
              '';
            };

            python = pkgs.mkShell {
              packages = [ pythonEnv ];
              shellHook = ''echo "Python Shell ready." '';
            };

            cbe = pkgs.mkShell {
              packages = [
                cbeEnv
                pkgs.openblas
              ];
              shellHook = ''echo "CBE Shell ready." '';
            };

            ml = pkgs.mkShell {
              packages = [
                mlEnv
                pkgs.uv
              ];
              shellHook = ''
                if [ ! -d ".venv" ]; then
                  echo "Creating new virtual environment..."
                  uv venv --system-site-packages --python ${mlEnv}/bin/python3 .venv
                fi
                source .venv/bin/activate
                export PYTHONPATH="${mlEnv}/${pkgs.python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
                export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.libGL}/lib:$LD_LIBRARY_PATH"
                unset SOURCE_DATE_EPOCH
                echo "Virtual environment (.venv) activated."
                echo "Machine Learning Python Shell ready."
              '';
            };

            homelab = pkgs.mkShell {
              packages = with pkgs; [
                kubectl
                terraform
                terragrunt
                ansible
                talosctl
                cilium-cli
                kubernetes-helm
                argocd
                k9s
                kubeseal
              ];
              shellHook = ''echo "Welcome to the homelab Development Shell."'';
            };

            default = self'.devShells.ml;
          };

          # Forces checks/laptop-safety.nix and checks/profiles.nix asserts at
          # eval; owned by `nix flake check` so just/CI share one laptop eval.
          checks.laptop-safety = pkgs.runCommand "laptop-safety" { } ''
            echo ${
              builtins.seq (import ./checks/laptop-safety.nix {
                config = self.nixosConfigurations.laptop.config;
              }) "ok"
            } > $out
          '';
          checks.profiles =
            let
              res = import ./checks/profiles.nix self.nixosConfigurations.laptop.config.home-manager.users.rupan.home.file;
            in
            assert res.ok && res.count > 0;
            pkgs.runCommand "desktop-profiles-check" { } ''
              echo "${toString res.count} profiles ok: ${builtins.concatStringsSep " " res.names}" > $out
            '';
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.statix.enable = true;
            programs.deadnix.enable = true;
            programs.qmlformat.enable = true;
            # ruff-check off: its default rules move with nixpkgs; lock updates
            # would fail `nix fmt` / CI with no local change. Run `ruff check` by hand.
            programs.ruff-format.enable = true;
            # vendor/ holds frozen upstream snapshots (e.g. the intentd
            # baseline); never reformat them, refresh deliberately instead.
            settings.formatter.nixfmt.excludes = [ "vendor/*" ];
            settings.formatter.statix.excludes = [
              "hosts/laptop/hardware-configuration.nix"
              "vendor/*"
            ];
            settings.formatter.deadnix.excludes = [
              "hosts/laptop/hardware-configuration.nix"
              "vendor/*"
            ];
            # ruff-format matches *.py only; this script is python by shebang.
            settings.formatter.ruff-format.includes = [ "home/scripts/merge-ini-section" ];
          };
        };

      flake =
        let
          mkSystem =
            host: user: userModule:
            nixpkgs.lib.nixosSystem {
              inherit system pkgs;
              specialArgs = {
                inherit
                  inputs
                  chatgpt-pkgs
                  self
                  ;
                diskoModule = "${inputs.disko}/module.nix";
              };
              modules = [
                ./hosts/${host}/configuration.nix
                inputs.nix-agent.nixosModules.default
                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = {
                    inherit
                      inputs
                      chatgpt-pkgs
                      self
                      ;
                  };
                  home-manager.backupFileExtension = "backup";
                  home-manager.users.${user} = import userModule;
                }
              ];
            };
        in
        {
          nixosConfigurations = {
            laptop = mkSystem "laptop" "rupan" ./home/rupan/laptop.nix;
            iso = mkSystem "iso" "rupan" ./home/rupan/iso.nix;
            vm = mkSystem "vm" "developer" ./home/rupan/vm.nix;
          };
        };
    };
}
