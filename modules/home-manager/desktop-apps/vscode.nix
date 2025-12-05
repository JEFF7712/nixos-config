{ pkgs, lib, config, ... }: {
  options.vscode.enable = lib.mkEnableOption "vscode editor";

  config = lib.mkIf config.vscode.enable {
    programs.vscode = {
      enable = true;
      # Prevent the "Mutable" warning by allowing extensions to be managed by Nix
      mutableExtensionsDir = false; 
      
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix         # Nix syntax highlighting
        ms-python.python     # Python support
        # github.copilot     # AI
        # eamodio.gitlens    # Git supercharger
      ];
      
      userSettings = {
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
        "editor.fontSize" = 14;
        "window.titleBarStyle" = "custom";
      };
    };
  };
}
