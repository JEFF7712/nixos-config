{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

{
  home.username = "developer";
  home.homeDirectory = "/home/developer";
  home.stateVersion = "25.11";

  home.sessionVariables.EDITOR = "nvim";
  programs.home-manager.enable = true;

  imports = [
    ../../modules/home-manager/repo-path.nix
    ../../modules/home-manager/terminal.nix
    ../../modules/home-manager/dev.nix
    ../../modules/home-manager/cli/cli-tools.nix
  ];

  terminal.enable = true;
  dev.enable = true;
  cli-tools.enable = true;

  programs.git = {
    enable = true;
    userName = "JEFF7712";
    userEmail = "rupanpandyan@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      credential."https://github.com".helper = "!gh auth git-credential";
      credential."https://gist.github.com".helper = "!gh auth git-credential";
      diff.external = lib.getExe pkgs.difftastic;
    };
  };
}
