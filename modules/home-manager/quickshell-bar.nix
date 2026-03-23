# modules/home-manager/quickshell-bar.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  qs = inputs.quickshell.packages.${pkgs.system}.default;
in
{
  options.quickshell-bar.enable = lib.mkEnableOption "quickshell bar";

  config = lib.mkIf config.quickshell-bar.enable {
    home.packages = [
      qs
      pkgs.brightnessctl
      pkgs.playerctl
    ];

    # Symlink the QML source directory as out-of-store so it's editable without rebuild.
    xdg.configFile."quickshell".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/quickshell";

    # Systemd user service — only starts when the active profile is NOT noctalia.
    systemd.user.services.quickshell-bar = {
      Unit = {
        Description = "Quickshell bar (non-noctalia profiles)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecCondition = "${pkgs.bash}/bin/bash -c '[ \"$(cat %h/.config/desktop-profiles/active 2>/dev/null || echo noctalia)\" != \"noctalia\" ]'";
        ExecStart = "${qs}/bin/quickshell";
        Environment = "NIRI_SOCKET=/run/user/%U/niri.sock";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
