{  pkgs, lib, config, inputs, ... }:
let
  comfyTheme = pkgs.fetchFromGitHub {
    owner = "Comfy-Themes";
    repo = "Spicetify";
    rev = "2c22f3649a82e599be0e7eb506a0f83459caf9e8"; 
    hash = "sha256-R195U83vN1Xq89490e5H28z4G86G292vL1vJ83X0N7Y="; 
  };
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  options.vscode.enable = lib.mkEnableOption "Spicetify";

  config = lib.mkIf config.spicetify.enable {
    programs.spicetify = {
      enable = true;
      package = pkgs.spotify;

      theme = {
        name = "Comfy";
        src = comfyTheme;
        injectCss = true;
        injectThemeJs = true;
        replaceColors = true;
        overwriteAssets = true;
      };
    
      colorScheme = "spotify";
      enabledExtensions = [ "theme.js" ];
    };
  };
}
