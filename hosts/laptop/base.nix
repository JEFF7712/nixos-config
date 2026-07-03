{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    (inputs.import-tree ../../modules/nixos)
  ];

  nix = {
    package = pkgs.nix;
    # Pure-flake setup: no channels, and pin the registry + NIX_PATH to the
    # locked nixpkgs so `nix run nixpkgs#foo`, comma, and `nix-shell -p`
    # all resolve to the same rev as the running system.
    channel.enable = false;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = "auto";
      cores = 0;
      download-buffer-size = 268435456;
    };
  };

  nvidia.enable = true;
  secrets.enable = true;
  secureboot.enable = true;
  niri.enable = true;
  general-laptop.enable = true;
  asus-numpad.enable = true;
  audio.enable = true;
  ctls.enable = true;
  bluetooth.enable = true;
  filemanager.enable = true;
  screenshot-cleanup.enable = true;
  battery-threshold.enable = false;
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
  xhisperLocal = {
    enable = true;
    ollama.package = pkgs.ollama-cuda;
  };

  # `just vm` boots this config in QEMU. Strip hardware-bound pieces and give
  # the VM a usable login: the real machine's password is imperative state
  # that doesn't exist inside the VM image.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 8;
    };
    nvidia.enable = lib.mkForce false;
    # docker.nix enables this too; without the nvidia driver it fails an assert.
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    # The VM's host key can't decrypt secrets.yaml; sops would fail activation.
    secrets.enable = lib.mkForce false;
    users.users.rupan.initialPassword = "rupan";
  };

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
  services.thermald.enable = true;
  services.fwupd.enable = true;
  services.asusd.enable = true;
  zramSwap.enable = true;
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
    # nh clean prunes profiles, but ESP entries only shrink at the next
    # switch; cap them so /boot can't fill up silently.
    loader.systemd-boot.configurationLimit = 10;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "exfat" ];

    plymouth = {
      enable = true;
      theme = "nixos-logo";
      themePackages = [ pkgs.plymouth-nixos-logo ];
      inherit (pkgs.plymouth-nixos-logo) logo;
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

  # switch/test are pinned to this repo's exact flake refs — a wildcard here
  # would let any flake URI run as root. dry-activate stays globbed for
  # nix-agent's headless dry runs.
  security.sudo.extraRules = [
    {
      users = [ "rupan" ];
      commands =
        let
          rebuild = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
          nh = "${pkgs.nh}/bin/nh";
          flakeRefs = [
            "path\\:/home/rupan/nixos\\#laptop"
            "/home/rupan/nixos\\#laptop"
            ".\\#laptop"
          ];
        in
        [
          {
            command = "${rebuild} dry-activate --flake *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${nh} os switch -R . -H laptop";
            options = [ "NOPASSWD" ];
          }
        ]
        ++ lib.concatMap (ref: [
          {
            command = "${rebuild} switch --flake ${ref}";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${rebuild} test --flake ${ref}";
            options = [ "NOPASSWD" ];
          }
        ]) flakeRefs;
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

  auto-update.enable = true;

  programs.nh = {
    enable = true;
    flake = "/home/rupan/nixos";
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep-since 7d --keep 3";
    };
  };

  nix.optimise.automatic = true;

  # Homelab Attic binary cache. Disabled while the homelab is offline.
  # extra-substituters: make the daemon fetch from it.
  # extra-trusted-substituters: let non-trusted users (i.e. not root) use it.
  # extra-trusted-public-keys: verify signatures from it.
  # accept-flake-config: auto-accept any flake's nixConfig.extra-substituters /
  #   trusted-public-keys / etc. without the interactive y/N prompt that hangs
  #   direnv (direnv has no stdin to answer). Saved per-flake answers live in
  #   ~/.local/share/nix/trusted-settings.json; this is the global escape hatch.
  # nix.settings.extra-substituters = [ "http://10.0.20.190:8080/homelab" ];
  # nix.settings.extra-trusted-substituters = [ "http://10.0.20.190:8080/homelab" ];
  # nix.settings.extra-trusted-public-keys = [
  #   "homelab:s17u8G3szjlQ6UmMAPsszVS/J1jaw6gDwSDM9+/QeNQ="
  # ];
  nix.settings.accept-flake-config = true;

  system.stateVersion = "25.11"; # DO NOT EDIT
}
