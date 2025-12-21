{ config, lib, pkgs, modulesPath, ... }:

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