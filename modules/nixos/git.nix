{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.git.enable = lib.mkEnableOption "git";

  config = lib.mkIf config.git.enable {
    programs.git = {
      enable = true;
      config = {
        user.name = "JEFF7712";
        user.email = "rupanpandyan@gmail.com";
        credential."https://github.com".helper = "!gh auth git-credential";
        credential."https://gist.github.com".helper = "!gh auth git-credential";
        init.defaultBranch = "main";
        safe.directory = "/home/rupan/nixos";
      };
    };
  };
}
