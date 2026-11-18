{
  nix-vscode-extensions,
  vicinae,
}:

[
  (import ./local-packages.nix { inherit vicinae; })
  (import ./orca-slicer.nix)
  (import ./streamcontroller.nix)
  nix-vscode-extensions.overlays.default
]
