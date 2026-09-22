{
  pkgs,
  lib,
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
    ../../modules/home-manager/nixvim.nix
    ../../modules/home-manager/dev.nix
    ../../modules/home-manager/cli/cli-tools.nix
  ];

  terminal.enable = true;
  nixvim.enable = true;
  dev.enable = true;
  cli-tools.enable = true;

  # Standalone HM has no home-manager.backupFileExtension option (that path is
  # NixOS-only). Export the same env `home-manager switch -b` sets so collisions
  # rename to *.backup instead of failing activation.
  home.activation.homeManagerBackupExt = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    export HOME_MANAGER_BACKUP_EXT=backup
  '';

  programs.git = {
    enable = true;
    settings = {
      user.name = "JEFF7712";
      user.email = "rupanpandyan@gmail.com";
      init.defaultBranch = "main";
      credential."https://github.com".helper = "!gh auth git-credential";
      credential."https://gist.github.com".helper = "!gh auth git-credential";
      diff.external = lib.getExe pkgs.difftastic;
    };
  };
}
