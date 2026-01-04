{ pkgs, CBEpythonEnv, pythonEnv }:

{
  cbe = pkgs.mkShell {
    packages = [ CBEpythonEnv pkgs.openblas ];
    shellHook = ''echo "Welcome to the CBE Development Shell."'';
  };

  python = pkgs.mkShell {
packages = [
      pythonEnv
      pkgs.python3Packages.pip
      pkgs.python3Packages.virtualenv
      pkgs.linuxPackages.nvidia_x11
      pkgs.libGL
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ];

    shellHook = ''
      export PIP_PREFIX="$(pwd)/.build/pip_packages"
      export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.libGL}/lib:$LD_LIBRARY_PATH"
      unset SOURCE_DATE_EPOCH
      echo "PyTorch Shell"
    '';
  };

  homelab = pkgs.mkShell {
    packages = with pkgs; [ 
      kubectl
      terraform
      terragrunt
      ansible
      fluxcd
      talosctl
      cilium-cli
      kubernetes-helm
      argocd
      k9s
    ];
    shellHook = ''echo "Welcome to the homelab Development Shell."'';
  };
}
