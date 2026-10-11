{
  lib,
  pkgs,
  inputs,
  modulesPath,
  self,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix"
    (inputs.import-tree ../../modules/nixos)
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;

  environment.etc."nixos-config-source".source = self;

  system.activationScripts.copyConfig = lib.stringAfter [ "users" "etc" ] ''
    if [ ! -d /home/rupan/nixos ]; then
      mkdir -p /home/rupan
      ${pkgs.rsync}/bin/rsync -av --chmod=u+w /etc/nixos-config-source/ /home/rupan/nixos/
      chown -R rupan:users /home/rupan/nixos
    fi
  '';

  isoImage.squashfsCompression = lib.mkForce "zstd";

  networking.hostName = "rupan-live-iso";

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  niri.enable = true;
  # workstation (audio, bluetooth, file manager, git) defaults on.

  users.users.rupan = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "dialout"
      "video"
    ];
    shell = pkgs.fish;
    initialHashedPassword = "";
  };

  programs.fish.enable = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "rupan";

  environment.shells = with pkgs; [ fish ];
  environment.systemPackages = with pkgs; [
    wget
    neovim
    pciutils
    rsync
    git
    (pkgs.writeShellApplication {
      name = "get-config";
      runtimeInputs = with pkgs; [
        git
        coreutils
      ];
      text = builtins.readFile ../../home/scripts/get-config;
    })
  ];

  services.power-profiles-daemon.enable = true;
  services.printing.enable = true;
  services.libinput.enable = true;
  # Installer profile enables sshd; disable it so setting a password does not
  # expose well-known accounts over the network.
  services.openssh.enable = lib.mkForce false;

  services.xserver.videoDrivers = [
    "modesetting"
    "fbdev"
  ];

  time.timeZone = "America/Chicago";

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
  networking.networkmanager.dns = "none";

  system.stateVersion = "25.11";
}
