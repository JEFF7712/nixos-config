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

VERSION = 15
CLEAR_EDGE_DENSITY = 0.025
CLEAR_COLOR_SPREAD = 0.04
# The gap between split panels must be this much busier than the panels themselves.
SPLIT_SUBJECT_RATIO = 3.0
# Focal-mass height difference (fraction of screen) that earns the full counterweight offset.
SPLIT_DIAGONAL_FULL = 0.08
SPLIT_COUNTERWEIGHT = 0.7
# Edge strength that counts as linework; dilated so thin or sparse strokes still occupy space.
INK_EDGE = 0.15
INK_DILATE = 2
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
            # Prescaled renders from wallpaper-prewarm are not the source; keep the
            # configured path so per-wallpaper overrides still match.
            if match and "/wallpaper-renders/" in match.group(1):
                density = re.search(r"scale: ([0-9.]+)", line)
                if density:
                    scale = float(density.group(1))
                break
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
    # Box-reduce oversized sources first; LANCZOS straight from 4K costs ~5x more.
    factor = min(image.width // size[0], image.height // size[1])
    if factor >= 2:
        image = image.reduce(factor)
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
    # Split and band only make sense where placement found room for them.
    candidates = [
        c for c in request["candidates"] if "width2" not in c and c["name"] != "band"
    ]
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
    # Saliency is local contrast in brightness and colour: a smooth vignette or a flat
    # tinted sky is negative space even when it is far from the image's average.
    radius = max(2, min(light.shape) // 16)
    size = 2 * radius + 1

    def local_mean(channel: RGB) -> RGB:
        table = integral(np.pad(channel, radius, mode="edge"))
        return (
            table[size:, size:]
            - table[:-size, size:]
            - table[size:, :-size]
            + table[:-size, :-size]
        ) / size**2

    colour_shift = np.sqrt(
        sum((rgb[:, :, c] - local_mean(rgb[:, :, c])) ** 2 for c in range(3))
    )
    attention = np.minimum(
        1, np.abs(light - local_mean(light)) * 3 + colour_shift * 1.5
    )
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

    weight = edges * 3 + attention
    total = float(weight.sum()) or 1.0
    subject_x = (
        float(
            (weight.sum(axis=0) * (np.arange(weight.shape[1]) + 0.5)).sum()
            / total
            / weight.shape[1]
        )
        * width
    )
    columns = np.cumsum(weight.sum(axis=0)) / total
    subject_left = float(np.searchsorted(columns, 0.03)) / weight.shape[1] * width
    subject_right = float(np.searchsorted(columns, 0.97) + 1) / weight.shape[1] * width
    subject_y = (
        float(
            (weight.sum(axis=1) * (np.arange(weight.shape[0]) + 0.5)).sum()
            / total
            / weight.shape[0]
        )
        * height
    )

    ink = edges > INK_EDGE
    for _ in range(INK_DILATE):
        grown = ink.copy()
        grown[1:] |= ink[:-1]
        grown[:-1] |= ink[1:]
        grown[:, 1:] |= ink[:, :-1]
        grown[:, :-1] |= ink[:, 1:]
        ink = grown
    ink_cover = integral(ink.astype(float))

    # Focal mass: bright, saturated detail inside the subject span. When it leans on a
    # diagonal, split panels counterweight it (left panel opposite the left-side mass).
    focal = weight * (0.3 + saturation) * light
    span = slice(
        int(subject_left / width * weight.shape[1]),
        max(1, int(np.ceil(subject_right / width * weight.shape[1]))),
    )
    focal_cols = np.arange(weight.shape[1])[span]
    focal_span = focal[:, span]
    if focal_span.size and focal_span.max() > 0:
        focal_span = np.where(
            focal_span >= np.quantile(focal_span, 0.95), focal_span, 0
        )
    rows = np.arange(weight.shape[0]) + 0.5
    split_col = subject_x / width * weight.shape[1]

    def focal_y(mask: NDArray[np.bool_]) -> float:
        mass = focal_span[:, mask]
        total_mass = float(mass.sum())
        if total_mass <= 0:
            return subject_y
        return (
            float((mass.sum(axis=1) * rows).sum() / total_mass)
            / weight.shape[0]
            * height
        )

    diagonal = float(
        np.clip(
            (focal_y(focal_cols >= split_col) - focal_y(focal_cols < split_col))
            / height
            / SPLIT_DIAGONAL_FULL,
            -1,
            1,
        )
    )

    def panel_score(box: tuple[int, int, int, int]) -> float:
        return (
            mean_region(busyness, box) * 6
            + mean_region(contrast_cost, box) * 0.8
            + mean_region(ink_cover, box) * 8
        )

    def best_split(candidate: dict[str, Any]) -> dict[str, Any] | None:
        fit = min(
            1.0,
            (width - 3 * margin) / (candidate["width"] + candidate["width2"]),
            (height - 2 * margin) / max(candidate["height"], candidate["height2"]),
        )
        found = None
        # Shrunk panels can tuck into corners beside a diagonal subject.
        for scale in (fit, fit * 0.9, fit * 0.8):
            pose = split_at(candidate, scale)
            if pose is not None and (found is None or pose["_score"] < found["_score"]):
                found = pose
        return found

    def split_at(candidate: dict[str, Any], scale: float) -> dict[str, Any] | None:
        aw, ah = float(candidate["width"]), float(candidate["height"])
        bw, bh = float(candidate["width2"]), float(candidate["height2"])
        aw, ah, bw, bh = aw * scale, ah * scale, bw * scale, bh * scale

        def panels(
            w: float, h: float, lo: float, hi: float
        ) -> list[tuple[float, float, float]]:
            out = []
            if hi < lo:
                return out
            for x, y in itertools.product(
                np.linspace(lo, hi, 15), np.linspace(margin, height - h - margin, 13)
            ):
                box = sample_box(x, y, w, h)
                if automatic and not is_clear(box):
                    continue
                out.append((float(x), float(y), panel_score(box)))
            return out

        # Panel A (clock) sits left of the subject, panel B (stats) right of it.
        left = panels(aw, ah, margin, subject_x - aw)
        right = panels(bw, bh, subject_x, width - bw - margin)
        found = None
        found_score = float("inf")
        for ax, ay, a_score in left:
            for bx, by, b_score in right:
                gap_left, gap_right = ax + aw, bx
                if gap_right - gap_left < margin:
                    continue
                top, bottom = min(ay, by), max(ay + ah, by + bh)
                gap = mean_region(
                    busyness,
                    sample_box(gap_left, top, gap_right - gap_left, bottom - top),
                )
                panel_activity = max(
                    mean_region(busyness, sample_box(ax, ay, aw, ah)),
                    mean_region(busyness, sample_box(bx, by, bw, bh)),
                )
                if gap < max(1e-3, panel_activity) * SPLIT_SUBJECT_RATIO:
                    continue
                # Centre each panel in the gutter beside the subject, level with the subject.
                gutters = (
                    abs(ax + aw / 2 - max(aw / 2 + margin, subject_left / 2))
                    + abs(
                        bx
                        + bw / 2
                        - min(width - bw / 2 - margin, (subject_right + width) / 2)
                    )
                ) / width
                a_target = (
                    height / 2
                    + diagonal
                    * max(0.0, (height - ah) / 2 - margin)
                    * SPLIT_COUNTERWEIGHT
                )
                b_target = (
                    height / 2
                    - diagonal
                    * max(0.0, (height - bh) / 2 - margin)
                    * SPLIT_COUNTERWEIGHT
                )
                vertical = (
                    abs(ay + ah / 2 - a_target) + abs(by + bh / 2 - b_target)
                ) / height
                score = (
                    a_score + b_score + gutters * 1.5 + vertical * 0.6 + (1 - scale) * 2
                )
                if score < found_score:
                    found_score = score
                    found = {
                        "name": candidate["name"],
                        "x": round(ax, 2),
                        "y": round(ay, 2),
                        "width": float(candidate["width"]),
                        "height": float(candidate["height"]),
                        "x2": round(bx, 2),
                        "y2": round(by, 2),
                        "width2": float(candidate["width2"]),
                        "height2": float(candidate["height2"]),
                        "scale": round(scale, 5),
                        "placement": "split",
                        "diagonal": round(diagonal, 3),
                        "_score": score,
                    }
        return found

    def finish(
        result: dict[str, Any], regions: list[tuple[float, float, float, float]]
    ) -> dict[str, Any]:
        opacity = 0.0
        for x, y, w, h in regions:
            region = image.crop(
                (
                    int(x / width * image.width),
                    int(y / height * image.height),
                    min(
                        image.width,
                        int(np.ceil((x + w * result["scale"]) / width * image.width)),
                    ),
                    min(
                        image.height,
                        int(np.ceil((y + h * result["scale"]) / height * image.height)),
                    ),
                )
            )
            # Full-resolution channel extrema keep small bright details out of the downsampling blind spot.
            ranges = np.asarray(region.getextrema(), dtype=float).reshape(3, 2) / 255
            extrema = np.array(list(itertools.product(*ranges)))
            opacity = max(
                opacity, backdrop_opacity(extrema, foreground, accent, backing)
            )
        result.update(
            {
                "backdropOpacity": opacity,
                "backdropColor": hex_color(backing),
                "foreground": hex_color(foreground),
                "accent": hex_color(accent),
                "available": True,
            }
        )
        return result

    for candidate in request["candidates"]:
        if "width2" in candidate:
            continue
        cw, ch = float(candidate["width"]), float(candidate["height"])
        fit = min(1.0, (width - 2 * margin) / cw, (height - 2 * margin) / ch)
        # Slightly smaller poses can slip into a short strip of negative space.
        for scale in (fit, fit * 0.9, fit * 0.8):
            w, h = cw * scale, ch * scale
            xs = np.linspace(margin, width - w - margin, 19)
            ys = np.linspace(margin, height - h - margin, 13)
            for x, y in itertools.product(xs, ys):
                box = sample_box(x, y, w, h)
                activity = mean_region(busyness, box)
                if automatic and not is_clear(box):
                    continue
                score = (
                    activity * 6
                    + mean_region(contrast_cost, box) * 0.8
                    + mean_region(ink_cover, box) * 8
                )
                center_x, center_y = (x + w / 2) / width, (y + h / 2) / height
                target_x = {"left": 0.2, "right": 0.8}.get(preference, 0.5)
                target_y = {"top": 0.2, "bottom": 0.8}.get(preference, 0.45)
                score += ((center_x - target_x) ** 2 + (center_y - target_y) ** 2) * (
                    2 if preference != "auto" else 0.12
                )
                score += center_x * 0.04
                score += (0.04 if candidate["name"] == "compact" else 0) + (
                    1 - scale
                ) * 2
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
    split = None
    split_candidate = next((c for c in request["candidates"] if "width2" in c), None)
    if split_candidate is not None and preference in {"auto", "split"}:
        split = best_split(split_candidate)
    if split is not None and (
        preference == "split" or best is None or split["_score"] <= best_score + 0.35
    ):
        best = split
        best_score = split.pop("_score")
        regions = [
            (best["x"], best["y"], best["width"], best["height"]),
            (best["x2"], best["y2"], best["width2"], best["height2"]),
        ]
        return finish(best, regions)

    centered = centered_layout(request)
    center_box = sample_box(
        centered["x"],
        centered["y"],
        centered["width"] * centered["scale"],
        centered["height"] * centered["scale"],
    )
    if best is None or preference == "center" or (automatic and is_clear(center_box)):
        best = centered
    return finish(best, [(best["x"], best["y"], best["width"], best["height"])])


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


RENDER_CACHE_KEEP = 12


def cached_render(
    cache_dir: Path, path: Path, size: tuple[int, int], fill: str, color: str
) -> Image.Image:
    # Palette changes re-run placement against the same wallpaper moments later;
    # reuse the screen-sized render instead of decoding the source again.
    stat = path.stat()
    key = hashlib.sha256(
        json.dumps(
            [str(path), stat.st_mtime_ns, stat.st_size, list(size), fill, color]
        ).encode()
    ).hexdigest()[:24]
    # Same key as wallpaper-prewarm / prescaled_wallpaper (centred crop only).
    if fill in {"fill", "crop"}:
        shared = (
            cache_dir.parent.parent
            / "wallpaper-renders"
            / f"{size[0]}x{size[1]}"
            / (
                hashlib.sha256(
                    f"{path}\0{int(stat.st_mtime)}\0{stat.st_size}".encode()
                ).hexdigest()[:24]
                + ".jpg"
            )
        )
        try:
            with Image.open(shared) as image:
                return image.convert("RGB")
        except OSError:
            pass
    renders = cache_dir / "renders"
    cached = renders / f"{key}.png"
    try:
        with Image.open(cached) as image:
            return image.convert("RGB")
    except OSError:
        pass
    image = render_wallpaper(path, size, fill, color)
    try:
        renders.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            dir=renders, suffix=".png", delete=False
        ) as out:
            image.save(out, format="PNG", compress_level=1)
        os.replace(out.name, cached)
        stale = sorted(renders.glob("*.png"), key=lambda f: f.stat().st_mtime)
        for old in stale[:-RENDER_CACHE_KEEP]:
            old.unlink(missing_ok=True)
    except OSError:
        pass
    return image


def analyse(request: dict[str, Any]) -> dict[str, Any]:
    path, fill, color, scale = wallpaper_source(request["screen"])
    # The transition stamp names the incoming wallpaper before awww reports it.
    if request.get("wallpaper"):
        path = Path(request["wallpaper"]).expanduser().resolve()
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
    image = cached_render(
        cache_dir,
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
