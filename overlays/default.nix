{
  inputs,
  nix-vscode-extensions,
}:

[
  (import ./local-packages.nix)
  (import ./ctranslate2-cuda.nix)
  (import ./python-fixes.nix)
  nix-vscode-extensions.overlays.default
  inputs.niri-blur.overlays.default
]
