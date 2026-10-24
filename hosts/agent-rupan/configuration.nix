{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  networking = {
    hostName = "agent-rupan";
    useDHCP = false;
    useNetworkd = true;
    enableIPv6 = false;
    nameservers = [ "1.1.1.1" ];
    firewall.allowedTCPPorts = [ 22 ];
  };
  systemd.network.networks."10-workspace" = {
    matchConfig.MACAddress = "02:00:00:10:00:02";
    address = [ "172.31.10.2/30" ];
    routes = [ { Gateway = "172.31.10.1"; } ];
    networkConfig.IPv6AcceptRA = false;
    linkConfig.RequiredForOnline = "routable";
  };

  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/vda";
    };
    kernelParams = [ "console=ttyS0,115200" ];
    growPartition = true;
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  users.users.developer = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILW7MVmIGzW4Eq1NJm4+gsGwQ+iL44bIfyAa/wdQ1srQ rupanpandyan@gmail.com"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "developer" ];
    };
  };
  services.qemuGuest.enable = true;
  services.logind.settings.Login.KillUserProcesses = false;
  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = 1;
    cores = 2;
  };
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 3";
    };
  };
  time.timeZone = "America/Chicago";
  system.stateVersion = "26.05";

  system.build.qcow2 = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit lib pkgs config;
    format = "qcow2";
    partitionTableType = "legacy";
    diskSize = 8192;
    memSize = 2048;
  };
}
