{
  nix-vscode-extensions,
}:

[
  (import ./local-packages.nix)
  (import ./orca-slicer.nix)
  nix-vscode-extensions.overlays.default
]
