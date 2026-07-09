{
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  coreutils,
  stdenv,
  zlib,
}:

stdenvNoCC.mkDerivation {
  pname = "cursor-agent";
  version = "2026.07.08-0c04a8a";

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/2026.07.08-0c04a8a/linux/x64/agent-cli-package.tar.gz";
    hash = "sha256-qVzpU8+ynYdgC3Fg/fe7vwkIlfON74FVIPMsSojxtZU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/cursor-agent $out/bin
    cp -R . $out/libexec/cursor-agent/

    patchShebangs $out/libexec/cursor-agent/cursor-agent $out/libexec/cursor-agent/cursor-agent-svc

    wrapProgram $out/libexec/cursor-agent/cursor-agent \
      --prefix PATH : ${coreutils}/bin

    ln -s $out/libexec/cursor-agent/cursor-agent $out/bin/cursor-agent
    ln -s $out/libexec/cursor-agent/cursor-agent $out/bin/agent

    runHook postInstall
  '';
}
