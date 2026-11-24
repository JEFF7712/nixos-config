{
  buildGoModule,
  fetchFromGitHub,
}:

# `ws` from seg6/dotfiles: a tmux session picker over a projects root. The
# folio launcher lists its recent projects and opens them with `ws open`.
buildGoModule {
  pname = "seg6-ws";
  version = "0-unstable-2026-11-19";

  src = fetchFromGitHub {
    owner = "seg6";
    repo = "dotfiles";
    rev = "32b7e78956a5e023c5a92a507a03389507d41054";
    hash = "sha256-/ADf5nF2e/WjDcz99/fertyqRvMOhRDBM9G7CpHU/Q8=";
  };

  modRoot = "tools/cli";
  subPackages = [ "cmd/ws" ];
  vendorHash = "sha256-wk4yUELHauVGm0Dx4W3EZr8dkiStWV3uCyIlPNEtGRo=";

  meta = {
    description = "tmux workspace picker from seg6/dotfiles";
    homepage = "https://github.com/seg6/dotfiles";
    mainProgram = "ws";
  };
}
