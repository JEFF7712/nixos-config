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

    # Upstream's argparse rejects English-only model variants like small.en.
    # Drop the explicit choices list so faster-whisper validates instead.
    substituteInPlace xhisper_transcribe.py \
      --replace-fail \
        'choices=["tiny", "base", "small", "medium", "large-v1", "large-v2", "large-v3"],' \
        ""

    # Upstream calls `python3 "$TRANSCRIPT_SCRIPT"` where TRANSCRIPT_SCRIPT is the
    # bare name "xhisper_transcribe". python3 treats that as a cwd-relative path
    # (no PATH lookup), so it silently fails. Drop the python3 prefix and rely on
    # xhisper_transcribe's shebang, which points at our wrapped interpreter.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'python3 "$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null' \
        '"$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null'

    # The user binds xhisper to Mod+Z (Super+Z). After the keypress fires the
    # script, paste() starts typing the status / transcript via uinput while
    # the physical Super key is often still held — so each character lands as
    # Mod+<char>, opening Obsidian / Thunar / Vesktop / etc. via the niri
    # bindings on Mod+O, Mod+E, Mod+D. Sleep at paste() entry gives the user
    # time to release the modifier before any synthetic keystrokes go out.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'paste() {' \
        'paste() { sleep 0.3 ;  # wait for Mod release — see xhisper-local default.nix'
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
