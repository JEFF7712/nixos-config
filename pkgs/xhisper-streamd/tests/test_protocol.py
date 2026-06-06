import io
import json

from xhisper_streamd import run_stream_loop


class FakeTranscriber:
    def __init__(self) -> None:
        self.steps = [
            {"confirmed": "", "tentative": "hello"},
            {"confirmed": "hello", "tentative": "world"},
            {"confirmed": "hello world", "tentative": ""},
        ]
        self._i = 0
        self.appended_chunks: list[bytes] = []
        self.finalized = False

    def add_audio(self, b: bytes) -> None:
        self.appended_chunks.append(b)

    def step(self):
        if self._i >= len(self.steps):
            return None
        out = self.steps[self._i]
        self._i += 1
        return out

    def finalize(self) -> str:
        self.finalized = True
        return "hello world"


def test_emits_partial_then_final_on_eof():
    pcm = b"\x00\x00" * 16000 * 2  # 2 seconds of silence
    stdin = io.BytesIO(pcm)
    stdout = io.StringIO()
    t = FakeTranscriber()

    run_stream_loop(stdin, stdout, t, chunk_bytes=16000 * 2 // 2)  # 0.5 s chunks (s16le)

    lines = [ln for ln in stdout.getvalue().splitlines() if ln.strip()]
    parsed = [json.loads(ln) for ln in lines]

    partials = [m for m in parsed if m["type"] == "partial"]
    finals = [m for m in parsed if m["type"] == "final"]

    assert len(partials) == 3
    assert partials[0] == {"type": "partial", "confirmed": "", "tentative": "hello"}
    assert partials[-1] == {"type": "partial", "confirmed": "hello world", "tentative": ""}
    assert finals == [{"type": "final", "text": "hello world"}]
    assert t.finalized
