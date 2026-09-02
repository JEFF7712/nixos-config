{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "1.0.2-R2040.1";

  sources = {
    "x86_64-linux" = {
      file = "muse-x86-linux";
      hash = "sha256-byRiPW0aGTqKuNYQw98Rw4zIu1SqObZTL7Knop2F0ns=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "muse-code: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "muse-code";
  inherit version;

  src = fetchurl {
    url = "https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version=${version}&file=${source.file}";
    inherit (source) hash;
    name = "muse-${version}-${source.file}";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/muse

    runHook postInstall
  '';

  meta = {
    description = "Muse Code CLI, terminal coding agent powered by Muse Spark";
    homepage = "https://dev.meta.ai";
    license = lib.licenses.unfree;
    mainProgram = "muse";
    platforms = builtins.attrNames sources;
  };
}
