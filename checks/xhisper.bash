#!/usr/bin/env bash
# Guards the Mod+Z dictation path: transcribe must not hang on Hugging Face,
# must not swallow errors, and must not paste nothing after an empty result.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_ROOT/pkgs/xhisper-local"
PKG="$PKG_DIR/default.nix"
TRANSCRIBE="$PKG_DIR/xhisper_transcribe.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$PKG" ] || fail "missing $PKG"

# Transcription stderr used to be discarded (2>/dev/null), so Hugging Face
# downloads and CUDA failures looked like a stuck "(transcribing...)" with
# no paste. The final cmd_args invocation must append stderr to the logfile.
if grep -E 'cmd_args\[@\]' "$PKG" | grep -q '2>/dev/null'; then
  fail "xhisper transcribe still discards stderr (2>/dev/null)"
fi
if ! grep -E 'cmd_args\[@\]' "$PKG" | grep -q '2>>'; then
  fail "xhisper transcribe stderr is not redirected to the logfile"
fi

# Extra Mod+Z during transcribe used to start a new recording and clobber the wav.
rg -q 'xhisper-transcribing' "$PKG_DIR" ||
  fail "xhisper has no in-flight transcription lock"

# Whisper returning "" used to delete "(transcribing...)" and paste nothing.
rg -q 'no speech detected' "$PKG_DIR" ||
  fail "empty transcription is not surfaced to the user"

# The listening popup was killed at transcribe-start, leaving only inline text.
rg -q 'Transcribing' "$PKG_DIR" ||
  fail "transcribing popup is not shown"

[ -f "$TRANSCRIBE" ] || fail "missing $TRANSCRIBE (local-first Whisper loader)"

grep -q 'local_files_only' "$TRANSCRIBE" ||
  fail "xhisper_transcribe.py does not prefer a local Hugging Face cache"

python3 - "$TRANSCRIBE" <<'PY'
import importlib.util
import io
import sys
import types
from pathlib import Path

transcribe_path = Path(sys.argv[1])

calls = []
behavior = {"raise": None}


class FakeSegment:
    def __init__(self, text):
        self.text = text


class WhisperModel:
    def __init__(self, model_size, device="auto", compute_type="default", local_files_only=False, **kwargs):
        calls.append(
            {
                "model_size": model_size,
                "device": device,
                "compute_type": compute_type,
                "local_files_only": local_files_only,
            }
        )
        if behavior["raise"] is not None:
            err = behavior["raise"]
            behavior["raise"] = None
            raise err
        self.device = device

    def transcribe(self, audio_path, **kwargs):
        return [FakeSegment("hello world")], None


fw = types.ModuleType("faster_whisper")
fw.WhisperModel = WhisperModel
sys.modules["faster_whisper"] = fw

spec = importlib.util.spec_from_file_location("xhisper_transcribe", transcribe_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

calls.clear()
model = mod.load_model("small.en", "cuda")
if calls[0]["local_files_only"] is not True:
    raise SystemExit(f"first load should be local_files_only=True, got {calls[0]}")
if calls[0]["device"] != "cuda":
    raise SystemExit(f"first load should use cuda, got {calls[0]}")
if model.device != "cuda":
    raise SystemExit("cached CUDA load should succeed")

calls.clear()
behavior["raise"] = RuntimeError("cuDNN not found")
stderr = io.StringIO()
old_err = sys.stderr
sys.stderr = stderr
model = mod.load_model("small.en", "cuda")
sys.stderr = old_err
if len(calls) < 2:
    raise SystemExit(f"CUDA failure should fall back, calls={calls}")
if calls[-1]["device"] != "cpu":
    raise SystemExit(f"CUDA failure should fall back to cpu, got {calls}")
if "CUDA" not in stderr.getvalue() and "cpu" not in stderr.getvalue().lower():
    raise SystemExit(f"CUDA fallback should be logged, stderr={stderr.getvalue()!r}")
if model.device != "cpu":
    raise SystemExit("fallback model should be on cpu")

calls.clear()
behavior["raise"] = FileNotFoundError("local cache miss")
stderr = io.StringIO()
sys.stderr = stderr
model = mod.load_model("small.en", "cpu")
sys.stderr = old_err
if not any(c["local_files_only"] is False for c in calls):
    raise SystemExit(f"cache miss should download, calls={calls}")
if "download" not in stderr.getvalue().lower() and "cache" not in stderr.getvalue().lower():
    raise SystemExit(f"cache miss should be logged, stderr={stderr.getvalue()!r}")

text = mod.transcribe_file("/tmp/fake.wav", model_size="small.en", device="cpu")
if text != "hello world":
    raise SystemExit(f"expected transcribed text, got {text!r}")
PY
