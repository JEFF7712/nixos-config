#!/usr/bin/env iris-python
from __future__ import annotations

import configparser
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from typing import Any

import numpy as np
from numpy.typing import NDArray
from PIL import Image, ImageOps

VERSION = 5
CLEAR_EDGE_DENSITY = 0.025
CLEAR_COLOR_SPREAD = 0.04
RGB = NDArray[np.float64]


def luminance(rgb: RGB) -> RGB:
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return linear @ np.array([0.2126, 0.7152, 0.0722])


def contrast(a: RGB, b: RGB) -> RGB:
    x, y = luminance(a), luminance(b)
    return (np.maximum(x, y) + 0.05) / (np.minimum(x, y) + 0.05)


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def wallpaper_source(screen: str) -> tuple[Path, str, str, float]:
    settings = configparser.ConfigParser(interpolation=None)
    settings.read(config_home() / "waypaper/config.ini")
    section = (
        settings[screen]
        if settings.has_section(screen)
        else settings["Settings"]
        if settings.has_section("Settings")
        else {}
    )
    path = str(section.get("wallpaper", ""))
    fill = str(section.get("fill", "fill"))
    color = str(section.get("color", "#000000"))
    scale = 1.0
    try:
        query = subprocess.run(
            ["awww", "query"], capture_output=True, text=True, timeout=2, check=True
        )
        for line in query.stdout.splitlines():
            match = re.search(
                r"(?:^|: )"
                + re.escape(screen)
                + r": .*?currently displaying: image: (.*)$",
                line,
            )
            if match:
                if (
                    Path(path).expanduser().resolve()
                    != Path(match.group(1)).expanduser().resolve()
                ):
                    fill = "fill"
                path = match.group(1)
                density = re.search(r"scale: ([0-9.]+)", line)
                if density:
                    scale = float(density.group(1))
                break
    except (OSError, subprocess.SubprocessError):
        pass
    if not path:
        raise ValueError("No wallpaper is configured")
    return Path(path).expanduser().resolve(), fill, color, scale


def render_wallpaper(
    path: Path, size: tuple[int, int], fill: str, color: str
) -> Image.Image:
    if path.suffix.lower() in {".mp4", ".webm", ".mkv", ".mov", ".gif"}:
        raise ValueError("Animated wallpaper needs a stable readability backdrop")
    with Image.open(path) as source:
        image = ImageOps.exif_transpose(source).convert("RGB")
    if fill in {"fill", "crop"}:
        return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)
    if fill in {"fit", "center"}:
        if fill == "fit":
            image = ImageOps.contain(image, size, method=Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", size, color)
        canvas.paste(
            image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2)
        )
        return canvas
    if fill == "stretch":
        return image.resize(size, Image.Resampling.LANCZOS)
    if fill == "tile":
        canvas = Image.new("RGB", size, color)
        for y in range(0, size[1], image.height):
            for x in range(0, size[0], image.width):
                canvas.paste(image, (x, y))
        return canvas
    raise ValueError(f"Unsupported wallpaper fill mode: {fill}")


def read_overrides(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(
            (config_home() / "desktop-profiles/idle-layout.json").read_text()
        )
        return data.get(str(path), data.get(path.name, {}))
    except (OSError, ValueError, AttributeError):
        return {}


def integral(values: RGB) -> RGB:
    return np.pad(values.cumsum(axis=0).cumsum(axis=1), ((1, 0), (1, 0)))


def mean_region(table: RGB, box: tuple[int, int, int, int]) -> float:
    x, y, right, bottom = box
    return float(
        (table[bottom, right] - table[y, right] - table[bottom, x] + table[y, x])
        / max(1, (right - x) * (bottom - y))
    )


def readable_colors(request: dict[str, Any]) -> tuple[RGB, RGB, RGB]:
    foreground = np.array(request.get("foreground", [1, 1, 1]), dtype=float)
    backing = np.zeros(3) if float(luminance(foreground)) > 0.3 else np.ones(3)
    original = foreground.copy()
    for amount in np.linspace(0, 1, 21):
        foreground = original * (1 - amount) + (1 - backing) * amount
        if float(contrast(foreground * 0.72 + backing * 0.28, backing)) >= 4.8:
            break
    accent = np.array(request.get("accent", foreground), dtype=float)
    for amount in np.linspace(0, 1, 21):
        adjusted = accent * (1 - amount) + foreground * amount
        if float(contrast(adjusted, backing)) >= 4.8:
            return foreground, adjusted, backing
    return foreground, foreground, backing


def hex_color(color: RGB) -> str:
    return "#" + "".join(f"{round(float(v) * 255):02x}" for v in color)


def backdrop_opacity(pixels: RGB, foreground: RGB, accent: RGB, backing: RGB) -> float:
    for opacity in np.linspace(0, 1, 41):
        background = pixels * (1 - opacity) + backing * opacity
        dimmed_text = foreground * 0.72 + background * 0.28
        if (
            np.min(contrast(dimmed_text, background)) >= 4.5
            and np.min(contrast(accent, background)) >= 4.5
        ):
            return round(float(opacity), 3)
    return 1.0


def centered_layout(request: dict[str, Any]) -> dict[str, Any]:
    width, height = request["width"], request["height"]
    candidates = request["candidates"]
    candidate = next(
        (
            c
            for c in candidates
            if c["name"] == "wide"
            and c["width"] + 48 <= width
            and c["height"] + 48 <= height
        ),
        max(
            candidates,
            key=lambda c: min(
                1, (width - 48) / c["width"], (height - 48) / c["height"]
            ),
        ),
    )
    scale = min(
        1, (width - 48) / candidate["width"], (height - 48) / candidate["height"]
    )
    return {
        **candidate,
        "x": (width - candidate["width"] * scale) / 2,
        "y": (height - candidate["height"] * scale) / 2,
        "scale": scale,
        "placement": "centered",
    }


def choose_layout(
    image: Image.Image, request: dict[str, Any], overrides: dict[str, Any] | None = None
) -> dict[str, Any]:
    width, height = float(request["width"]), float(request["height"])
    sample = image.copy()
    sample.thumbnail((320, 320), Image.Resampling.LANCZOS)
    rgb = np.asarray(sample, dtype=float) / 255
    light = luminance(rgb)
    gy, gx = np.gradient(light)
    edges = np.minimum(1, np.hypot(gx, gy) * 12)
    saturation = rgb.max(axis=2) - rgb.min(axis=2)
    attention = np.minimum(1, np.abs(light - np.median(light)) * 2 + saturation * 0.6)
    busyness = integral(edges * 3 + attention)
    edge_density = integral(edges)
    color_moments = [
        (integral(rgb[:, :, channel]), integral(rgb[:, :, channel] ** 2))
        for channel in range(3)
    ]
    foreground, accent, backing = readable_colors(request)
    contrast_cost = integral(
        (contrast(foreground * 0.72 + rgb * 0.28, rgb) < 4.5).astype(float)
    )
    overrides = overrides or {}
    preference = overrides.get("prefer", "auto")
    automatic = preference == "auto" and not overrides.get("avoid")
    best: dict[str, Any] | None = None
    best_score = float("inf")
    margin = min(48.0, width * 0.04, height * 0.04)

    def sample_box(x: float, y: float, w: float, h: float) -> tuple[int, int, int, int]:
        return (
            max(0, int(x / width * sample.width)),
            max(0, int(y / height * sample.height)),
            min(sample.width, int(np.ceil((x + w) / width * sample.width))),
            min(sample.height, int(np.ceil((y + h) / height * sample.height))),
        )

    def is_clear(box: tuple[int, int, int, int]) -> bool:
        variance = (
            sum(
                max(0, mean_region(square, box) - mean_region(mean, box) ** 2)
                for mean, square in color_moments
            )
            / 3
        )
        return (
            mean_region(edge_density, box) <= CLEAR_EDGE_DENSITY
            and variance <= CLEAR_COLOR_SPREAD**2
        )

    for candidate in request["candidates"]:
        cw, ch = float(candidate["width"]), float(candidate["height"])
        scale = min(1.0, (width - 2 * margin) / cw, (height - 2 * margin) / ch)
        w, h = cw * scale, ch * scale
        xs = np.linspace(margin, width - w - margin, 19)
        ys = np.linspace(margin, height - h - margin, 13)
        for x, y in itertools.product(xs, ys):
            box = sample_box(x, y, w, h)
            activity = mean_region(busyness, box)
            if automatic and not is_clear(box):
                continue
            score = activity * 6 + mean_region(contrast_cost, box) * 0.8
            center_x, center_y = (x + w / 2) / width, (y + h / 2) / height
            target_x = {"left": 0.2, "right": 0.8}.get(preference, 0.5)
            target_y = {"top": 0.2, "bottom": 0.8}.get(preference, 0.45)
            score += ((center_x - target_x) ** 2 + (center_y - target_y) ** 2) * (
                2 if preference != "auto" else 0.12
            )
            score += center_x * 0.012
            score += (0.04 if candidate["name"] == "compact" else 0) + (1 - scale) * 2
            for avoid in overrides.get("avoid", []):
                ax, ay, aw, ah = avoid
                overlap = max(
                    0, min(x + w, (ax + aw) * width) - max(x, ax * width)
                ) * max(0, min(y + h, (ay + ah) * height) - max(y, ay * height))
                score += overlap / (w * h) * 100
            if score < best_score:
                best_score = score
                best = {
                    "name": candidate["name"],
                    "x": round(float(x), 2),
                    "y": round(float(y), 2),
                    "scale": round(scale, 5),
                    "width": cw,
                    "height": ch,
                    "placement": "clear" if automatic else "override",
                }
    centered = centered_layout(request)
    center_box = sample_box(
        centered["x"],
        centered["y"],
        centered["width"] * centered["scale"],
        centered["height"] * centered["scale"],
    )
    if best is None or preference == "center" or (automatic and is_clear(center_box)):
        best = centered
    x, y = best["x"], best["y"]
    region = image.crop(
        (
            int(x / width * image.width),
            int(y / height * image.height),
            min(
                image.width,
                int(np.ceil((x + best["width"] * best["scale"]) / width * image.width)),
            ),
            min(
                image.height,
                int(
                    np.ceil(
                        (y + best["height"] * best["scale"]) / height * image.height
                    )
                ),
            ),
        )
    )
    # Full-resolution channel extrema keep small bright details out of the downsampling blind spot.
    ranges = np.asarray(region.getextrema(), dtype=float).reshape(3, 2) / 255
    extrema = np.array(list(itertools.product(*ranges)))
    best.update(
        {
            "backdropOpacity": backdrop_opacity(extrema, foreground, accent, backing),
            "backdropColor": hex_color(backing),
            "foreground": hex_color(foreground),
            "accent": hex_color(accent),
            "available": True,
        }
    )
    return best


def fallback(request: dict[str, Any]) -> dict[str, Any]:
    foreground, accent, backing = readable_colors(request)
    return {
        **centered_layout(request),
        "backdropOpacity": 1,
        "backdropColor": hex_color(backing),
        "foreground": hex_color(foreground),
        "accent": hex_color(accent),
        "available": False,
    }


def analyse(request: dict[str, Any]) -> dict[str, Any]:
    path, fill, color, scale = wallpaper_source(request["screen"])
    overrides = read_overrides(path)
    stat = path.stat()
    token = hashlib.sha256(
        json.dumps(
            [
                VERSION,
                request,
                str(path),
                stat.st_mtime_ns,
                stat.st_size,
                fill,
                color,
                scale,
                overrides,
            ],
            sort_keys=True,
        ).encode()
    ).hexdigest()
    cache_dir = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        / "quickshell/idle-layout"
    )
    cache_file = cache_dir / (
        hashlib.sha256(request["screen"].encode()).hexdigest()[:16] + ".json"
    )
    try:
        cached = json.loads(cache_file.read_text())
        if cached.get("key") == token:
            return cached["result"]
    except (OSError, ValueError):
        pass
    image = render_wallpaper(
        path,
        (round(request["width"] * scale), round(request["height"] * scale)),
        fill,
        color,
    )
    result = choose_layout(image, request, overrides)
    result["wallpaper"] = str(path)
    try:
        cache_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=cache_dir, delete=False) as out:
            json.dump({"key": token, "result": result}, out)
        os.replace(out.name, cache_file)
    except OSError:
        pass
    return result


def main() -> None:
    request = json.loads(sys.argv[1])
    try:
        result = analyse(request)
    except (OSError, ValueError, KeyError, Image.DecompressionBombError) as error:
        result = fallback(request)
        result["error"] = str(error)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
