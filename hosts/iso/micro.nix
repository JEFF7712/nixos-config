{ pkgs, modulesPath, lib, ... }: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  isoImage.squashfsCompression = "xz";

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    git
    neovim
    wget
    rsync
    fish
    starship
    
    # The Script
    (pkgs.writeShellScriptBin "get-config" ''
      echo "Checking internet..."
      if ping -c 1 github.com &> /dev/null; then
          echo "Connected! Cloning..."
          rm -rf /home/nixos/nixos-config
          ${pkgs.git}/bin/git clone https://github.com/JEFF7712/nixos-config.git /home/nixos/nixos
          echo "✅ Config downloaded to ~/nixos"
      else
          echo "❌ No Internet. Run 'nmtui' to connect."
      fi
    '')
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
    initialHashedPassword = "";
  };

  programs.fish.enable = true;

  documentation.enable = false;
  documentation.nixos.enable = false;
  
  networking.hostName = "rupan-nixos";
}
