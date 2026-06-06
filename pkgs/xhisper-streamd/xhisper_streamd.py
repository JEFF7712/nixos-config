#!/usr/bin/env python3
"""xhisper-streamd: streaming Whisper daemon with LocalAgreement-2."""
import argparse
import sys

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

    # Placeholder — real streaming loop added in Task 5.
    print(f"xhisper-streamd starting: model={args.model} device={args.device}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
