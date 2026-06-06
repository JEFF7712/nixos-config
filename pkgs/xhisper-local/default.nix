{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  python3Packages,
  pipewire,
  ffmpeg,
  wl-clipboard,
  bc,
  coreutils,
  gnused,
  gnugrep,
  gawk,
  procps,
  bash,
  ollama ? null,
}:

let
  python = python3Packages.python.withPackages (ps: [
    ps.faster-whisper
  ]);

  runtimePath = lib.makeBinPath (
    [
      pipewire
      ffmpeg
      wl-clipboard
      bc
      coreutils
      gnused
      gnugrep
      gawk
      procps
      bash
    ]
    ++ lib.optional (ollama != null) ollama
  );
in
stdenv.mkDerivation {
  pname = "xhisper-local";
  version = "0-unstable-2026-06-06";

  src = fetchFromGitHub {
    owner = "wpbryant";
    repo = "xhisper-local";
    rev = "9a53cbad3adfdf55a2bf44d469a8e3475c3bdeb6";
    hash = "sha256-keYX3+kKaKHyaNMzuXRKuSlayE66m85sSoAm/SmQmTk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # Drop the upstream Pop!_OS-specific LD_LIBRARY_PATH hack — we provide
    # CUDA libs via nix-ld / the cuda-wrapped python if/when the user opts in.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'export LD_LIBRARY_PATH=/usr/local/lib/ollama/cuda_v12/lib:$LD_LIBRARY_PATH' \
        '# LD_LIBRARY_PATH override removed for NixOS'

    # Point the Python entrypoint at our wrapped interpreter (faster-whisper available).
    substituteInPlace xhisper_transcribe.py \
      --replace-fail \
        '#!/usr/bin/env python3' \
        '#!${python}/bin/python3'
  '';

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    install -Dm644 default_xhisperrc $out/share/xhisper/default_xhisperrc

    wrapProgram $out/bin/xhisper \
      --prefix PATH : "$out/bin:${runtimePath}"
  '';

  meta = {
    description = "Dictate anywhere in Linux with local Whisper + optional Ollama AI formatting";
    homepage = "https://github.com/wpbryant/xhisper-local";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "xhisper";
  };
}
