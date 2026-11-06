{
  lib,
  config,
  ...
}:

{
  options.howdy.enable = lib.mkEnableOption "Howdy facial authentication";

  config = lib.mkIf config.howdy.enable {
    services.howdy = {
      enable = true;
      control = "sufficient";
      settings = {
        core = {
          detection_notice = false;
          timeout_notice = true;
          no_confirmation = true;
          suppress_unknown = false;
          abort_if_ssh = true;
          abort_if_lid_closed = true;
          disabled = false;
          use_cnn = false;
        };

        video = {
          certainty = 4.2;
          timeout = 4;
          device_path = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:8:1.2-video-index0";
          warn_no_device = true;
          max_height = 360;
          dark_threshold = 60;
          recording_plugin = "opencv";
          device_format = "v4l2";
        };
      };
    };
  };
}
