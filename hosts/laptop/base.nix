{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:

{
  imports = [
    (inputs.import-tree ../../modules/nixos)
  ];

  nix = {
    package = pkgs.nix;
    # Pin registry + NIX_PATH to locked nixpkgs so ad-hoc `nix run` matches the system.
    channel.enable = false;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # `auto` OOM'd this ~31G box. oom-protection is the backstop.
      max-jobs = 2;
      cores = 8;
      max-substitution-jobs = 16;
      download-buffer-size = 268435456;
    };
  };

  nvidia.enable = true;
  secrets.enable = true;
  secureboot.enable = true;
  niri.enable = true;
  niri-greeter.enable = true;
  general-laptop.enable = true;
  oom-protection.enable = true;
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
  waydroid.enable = false;
  game.enable = true;
  airplay.enable = true;
  vpn.enable = true;
  git.enable = true;
  vicinae.enable = true;
  xhisperLocal = {
    enable = true;
    ollama.package = pkgs.ollama-cuda;
  };

  # `just vm`: strip hardware-bound pieces; the real password is imperative state.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 8;
    };
    nvidia.enable = lib.mkForce false;
    # docker.nix enables this; without the nvidia driver it fails an assert.
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
  programs.fish.enable = true;

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
    pam
  ];

  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.fwupd.enable = true;
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.systembus-notify.enable = true;
  };
  services.asusd.enable = true;
  zramSwap.enable = true;
  # logind cannot see idle inhibit; lid handling stays in Stasis (lid-close-action).
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
    loader.systemd-boot.enable = true;
    # Brief flash instead of the ~5s default; hold a key to catch it.
    loader.timeout = 3;
    # `e` at the boot menu would append init=/bin/sh (defeats secure boot / LUKS).
    loader.systemd-boot.editor = false;
    # /tmp is on root and nothing prunes it (nix builds, chromium sockets, agent scratch).
    tmp.cleanOnBoot = true;
    # zram is RAM-speed: swap aggressively, skip readahead.
    kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };
    # ESP entries only shrink at the next switch; cap so /boot can't fill up.
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
  networking.hostName = "laptop-nixos";

  networking.networkmanager.enable = true;
  # Don't block boot on the network being fully up (~5s off graphical.target).
  systemd.services.NetworkManager-wait-online.enable = false;

  # Router advertises v6 but egress blackholes (~10s AAAA timeout). RFC 6724
  # defaults with IPv4 moved above global v6; any table replaces glibc's.
  networking.getaddrinfo.precedence = {
    "::1/128" = 50;
    "::ffff:0:0/96" = 45;
    "::/0" = 40;
    "2002::/16" = 30;
    "::/96" = 20;
  };

  time.timeZone = "America/Chicago";

  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint ];
  };

  services.libinput.enable = true;

  # Journals had grown to 3.3G against the ~4G default cap.
  services.journald.extraConfig = "SystemMaxUse=1G";

  # sudo is 4750 root:wheel instead of world-executable; nothing outside wheel
  # has any business invoking it here.
  security.sudo.execWheelOnly = true;

  users.users.rupan = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  programs.nix-agent = {
    enable = true;
    flake = /home/rupan/nixos;
    # Module `--flake <dir>*` glob is too wide (fnmatch `*` matches `/` and `#`).
    privilegedAutomation.enable = false;
  };

  # Passwordless rebuild pinned to this repo's absolute path. sudo does not bind
  # cwd (`.` would run any flake); trailing `*` matches `/` and `#`. Exact
  # literals only; `#` and `:` escaped for the sudoers lexer. Keep in sync with
  # `just switch` / `just dry`. Root ignores user nix.conf.
  security.sudo.extraRules = [
    {
      users = [ "rupan" ];
      commands =
        let
          rebuild = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
          nh = "${pkgs.nh}/bin/nh";
          nixEnv = "${pkgs.nix}/bin/nix-env";
          flakeRefs = [
            "path\\:${config.repoPath}\\#laptop"
            "${config.repoPath}\\#laptop"
            config.repoPath
          ];
          actions = [
            "switch"
            "test"
            "dry-activate"
          ];
        in
        [
          {
            command = "${nh} os switch -R ${config.repoPath} -H laptop -- --max-jobs 2 --cores 8";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${rebuild} switch --rollback";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${nixEnv} ^-p /nix/var/nix/profiles/system --switch-generation [0-9]+$";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/nix/var/nix/profiles/system/bin/switch-to-configuration switch";
            options = [ "NOPASSWD" ];
          }
        ]
        ++ lib.concatMap (
          action:
          map (ref: {
            command = "${rebuild} ${action} --flake ${ref}";
            options = [ "NOPASSWD" ];
          }) flakeRefs
        ) actions;
    }
  ];

  environment.systemPackages = with pkgs; [
    wget
    neovim
    pciutils
    qemu_kvm
    virtiofsd
  ];

  security.pam.services.hyprlock = { };

  programs.gnupg.agent.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
    ];
  };

  services.openssh.enable = false;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [
      53317
      5353
    ];
  };

  # systemd-resolved so GP/netbird can push per-link DNS. Do not set
  # `networking.nameservers` (becomes global DNS= and outranks per-link).
  services.resolved = {
    enable = true;
    settings.Resolve = {
      FallbackDNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      # Unsigned/lying campus and hotel zones.
      DNSSEC = false;
      # avahi owns mDNS; two responders on 5353 conflict.
      MulticastDNS = false;
    };
  };
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.wifi.scanRandMacAddress = false;
  networking.networkmanager.wifi.macAddress = "preserve";
  networking.wireless.iwd.enable = false;

  auto-update.enable = true;
  focusMode.enable = true;

  programs.nh = {
    enable = true;
    flake = config.repoPath;
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep-since 7d --keep 3 --no-gcroots";
    };
  };

  nix.optimise.automatic = true;

  # Homelab Attic cache. Disabled while the homelab is offline.
  # nix.settings.extra-substituters = [ "http://10.0.20.190:8080/homelab" ];
  # nix.settings.extra-trusted-substituters = [ "http://10.0.20.190:8080/homelab" ];
  # nix.settings.extra-trusted-public-keys = [
  #   "homelab:s17u8G3szjlQ6UmMAPsszVS/J1jaw6gDwSDM9+/QeNQ="
  # ];
  # direnv has no stdin to answer the interactive y/N prompt, so it hangs.
  nix.settings.accept-flake-config = true;

  system.stateVersion = "25.11"; # DO NOT EDIT
}
