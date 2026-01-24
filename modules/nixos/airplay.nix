{ pkgs, lib, config, ... }:

{
  options.airplay.enable = lib.mkEnableOption "airplay";

  config = lib.mkIf config.airplay.enable {
    environment.systemPackages = [ pkgs.uxplay ];

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 7000 7001 7100 ];
      allowedUDPPorts = [ 5353 6000 6001 6002 6003 7011 ];
    };
  };
}
