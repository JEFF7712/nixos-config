{ pkgs, pythonEnv }:

{
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
      talosctl
      cilium-cli
      kubernetes-helm
      argocd
    ];
    shellHook = ''echo "Welcome to the homelab Development Shell."'';
  };
}
