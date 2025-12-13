{ pkgs, lib, config, inputs, ... }: 
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];
  options.desktop-apps.enable = lib.mkEnableOption "desktop-apps";
  config = lib.mkIf config.desktop-apps.enable {
 
    home.packages = with pkgs; [
      davinci-resolve
      bitwarden-desktop
      libreoffice-qt-fresh  
      netflix
      chromium
      obs-studio
      qbittorrent
      localsend
    ];
    
    programs.firefox.enable = true;

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
      mutableExtensionsDir = false; 
      
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix       
          ms-python.python   
          github.copilot     
          eamodio.gitlens    
          hashicorp.terraform
          hashicorp.hcl
          redhat.vscode-yaml
          esbenp.prettier-vscode
	  ms-azuretools.vscode-docker
        ];
        
        userSettings = {
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
          "editor.fontSize" = 14;
          "editor.defaultFormatter" = "prettier.prettier-vscode";
          "window.titleBarStyle" = "custom";
          "git.enableSmartCommit" = true;
          "git.confirmSync" = false;
        };
      };
    };


  };
}
