{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/bundle.nix
  ];

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  nvidia.enable = true;
  niri.enable = true;
  general-laptop.enable = true;
  audio.enable = true;
  bluetooth.enable = true;
  filemanager.enable = true;
  podman.enable = true;
  distrobox.enable = true;
  file-utils.enable = true;
  docker.enable = true;
  netbird.enable = true;
  game.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "exfat" ];

  networking.hostName = "workmachine-nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  services.printing.enable = true;

  environment.shells = with pkgs; [ fish ];
  users.users.rupan = {
    isNormalUser = true;
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ tree ];
  };

  environment.systemPackages = with pkgs; [
    wget
    neovim
    pciutils
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
    ];
  };

  services.openssh.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 53 5353 22054 ];
  };

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.dns = "none";

  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings.auto-optimise-store = true;

  system.stateVersion = "25.11";
}

