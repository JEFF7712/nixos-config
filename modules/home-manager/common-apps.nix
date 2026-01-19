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
#      vesktop
      pywalfox-native
    ];

    programs.firefox = {
      enable = true;
      profiles."09longn9.default-release" = {};
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
          rust-lang.rust-analyzer
	        tauri-apps.tauri-vscode
          llvm-vs-code-extensions.vscode-clangd
          ms-vscode.cmake-tools
        ];        
      };
    };

    xdg.configFile."Code/User/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/vscode/settings.json";
      force = true;
    };
  };
}
