{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix"
    ../../modules/nixos/niri.nix
    ../../modules/nixos/general-laptop.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/ctls.nix
    ../../modules/nixos/bluetooth.nix
    ../../modules/nixos/filemanager.nix
    ../../modules/nixos/file-utils.nix
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;

  isoImage.squashfsCompression = "xz";

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
    git
    (pkgs.writeShellScriptBin "get-config" ''
      echo "Checking internet connection..."
      if ping -c 1 github.com &> /dev/null; then
          echo "Connected! Updating repository..."

          TARGET_DIR="/home/rupan/nixos"

          if [ -d "$TARGET_DIR/.git" ]; then
              cd "$TARGET_DIR"
              ${pkgs.git}/bin/git pull
              echo "✅ Config updated from GitHub."
          else
              echo "Resyncing fresh from GitHub..."
              rm -rf "$TARGET_DIR"
              ${pkgs.git}/bin/git clone https://github.com/JEFF7712/nixos-config.git "$TARGET_DIR"
              echo "✅ Config downloaded to $TARGET_DIR"
          fi
      else
          echo "❌ No Internet Connection."
      fi
    '')
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
