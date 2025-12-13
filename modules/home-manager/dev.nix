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
      sshpass
    ];
  };
}
