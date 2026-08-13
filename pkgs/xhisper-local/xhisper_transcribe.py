#!/usr/bin/env python3
"""
xhisper transcription using faster-whisper.

Prefers the local Hugging Face cache so Mod+Z does not block on the network
after the model has been downloaded once. CUDA failures fall back to CPU.
Errors go to stderr (xhisper.sh appends that to /tmp/xhisper.log).
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

logging.getLogger("faster_whisper").setLevel(logging.WARNING)


def load_model(model_size: str, device: str):
    from faster_whisper import WhisperModel

    def attempt(dev: str, local_only: bool):
        compute_type = "float16" if dev == "cuda" else "int8"
        return WhisperModel(
            model_size,
            device=dev,
            compute_type=compute_type,
            local_files_only=local_only,
        )

    try:
        return attempt(device, True)
    except Exception as err:
        if device == "cuda":
            print(
                f"xhisper: CUDA load failed ({err}); falling back to CPU",
                file=sys.stderr,
            )
            try:
                return attempt("cpu", True)
            except Exception:
                pass
        else:
            print(
                f"xhisper: local cache miss for {model_size} ({err}); downloading",
                file=sys.stderr,
            )

        try:
            return attempt(device, False)
        except Exception as download_err:
            if device == "cuda":
                print(
                    f"xhisper: CUDA download/load failed ({download_err}); falling back to CPU",
                    file=sys.stderr,
                )
                return attempt("cpu", False)
            raise


def transcribe_file(
    audio_path: str,
    model_size: str = "base",
    device: str = "auto",
    language: str | None = None,
    prompt: str | None = None,
) -> str:
    model = load_model(model_size, device)
    segments, _info = model.transcribe(
        audio_path,
        language=language,
        initial_prompt=prompt,
        beam_size=5,
        vad_filter=True,
    )
    text = " ".join(segment.text for segment in segments)
    return " ".join(text.split())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Transcribe audio files using faster-whisper"
    )
    parser.add_argument("audio_file", help="Path to audio file to transcribe")
    parser.add_argument(
        "--model",
        default="base",
        help="Whisper model size (default: base)",
    )
    parser.add_argument(
        "--device",
        default="auto",
        choices=["auto", "cpu", "cuda"],
        help="Device to use (default: auto)",
    )
    parser.add_argument(
        "--language",
        help="Language code (e.g. en, es) for faster/more accurate transcription",
    )
    parser.add_argument(
        "--prompt",
        help="Context words for better accuracy",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug output",
    )
    args = parser.parse_args()

    if args.debug:
        logging.getLogger("faster_whisper").setLevel(logging.DEBUG)

    if not Path(args.audio_file).exists():
        print(f"Error: Audio file not found: {args.audio_file}", file=sys.stderr)
        return 1

    try:
        print(
            transcribe_file(
                args.audio_file,
                model_size=args.model,
                device=args.device,
                language=args.language,
                prompt=args.prompt,
            )
        )
    except Exception as exc:
        print(f"Error during transcription: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
