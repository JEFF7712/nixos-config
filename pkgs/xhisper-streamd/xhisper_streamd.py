#!/usr/bin/env python3
"""xhisper-streamd: streaming Whisper daemon with LocalAgreement-2."""
import argparse
import json
import sys
from dataclasses import dataclass

import numpy as np

__version__ = "0.1.0"


class RingBuffer:
    """Mono float32 audio ring buffer for streaming PCM s16le input."""

    def __init__(self, max_samples: int) -> None:
        self._max = max_samples
        self._buf = np.zeros(0, dtype=np.float32)

    def append(self, pcm_bytes: bytes) -> None:
        ints = np.frombuffer(pcm_bytes, dtype=np.int16)
        floats = ints.astype(np.float32) / 32768.0
        self._buf = np.concatenate([self._buf, floats])
        if len(self._buf) > self._max:
            self._buf = self._buf[-self._max:]

    def drop_front(self, n_samples: int) -> None:
        if n_samples <= 0:
            return
        self._buf = self._buf[n_samples:]

    def audio(self) -> np.ndarray:
        return self._buf

    def __len__(self) -> int:
        return len(self._buf)


def longest_agreed_prefix(history: list[list[str]], n: int) -> list[str]:
    """Longest token prefix identical across the last `n` decodes in history.

    Returns empty list if history has fewer than `n` entries.
    """
    if len(history) < n:
        return []
    window = history[-n:]
    min_len = min(len(seq) for seq in window)
    agreed: list[str] = []
    for i in range(min_len):
        token = window[0][i]
        if all(seq[i] == token for seq in window):
            agreed.append(token)
        else:
            break
    return agreed


@dataclass
class Word:
    text: str
    start: float  # seconds, relative to the *start of the ring buffer*
    end: float


class StreamingTranscriber:
    """Wraps faster-whisper for streaming inference over a sliding window."""

    SAMPLE_RATE = 16000

    def __init__(
        self,
        model_name: str,
        device: str,
        language: str,
        window_seconds: float,
        agreement_n: int,
    ) -> None:
        # Import here so --version / --help don't pay the model-import cost.
        from faster_whisper import WhisperModel

        compute_type = "float16" if device == "cuda" else "int8"
        self._model = WhisperModel(model_name, device=device, compute_type=compute_type)
        self._language = language or None
        self._buffer = RingBuffer(int(window_seconds * self.SAMPLE_RATE))
        self._history: list[list[str]] = []
        self._agreement_n = agreement_n
        self._confirmed_tokens: list[str] = []
        self._confirmed_audio_offset = 0.0  # seconds of audio already represented by confirmed_tokens

    def add_audio(self, pcm_bytes: bytes) -> None:
        self._buffer.append(pcm_bytes)

    def _transcribe_words(self) -> list[Word]:
        audio = self._buffer.audio()
        if len(audio) < self.SAMPLE_RATE // 2:  # less than 500 ms — nothing to say yet
            return []
        segments, _info = self._model.transcribe(
            audio,
            language=self._language,
            beam_size=1,
            word_timestamps=True,
            vad_filter=False,
        )
        words: list[Word] = []
        for seg in segments:
            for w in (seg.words or []):
                words.append(Word(text=w.word.strip(), start=w.start, end=w.end))
        return words

    def step(self) -> dict | None:
        """Run one streaming step. Returns {confirmed, tentative} or None if not enough audio yet."""
        words = self._transcribe_words()
        if not words:
            return None

        tokens = [w.text for w in words]
        self._history.append(tokens)
        if len(self._history) > self._agreement_n:
            self._history.pop(0)

        agreed = longest_agreed_prefix(self._history, self._agreement_n)

        # New confirmations beyond what we already locked in.
        previously_confirmed_count = len(self._confirmed_tokens)
        newly_confirmed = agreed[previously_confirmed_count:]
        if newly_confirmed:
            # Audio up to the end of the last newly-confirmed word is "consumed".
            last_idx = len(self._confirmed_tokens) + len(newly_confirmed) - 1
            consumed_end = words[last_idx].end  # seconds in current buffer
            samples_to_drop = int(consumed_end * self.SAMPLE_RATE)
            self._buffer.drop_front(samples_to_drop)
            self._confirmed_tokens.extend(newly_confirmed)
            # Reset history; offsets are no longer comparable.
            self._history = []

        confirmed_text = " ".join(self._confirmed_tokens)
        tentative_text = " ".join(tokens[len(agreed):])
        return {"confirmed": confirmed_text, "tentative": tentative_text}

    def finalize(self) -> str:
        """One last pass over remaining audio; return full transcript (confirmed + final tail)."""
        segments, _ = self._model.transcribe(
            self._buffer.audio(),
            language=self._language,
            beam_size=5,
            vad_filter=False,
        )
        tail = " ".join(seg.text.strip() for seg in segments).strip()
        full = " ".join(self._confirmed_tokens + ([tail] if tail else []))
        return " ".join(full.split())  # collapse whitespace


def run_stream_loop(stdin, stdout, transcriber, chunk_bytes: int) -> None:
    """Drive the streaming transcriber. Read PCM chunks from stdin, emit JSON
    partials on stdout, emit `final` on EOF, return.
    """
    while True:
        chunk = stdin.read(chunk_bytes)
        if not chunk:
            break
        transcriber.add_audio(chunk)
        partial = transcriber.step()
        if partial is not None:
            stdout.write(json.dumps({"type": "partial", **partial}) + "\n")
            stdout.flush()

    final_text = transcriber.finalize()
    stdout.write(json.dumps({"type": "final", "text": final_text}) + "\n")
    stdout.flush()


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="xhisper-streamd",
        description="Streaming Whisper daemon — reads PCM s16le from stdin, emits JSON partials.",
    )
    parser.add_argument("--version", action="version", version=f"xhisper-streamd {__version__}")
    parser.add_argument("--model", default="small.en", help="Whisper model size")
    parser.add_argument("--device", default="cuda", choices=["auto", "cpu", "cuda"])
    parser.add_argument("--language", default="en", help="Language code or empty for auto")
    parser.add_argument("--window-seconds", type=float, default=8.0)
    parser.add_argument("--step-ms", type=int, default=500)
    parser.add_argument("--agreement-n", type=int, default=2)
    args = parser.parse_args()

    transcriber = StreamingTranscriber(
        model_name=args.model,
        device=args.device,
        language=args.language,
        window_seconds=args.window_seconds,
        agreement_n=args.agreement_n,
    )
    chunk_bytes = (args.step_ms * StreamingTranscriber.SAMPLE_RATE * 2) // 1000  # 2 = s16le bytes/sample
    run_stream_loop(sys.stdin.buffer, sys.stdout, transcriber, chunk_bytes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
