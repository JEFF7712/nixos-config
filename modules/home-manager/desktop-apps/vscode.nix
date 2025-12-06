{ pkgs, lib, config, ... }: {
  options.vscode.enable = lib.mkEnableOption "vscode editor";

  config = lib.mkIf config.vscode.enable {
    programs.vscode = {
      enable = true;
      mutableExtensionsDir = false; 
      
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix       
          ms-python.python   
          github.copilot     
          eamodio.gitlens    
        ];
        
        userSettings = {
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
          "editor.fontSize" = 14;
          "window.titleBarStyle" = "custom";
        };
      };
    };
  };
}
