{ pkgs, lib, config, inputs, ... }: 
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];
  options.common-apps.enable = lib.mkEnableOption "common-apps";
  config = lib.mkIf config.common-apps.enable {

    home.packages = with pkgs; [
      networkmanagerapplet
      vesktop
      pywalfox-native
    ];

    programs.firefox = {
      enable = true;
      profiles."09longn9.default-release" = {
        extraConfig = ''
          (function() {
            try {
              window.addEventListener("keydown", function(e) {
                // Hotkey: Ctrl + Alt + Z
                if (e.ctrlKey && e.altKey && e.code === "KeyZ") {
                  let pref = "layout.css.devPixelsPerPx";
                  let current = Services.prefs.getCharPref(pref);
                  let newValue = (current === "1.0" || current === "1") ? "2.0" : "1.0";
                  Services.prefs.setCharPref(pref, newValue);
                }
              }, false);
            } catch (e) {}
          })();
        '';
      };
    };

    home.file.".mozilla/firefox/09longn9.default-release/chrome" = {
      source = ./configs/firefox/chrome;
      recursive = true;
    };

    home.file.".mozilla/firefox/09longn9.default-release/user.js".text = ''
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    '';

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

    programs.vscode = {
      enable = true;
      mutableExtensionsDir = true; 
      
      profiles.default = {
        extensions = with pkgs.vscode-marketplace; [
          jnoortheen.nix-ide       
          ms-python.python   
          github.copilot     
          hashicorp.terraform
          pjmiravalle.terraform-advanced-syntax-highlighting
          redhat.vscode-yaml
          esbenp.prettier-vscode
          kdl-org.kdl
          ms-azuretools.vscode-docker
        ];        
      };
    };

    xdg.configFile."Code/User/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/vscode/settings.json";

  };
}
