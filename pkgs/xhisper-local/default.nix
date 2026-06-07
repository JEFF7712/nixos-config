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
    # Also install an EXIT trap that dismisses the listening notification so
    # it doesn't linger if the script crashes mid-record.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'export LD_LIBRARY_PATH=/usr/local/lib/ollama/cuda_v12/lib:$LD_LIBRARY_PATH' \
        'trap "notify-send -a xhisper -h string:synchronous:xhisper -t 1 \" \" 2>/dev/null || true" EXIT  # LD_LIBRARY_PATH hack stripped; install notif-dismiss trap'

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

    # Fire notifications on record-start and transcribe-start so there's a
    # visible "what is xhisper doing" indicator in addition to the inline text.
    # The 'synchronous:xhisper' hint makes mako/dunst replace previous
    # notifications with the same group, so the popup updates in place.
    substituteInPlace xhisper.sh \
      --replace-fail \
        'paste "(recording...)"' \
        'paste "(recording...)" ; notify-send -a xhisper -h string:synchronous:xhisper -t 0 "🎤 xhisper" "Listening…" 2>/dev/null || true'

    substituteInPlace xhisper.sh \
      --replace-fail \
        'paste "(transcribing...)"' \
        'notify-send -a xhisper -h string:synchronous:xhisper -t 0 "💭 xhisper" "Transcribing…" 2>/dev/null || true ; paste "(transcribing...)"'
  '';

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    install -Dm644 default_xhisperrc $out/share/xhisper/default_xhisperrc

    # Blocks until Super (LEFTMETA / RIGHTMETA) is released on every keyboard
    # device, or a generous timeout elapses. Called by paste() to keep
    # synthesized keystrokes from colliding with niri's Mod+letter app launchers.
    # Uses select() on evdev fds so it returns the instant the release event
    # arrives instead of burning CPU polling.
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
