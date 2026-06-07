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
    # bindings on Mod+O, Mod+E, Mod+D.
    # We install a small evdev-polling helper (xhisper-wait-mod-release, see
    # postInstall) that blocks until KEY_LEFTMETA/RIGHTMETA actually clear or
    # 2 s elapses, then paste() invokes it before any synthetic keystrokes.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'paste() {' \
        'paste() { xhisper-wait-mod-release 2>/dev/null || sleep 0.3 ;'
  '';

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    install -Dm644 default_xhisperrc $out/share/xhisper/default_xhisperrc

    # Polls evdev until Super (LEFTMETA / RIGHTMETA) is released on every
    # keyboard, or 2 s elapses. Called by paste() to keep synthesized
    # keystrokes from colliding with niri's Mod+letter app launchers.
    cat > $out/bin/xhisper-wait-mod-release <<PYEOF
    #!${python}/bin/python3
    import sys, time, evdev

    LOG = open("/tmp/xhisper-wait.log", "a")
    def log(msg):
        LOG.write(f"{time.time():.3f} {msg}\n")
        LOG.flush()

    log("--- helper start")
    devs = []
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
            caps = d.capabilities()
            keys = caps.get(evdev.ecodes.EV_KEY, [])
            if evdev.ecodes.KEY_LEFTMETA in keys or evdev.ecodes.KEY_RIGHTMETA in keys:
                devs.append(d)
                log(f"watching {path} {d.name}")
        except (PermissionError, OSError) as e:
            log(f"skip {path}: {e}")
            continue

    log(f"initial active_keys snapshot:")
    for d in devs:
        try:
            log(f"  {d.path} {d.name}: {d.active_keys()}")
        except OSError as e:
            log(f"  {d.path}: {e}")

    deadline = time.time() + 2.0
    polls = 0
    while time.time() < deadline:
        held = False
        for d in devs:
            try:
                ks = d.active_keys()
                if evdev.ecodes.KEY_LEFTMETA in ks or evdev.ecodes.KEY_RIGHTMETA in ks:
                    held = True
                    if polls == 0:
                        log(f"  HELD on {d.path}: {ks}")
                    break
            except OSError:
                continue
        polls += 1
        if not held:
            break
        time.sleep(0.02)
    log(f"--- helper exit after {polls} polls, {time.time() - (deadline - 2.0):.3f}s")
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
