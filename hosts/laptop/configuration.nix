{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  nixosLogoPlymouthTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "nixos-logo-plymouth-theme";
    version = "1";
    dontUnpack = true;

    installPhase = ''
            theme_dir="$out/share/plymouth/themes/nixos-logo"
            mkdir -p "$theme_dir"

            cat > "$theme_dir/nixos-logo.plymouth" <<EOF
      [Plymouth Theme]
      Name=NixOS Logo
      Description=Minimal Plymouth theme that shows only the NixOS logo
      ModuleName=script

      [script]
      ImageDir=$theme_dir
      ScriptFile=$theme_dir/nixos-logo.script
      EOF

            cat > "$theme_dir/nixos-logo.script" <<'EOF'
      Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
      Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

      logo.image = Image("special://logo");
      logo.sprite = Sprite();

      fun center_logo()
      {
        logo.sprite.SetImage(logo.image);
        logo.sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
        logo.sprite.SetY(Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
        logo.sprite.SetZ(100);
        logo.sprite.SetOpacity(1);
      }

      center_logo();
      Plymouth.SetRefreshFunction(center_logo);

      fun quit_callback()
      {
        center_logo();
      }

      Plymouth.SetQuitFunction(quit_callback);
      EOF
    '';
  };
in

{
  imports = [
    ./hardware-configuration.nix
    (inputs.import-tree ../../modules/nixos)
  ];

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 4;
      cores = 4;
    };
  };

  nvidia.enable = true;
  niri.enable = true;
  general-laptop.enable = true;
  audio.enable = true;
  ctls.enable = true;
  bluetooth.enable = true;
  filemanager.enable = true;
  screenshot-cleanup.enable = true;
  battery-threshold.enable = true;
  podman.enable = true;
  distrobox.enable = true;
  file-utils.enable = true;
  docker.enable = true;
  netbird.enable = true;
  waydroid.enable = true;
  game.enable = true;
  airplay.enable = true;
  vpn.enable = true;
  git.enable = true;
  xhisperLocal.enable = true;

  environment.shells = with pkgs; [
    fish
    bash
  ];
  system.activationScripts.binbash = lib.stringAfter [ "usrbinenv" ] ''
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';
  users.users.rupan.shell = pkgs.fish;
  users.users.rupan.ignoreShellProgramCheck = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];

  services.power-profiles-daemon.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
  services.tlp.enable = false;
  services.auto-cpufreq.enable = false;

  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;
  };

  boot = {
    # Use the systemd-boot EFI boot loader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "exfat" ];

    plymouth = {
      enable = true;
      theme = "nixos-logo";
      themePackages = [ nixosLogoPlymouthTheme ];
      logo = "${pkgs.nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake.png";
    };

    # Keep boot output quiet so Plymouth stays visible unless something fails.
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
    ];
  };
  networking.hostName = "laptop-nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.rupan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "rupan" ];
      commands = [
        {
          command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild dry-activate --flake *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    wget
    neovim
    pciutils
    qemu_kvm
    virtiofsd
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  security.pam.services.hyprlock = { };

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

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [
      53317
      53
      5353
      22054
    ];
  };

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
  networking.networkmanager.dns = "none";
  networking.networkmanager.wifi.scanRandMacAddress = false;
  networking.networkmanager.wifi.macAddress = "preserve";
  networking.wireless.iwd.enable = false;

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

  # Homelab Attic binary cache.
  # extra-substituters: make the daemon fetch from it.
  # extra-trusted-substituters: let non-trusted users (i.e. not root) use it.
  # extra-trusted-public-keys: verify signatures from it.
  # accept-flake-config: auto-accept any flake's nixConfig.extra-substituters /
  #   trusted-public-keys / etc. without the interactive y/N prompt that hangs
  #   direnv (direnv has no stdin to answer). Saved per-flake answers live in
  #   ~/.local/share/nix/trusted-settings.json; this is the global escape hatch.
  nix.settings.extra-substituters = [ "http://10.0.20.190:8080/homelab" ];
  nix.settings.extra-trusted-substituters = [ "http://10.0.20.190:8080/homelab" ];
  nix.settings.extra-trusted-public-keys = [
    "homelab:s17u8G3szjlQ6UmMAPsszVS/J1jaw6gDwSDM9+/QeNQ="
  ];
  nix.settings.accept-flake-config = true;

  system.stateVersion = "25.11"; # DO NOT EDIT
}
