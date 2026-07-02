{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.secrets.enable = lib.mkEnableOption "sops-nix secrets (decrypted via the host SSH key)";

  config = lib.mkIf config.secrets.enable {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      # Decryption key at activation. Editing as rupan uses the separate age
      # key in ~/.config/sops/age/keys.txt; both are recipients in .sops.yaml.
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # attic client config incl. the homelab push token; consumed by the
      # atticPush home-manager module via a symlink into /run/secrets.
      secrets.attic-config-toml = {
        owner = "rupan";
        mode = "0400";
      };
    };

    environment.systemPackages = with pkgs; [
      sops
      age
      ssh-to-age
    ];
  };
}
