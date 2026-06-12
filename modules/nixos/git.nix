{
  lib,
  config,
  pkgs,
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
        # difftastic for human-facing diffs; --no-ext-diff to opt out.
        # git log -p / git show need --ext-diff to use it.
        diff.external = lib.getExe pkgs.difftastic;
      };
    };
  };
}
