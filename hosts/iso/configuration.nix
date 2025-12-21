{ config, lib, pkgs, modulesPath, self, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix"
    ../../modules/nixos/bundle.nix
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  
  fileSystems = lib.mkForce {
    "/" = {
      device = "overlay";
      fsType = "overlay";
      options = [ "lowerdir=/nix/store" "upperdir=/run/current-system" "workdir=/run/workdir" ];
    };
  };

  isoImage.squashfsCompression = "zstd";

  environment.etc."nixos-config-source".source = self;

  system.activationScripts.copyConfig = ''
    if [ ! -d /home/rupan/nixos-config ]; then
      echo "Copying config to home directory..."
      mkdir -p /home/rupan
      ${pkgs.rsync}/bin/rsync -av --chmod=u+w /etc/nixos-config-source/ /home/rupan/nixos-config/
      chown -R rupan:users /home/rupan/nixos-config
    fi
  '';

  networking.hostName = "rupan-live-iso";
  
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  niri.enable = true;
  general-laptop.enable = true;  
  audio.enable = true;
  ctls.enable = true; 
  bluetooth.enable = true;
  filemanager.enable = true;
  file-utils.enable = true;  

  users.users.rupan = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
    initialHashedPassword = ""; 
    packages = with pkgs; [ tree ];
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "rupan";

  environment.shells = with pkgs; [ fish ];
  environment.systemPackages = with pkgs; [
    wget 
    neovim 
    pciutils
    rsync
  ];

  services.power-profiles-daemon.enable = true;
  services.printing.enable = true;
  services.libinput.enable = true;
  services.openssh.enable = true;
  
  services.xserver.videoDrivers = [ "modesetting" "fbdev" ];

  time.timeZone = "America/Chicago";

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.dns = "none";

  system.stateVersion = "25.11"; 
}