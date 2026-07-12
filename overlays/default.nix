{
  nix-vscode-extensions,
}:

[
  (import ./local-packages.nix)
  (import ./ctranslate2-cuda.nix)
  nix-vscode-extensions.overlays.default
]
