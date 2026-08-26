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
    ps.evdev # for xhisper-wait-mod-release helper
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
    # Drop Pop!_OS LD_LIBRARY_PATH; EXIT trap dismisses the listening popup.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'export LD_LIBRARY_PATH=/usr/local/lib/ollama/cuda_v12/lib:$LD_LIBRARY_PATH' \
        "$(cat ${./exit-trap.nixos})"

    # `python3 xhisper_transcribe` is cwd-relative (no PATH lookup). Use the shebang.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'python3 "$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null' \
        '"$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null'

    substituteInPlace xhisper.sh \
      --replace-fail \
        'local cmd_args="--model $model_name --device $model_device"' \
        'local cmd_args=(--model "$model_name" --device "$model_device")' \
      --replace-fail \
        'cmd_args="$cmd_args --language $model_language"' \
        'cmd_args+=(--language "$model_language")' \
      --replace-fail \
        'cmd_args="$cmd_args --prompt \"$transcription_prompt\""' \
        'cmd_args+=(--prompt "$transcription_prompt")' \
      --replace-fail \
        '"$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null' \
        '"$TRANSCRIPT_SCRIPT" "$recording" "''${cmd_args[@]}" 2>> "$LOGFILE"'

    # paste() types via uinput while Super is often still held (Mod+Z bind),
    # so wait for KEY_*META release before synthetic keystrokes.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'paste() {' \
        'paste() { xhisper-wait-mod-release 2>/dev/null || sleep 0.3 ;'

    # Kill/respawn the popup to change XHISPER_POPUP_TEXT (read at launch).
    substituteInPlace xhisper.sh \
      --replace-fail \
        'paste "(recording...)"' \
        'paste "(recording...)" ; kill $(cat /tmp/xhisper-popup.pid 2>/dev/null) 2>/dev/null ; XHISPER_POPUP_TEXT="🎤 Listening…" qs -p "$HOME/.config/quickshell-xhisper-popup" >/dev/null 2>&1 & echo $! > /tmp/xhisper-popup.pid'

    # Extra Mod+Z during Whisper used to start a new recording and clobber the wav.
    substituteInPlace xhisper.sh \
      --replace-fail \
        "$(cat ${./finish-recording.orig})" \
        "$(cat ${./finish-recording.nixos})"
  '';

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    install -Dm644 default_xhisperrc $out/share/xhisper/default_xhisperrc

    # Local HF cache, CUDA→CPU fallback — so Mod+Z cannot hang on a Hub download.
    install -Dm755 ${./xhisper_transcribe.py} $out/bin/xhisper_transcribe
    substituteInPlace $out/bin/xhisper_transcribe \
      --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3'

    cat > $out/bin/xhisper-amplitude-monitor <<PYEOF
    #!${python}/bin/python3
    import math, os, struct, sys, time

    WAV = "/tmp/xhisper.wav"
    CHUNK_BYTES = 1600  # 50 ms at 16 kHz mono s16le
    HEADER = 44

    sys.stdout.write("0.000\n")
    sys.stdout.flush()
    for _ in range(200):
        if os.path.exists(WAV) and os.path.getsize(WAV) > HEADER:
            break
        time.sleep(0.05)

    while True:
        try:
            sz = os.path.getsize(WAV)
            if sz > HEADER:
                with open(WAV, "rb") as f:
                    f.seek(max(HEADER, sz - CHUNK_BYTES))
                    data = f.read(CHUNK_BYTES)
                n = len(data) // 2
                if n > 0:
                    ints = struct.unpack(f"<{n}h", data)
                    rms = math.sqrt(sum(s * s for s in ints) / n) / 32768.0
                    # Fan/hum noise floor, then sqrt-compress remaining RMS.
                    NOISE_FLOOR = 0.010
                    GAIN = 10.0
                    above = max(0.0, rms - NOISE_FLOOR)
                    level = max(0.0, min(1.0, math.sqrt(above * GAIN)))
                    sys.stdout.write(f"{level:.3f}\n")
                    sys.stdout.flush()
        except (FileNotFoundError, OSError):
            sys.stdout.write("0.000\n")
            sys.stdout.flush()
        time.sleep(0.05)
    PYEOF
    chmod +x $out/bin/xhisper-amplitude-monitor

    cat > $out/bin/xhisper-wait-mod-release <<PYEOF
    #!${python}/bin/python3
    import select, sys, time, evdev
    from evdev import ecodes

    TIMEOUT = 10.0
    META_KEYS = (ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA)

    devs = []
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
            caps = d.capabilities()
            keys = caps.get(ecodes.EV_KEY, [])
            if any(k in keys for k in META_KEYS):
                devs.append(d)
        except (PermissionError, OSError):
            continue

    def any_meta_held():
        for d in devs:
            try:
                ks = d.active_keys()
                if any(k in ks for k in META_KEYS):
                    return True
            except OSError:
                continue
        return False

    if not any_meta_held():
        sys.exit(0)

    fd_map = {d.fd: d for d in devs}
    deadline = time.time() + TIMEOUT
    while time.time() < deadline:
        r, _, _ = select.select(fd_map.keys(), [], [], deadline - time.time())
        for fd in r:
            try:
                for ev in fd_map[fd].read():
                    if (
                        ev.type == ecodes.EV_KEY
                        and ev.code in META_KEYS
                        and ev.value == 0
                    ):
                        if not any_meta_held():
                            sys.exit(0)
            except (BlockingIOError, OSError):
                continue
    sys.exit(0)
    PYEOF
    chmod +x $out/bin/xhisper-wait-mod-release

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
