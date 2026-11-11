{
  nix-vscode-extensions,
}:

[
  (import ./local-packages.nix)
  (import ./orca-slicer.nix)
  (import ./streamcontroller.nix)
  nix-vscode-extensions.overlays.default
]
