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
    lib.mkEnableOption "desktop workstation base (audio, bluetooth, input, file manager, utils, git, launcher cache)"
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
    xdg.mime = {
      defaultApplications = {
        "inode/directory" = "thunar.desktop";
        "application/x-directory" = "thunar.desktop";
      };
      addedAssociations = {
        "inode/directory" = [ "thunar.desktop" ];
        "application/x-directory" = [ "thunar.desktop" ];
      };
      removedAssociations = {
        "inode/directory" = [
          "org.gnome.Nautilus.desktop"
          "nautilus.desktop"
          "org.kde.dolphin.desktop"
          "dolphin.desktop"
          "nemo.desktop"
          "pcmanfm.desktop"
          "caja.desktop"
        ];
        "application/x-directory" = [
          "org.gnome.Nautilus.desktop"
          "nautilus.desktop"
          "org.kde.dolphin.desktop"
          "dolphin.desktop"
          "nemo.desktop"
          "pcmanfm.desktop"
          "caja.desktop"
        ];
      };
    };

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

    nix.settings = {
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
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
