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
            mdtraj = pySuper.mdtraj.overridePythonAttrs (old: {
              doCheck = false;
            });
            imbalanced-learn = pySuper.imbalanced-learn.overridePythonAttrs (old: {
              propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pySelf.sklearn-compat ];
            });
          };
        };

        pythonEnv = myPython.withPackages (
          ps: with ps; [
            numpy
            pandas
            requests
            matplotlib
            openpyxl
            scikit-learn
            scipy
            torch
            torch-geometric
            openmm
            mdtraj
            plotly
            jupyterlab
            pip
            virtualenv
          ]
        );
      in
      {
        devShells = {
          python = pkgs.mkShell {
            packages = [ pythonEnv ];
            shellHook = ''echo "Python Shell ready." '';
          };

          cbe = pkgs.mkShell {
            packages = [
              pythonEnv
              pkgs.openblas
            ];
            shellHook = ''echo "CBE Shell ready." '';
          };

          ml = pkgs.mkShell {
            packages = [
              pythonEnv
            ];

            shellHook = ''
              if [ ! -d ".venv" ]; then
                echo "Creating new virtual environment..."
                virtualenv .venv
              fi
              source .venv/bin/activate

              export PIP_PREFIX="$(pwd)/.build/pip_packages"
              export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"

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
