{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.xhisperLocal;
  xhisperPkg = pkgs.xhisper-local.override {
    ollama = if cfg.ollama.enable then cfg.ollama.package else null;
  };
  streamdPkg = pkgs.callPackage ../../pkgs/xhisper-streamd { };
in
{
  options.xhisperLocal = {
    enable = lib.mkEnableOption "xhisper-local dictation";

    user = lib.mkOption {
      type = lib.types.str;
      default = "rupan";
      description = "User added to the input group for /dev/uinput access.";
    };

    ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run a local Ollama service for AI post-processing.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ollama;
        defaultText = lib.literalExpression "pkgs.ollama";
        description = ''
          Ollama package. Defaults to CPU-only; swap to pkgs.ollama-cuda or
          pkgs.ollama-vulkan once your binary cache covers it.
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "gemma3:4b";
        description = "Ollama model to auto-pull for post-processing.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      xhisperPkg
      streamdPkg
      pkgs.socat
      pkgs.jq
    ];

    users.users.${cfg.user}.extraGroups = [ "input" ];

    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    services.ollama = lib.mkIf cfg.ollama.enable {
      enable = true;
      package = cfg.ollama.package;
      loadModels = [ cfg.ollama.model ];
    };
  };
}
