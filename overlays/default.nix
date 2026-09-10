{
  nix-vscode-extensions,
}:

[
  (import ./local-packages.nix)
  (import ./orca-slicer.nix)
  (import ./ctranslate2-cuda.nix)
  nix-vscode-extensions.overlays.default
]
