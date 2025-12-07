{  pkgs, lib, config, inputs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  options.spicetify.enable = lib.mkEnableOption "Spicetify";

  config = lib.mkIf config.spicetify.enable {
    programs.spicetify = {
      enable = true;
    
      theme = spicePkgs.themes.comfy;
      colorScheme = "Spotify"; 

      enabledExtensions = with spicePkgs.extensions; [
        fullAppDisplay
        shuffle
        hidePodcasts
        adblock
	beautiful-lyrics
	CoverAmbience
      ];
    };
  };
}
