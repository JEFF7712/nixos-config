{
  lib,
  stdenv,
  python3Packages,
  makeWrapper,
}:

let
  python = python3Packages.python.withPackages (ps: [
    ps.faster-whisper
    ps.numpy
  ]);
in
stdenv.mkDerivation {
  pname = "xhisper-streamd";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/lib/xhisper-streamd $out/bin
    cp xhisper_streamd.py __main__.py $out/lib/xhisper-streamd/

    makeWrapper ${python}/bin/python3 $out/bin/xhisper-streamd \
      --add-flags "$out/lib/xhisper-streamd" \
      --set PYTHONUNBUFFERED 1
  '';

  meta = {
    description = "Streaming Whisper daemon for xhisper-stream overlay dictation";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "xhisper-streamd";
  };
}
