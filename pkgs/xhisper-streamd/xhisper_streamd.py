#!/usr/bin/env python3
"""xhisper-streamd: streaming Whisper daemon with LocalAgreement-2."""
import argparse
import sys

__version__ = "0.1.0"


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
