{ pkgs, lib, config, ... }:

{
  options.airplay.enable = lib.mkEnableOption "airplay";

  config = lib.mkIf config.airplay.enable {
    environment.systemPackages = with pkgs; [ 
      uxplay 
      gst_all_1.gst-vaapi 
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
    ];

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
