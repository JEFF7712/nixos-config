{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.1.21";

  sources = {
    "x86_64-linux" = {
      name = "linux-amd64";
      hash = "sha256-8n8BruxnPzOh+GkBN+T3NtluZvI/dXj3eAg1hb9Ib+E=";
    };
    "aarch64-linux" = {
      name = "linux-arm64";
      hash = "sha256-M1kxPLTDzo2ical/cLn7brLfJkyCGA79iA9WGwcIjCE=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "claude-code-proxy: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "claude-code-proxy";
  inherit version;

  src = fetchurl {
    url = "https://github.com/raine/claude-code-proxy/releases/download/v${version}/claude-code-proxy-${source.name}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 claude-code-proxy $out/bin/claude-code-proxy

    runHook postInstall
  '';

  meta = {
    description = "Anthropic-compatible proxy for subscription-backed coding models";
    homepage = "https://github.com/raine/claude-code-proxy";
    license = lib.licenses.mit;
    mainProgram = "claude-code-proxy";
    platforms = builtins.attrNames sources;
  };
}
