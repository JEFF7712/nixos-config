{ pkgs, lib, config, ... }: {
  options.dev.enable = lib.mkEnableOption "dev";

  config = lib.mkIf config.dev.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home.packages = with pkgs; [
      terraform
      ansible
      kubectl
      terragrunt
      (pkgs.runCommand "talosctl-1.11.6" {
        src = pkgs.fetchurl {
          url = "https://github.com/siderolabs/talos/releases/download/v1.11.6/talosctl-linux-amd64";
          sha256 = "0d6gql2wm54cp8pqxr8m6lvffql8im6y3rl1680hiawwbxffyj52";
        };
      } ''
        mkdir -p $out/bin
        cp $src $out/bin/talosctl
        chmod +x $out/bin/talosctl
      '')
      fluxcd
      gemini-cli
      geminicommit
    ];
  };
}
