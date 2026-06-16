{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "maple-mono-nf";
  version = "7.9";

  src = fetchzip {
    url = "https://github.com/subframe7536/maple-font/releases/download/v${finalAttrs.version}/MapleMono-NF.zip";
    hash = "sha256-N7wQ/dCtdwha/VjM7/y7Fid3371t2S7oUE5vEtBeo0g=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 *.ttf -t "$out/share/fonts/truetype"
    runHook postInstall
  '';

  meta = {
    description = "Maple Mono: rounded monospace font with Nerd Font glyphs and ligatures";
    homepage = "https://github.com/subframe7536/maple-font";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
