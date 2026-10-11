{
  description = "Development shells for various projects";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        myPython = pkgs.python3.override {
          packageOverrides = pySelf: pySuper: {
            mdtraj = pySuper.mdtraj.overridePythonAttrs (_old: {
              doCheck = false;
            });
            imbalanced-learn = pySuper.imbalanced-learn.overridePythonAttrs (old: {
              propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pySelf.sklearn-compat ];
            });
          };
        };

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
        pythonEnv = myPython.withPackages pythonPackages;
        cbeEnv = myPython.withPackages (
          ps:
          pythonPackages ps
          ++ [
            ps.openmm
            ps.mdtraj
          ]
        );
        mlEnv = myPython.withPackages (
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
              export PYTHONPATH="${mlEnv}/${myPython.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"

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

          default = self.devShells.${system}.ml;
        };
      }
    );
}
