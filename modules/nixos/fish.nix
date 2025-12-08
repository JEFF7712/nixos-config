{ pkgs, lib, config, ... }: {
  options.fish.enable = lib.mkEnableOption "fish";

  config = lib.mkIf config.fish.enable {
    programs.fish.enable = true;
    users.users.rupan.shell = pkgs.fish;
  };
}
