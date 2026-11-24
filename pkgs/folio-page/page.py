"""Dither the lower band of a wallpaper into folio's two-tone page.png.

Port of writePage from seg6/dotfiles tools/cli/internal/theme/folio.go.
"""

import math
import os
import sys
import tempfile

import numpy as np
from PIL import Image

WIDTH, HEIGHT = 640, 360


def tones(path):
    source = Image.open(path).convert("RGB")
    w, h = source.size
    rgb = np.asarray(source, dtype=np.float64) / 255.0
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    table = np.zeros((h + 1, w + 1))
    table[1:, 1:] = lum.cumsum(0).cumsum(1)

    scale = max(WIDTH / w, HEIGHT / h)
    offset_x = (w * scale - WIDTH) / 2
    drop = 0.2 * HEIGHT
    out = np.zeros((HEIGHT, WIDTH))
    xs = np.arange(WIDTH, dtype=np.float64)
    sx0 = np.clip(np.floor((xs + offset_x) / scale).astype(int), 0, w)
    sx1 = np.clip(np.ceil((xs + 1 + offset_x) / scale).astype(int), 0, w)
    for y in range(HEIGHT):
        strength = min(1.0, max(0.0, (y / HEIGHT - 0.58) / 0.20))
        if strength == 0:
            continue
        sy0 = min(max(int(math.floor((y - drop) / scale)), 0), h)
        sy1 = min(max(int(math.ceil((y + 1 - drop) / scale)), 0), h)
        if sy1 <= sy0:
            continue
        total = table[sy1, sx1] - table[sy0, sx1] - table[sy1, sx0] + table[sy0, sx0]
        count = (sx1 - sx0) * (sy1 - sy0)
        with np.errstate(invalid="ignore", divide="ignore"):
            tone = np.where(count > 0, total / np.maximum(count, 1), 0.0)
        tone = 1 / (1 + np.exp(-5 * (tone - 0.5)))
        tone = np.power(tone, 1.7) * 0.92
        out[y] = np.where(count > 0, tone * strength, 0.0)
    return out


def dither(work):
    work = work.tolist()
    lit = bytearray(WIDTH * HEIGHT)
    for y in range(HEIGHT):
        row = work[y]
        below = work[y + 1] if y + 1 < HEIGHT else None
        for x in range(WIDTH):
            value = row[x]
            if value == 0.0:
                continue
            on = 1.0 if value >= 0.5 else 0.0
            if on:
                lit[y * WIDTH + x] = 1
            spare = value - on
            if x + 1 < WIDTH:
                row[x + 1] += spare * 7 / 16
            if below is not None:
                if x > 0:
                    below[x - 1] += spare * 3 / 16
                below[x] += spare * 5 / 16
                if x + 1 < WIDTH:
                    below[x + 1] += spare * 1 / 16
    return bytes(lit)


def hex_rgb(value):
    value = value.lstrip("#")
    return [int(value[i : i + 2], 16) for i in (0, 2, 4)]


def main():
    if len(sys.argv) != 5:
        sys.exit("usage: folio-page WALLPAPER TARGET PAPER INK")
    wallpaper, target, paper, ink = sys.argv[1:]
    page = Image.frombytes("P", (WIDTH, HEIGHT), dither(tones(wallpaper)))
    page.putpalette(hex_rgb(paper) + hex_rgb(ink))
    directory = os.path.dirname(os.path.abspath(target))
    os.makedirs(directory, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".page.", suffix=".png", dir=directory)
    os.close(fd)
    try:
        page.save(temporary, "PNG")
        os.chmod(temporary, 0o644)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)


if __name__ == "__main__":
    main()
