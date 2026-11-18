{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.workstation;
in
{
  options.workstation.enable =
    lib.mkEnableOption "desktop workstation base (audio, bluetooth, input, file manager, utils, git)"
    // {
      default = true;
    };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
        };
      };
    };
    services.blueman.enable = true;

    services.libinput.enable = true;
    services.hardware.bolt.enable = true;

    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };
    programs.xfconf.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;

    services.usbmuxd.enable = true;

    systemd.tmpfiles.rules = [
      "e /home/rupan/media/images/screenshots - - - 30d"
    ];

    programs.git = {
      enable = true;
      config = {
        user.name = "JEFF7712";
        user.email = "rupanpandyan@gmail.com";
        credential."https://github.com".helper = "!gh auth git-credential";
        credential."https://gist.github.com".helper = "!gh auth git-credential";
        init.defaultBranch = "main";
        safe.directory = config.repoPath;
        diff.external = lib.getExe pkgs.difftastic;
      };
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      brightnessctl
      playerctl
      dualsensectl
      zip
      unzip
      libimobiledevice
      ifuse
      gphoto2
    ];
  };
}
