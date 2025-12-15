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
      networkmanagerapplet
      (writeShellScriptBin "firefox" ''
        exec ${pkgs.firefox}/bin/firefox --marionette --remote-allow-system-access "$@"
      '')
    ];

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
        extensions = with pkgs.vscode-marketplace; [
          bbenoist.nix       
          ms-python.python   
          github.copilot     
          eamodio.gitlens    
          hashicorp.terraform
          pjmiravalle.terraform-advanced-syntax-highlighting
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
