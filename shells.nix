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
      (stdenv.mkDerivation {
        pname = "talosctl";
        version = "1.11.6";
        src = fetchurl {
          url = "https://github.com/siderolabs/talos/releases/download/v1.11.6/talosctl-linux-amd64";
          sha256 = "0d6gql2wm54cp8pqxr8m6lvffql8im6y3rl1680hiawwbxffyj52";
        };
        phases = [ "installPhase" ];
        installPhase = "mkdir -p $out/bin; cp $src $out/bin/talosctl; chmod +x $out/bin/talosctl";
      })
      cilium-cli
    ];
    shellHook = ''echo "Welcome to the homelab Development Shell."'';
  };
}
