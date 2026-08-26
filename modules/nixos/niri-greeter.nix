{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.niri-greeter.enable = lib.mkEnableOption "greetd with tuigreet as the niri login greeter";

  config = lib.mkIf config.niri-greeter.enable {
    assertions = [
      {
        assertion = config.niri.enable;
        message = "niri-greeter.enable requires niri.enable";
      }
    ];

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --remember-session --asterisks --cmd ${lib.getExe' config.programs.niri.package "niri-session"}";
    };
  };
}
