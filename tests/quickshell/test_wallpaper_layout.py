from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

SOURCE = (
    Path(__file__).resolve().parents[2]
    / "home/configs/quickshell/services/internal/wallpaper_layout.py"
)
SPEC = importlib.util.spec_from_file_location("wallpaper_layout", SOURCE)
assert SPEC and SPEC.loader
layout = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(layout)


def request(width: int = 1440, height: int = 900) -> dict:
    return {
        "screen": "test-monitor",
        "width": width,
        "height": height,
        "foreground": [1, 1, 1],
        "accent": [0.92, 0.17, 0.87],
        "candidates": [
            {"name": "wide", "width": 1048, "height": 440},
            {"name": "compact", "width": 448, "height": 648},
        ],
    }


class WallpaperLayoutTests(unittest.TestCase):
    def assert_in_bounds(self, result: dict, query: dict) -> None:
        self.assertGreaterEqual(result["x"], 0)
        self.assertGreaterEqual(result["y"], 0)
        self.assertLessEqual(
            result["x"] + result["width"] * result["scale"], query["width"] + 0.02
        )
        self.assertLessEqual(
            result["y"] + result["height"] * result["scale"], query["height"] + 0.02
        )

    def assert_centered(self, result: dict, query: dict) -> None:
        self.assertAlmostEqual(
            result["x"] + result["width"] * result["scale"] / 2, query["width"] / 2
        )
        self.assertAlmostEqual(
            result["y"] + result["height"] * result["scale"] / 2, query["height"] / 2
        )
        self.assertEqual(result["placement"], "centered")

    def test_central_artwork_uses_clear_side(self) -> None:
        image = Image.new("RGB", (1440, 900), "black")
        noise = np.random.default_rng(10).integers(
            0, 255, (740, 400, 3), dtype=np.uint8
        )
        image.paste(Image.fromarray(noise), (520, 80))
        result = layout.choose_layout(image, request())
        self.assertEqual(result["name"], "compact")
        self.assertLess(result["x"] + result["width"], 520)
        self.assertEqual(result["backdropOpacity"], 0)

    def test_subject_on_left_uses_right(self) -> None:
        image = Image.new("RGB", (1440, 900), "black")
        noise = np.random.default_rng(11).integers(
            0, 255, (900, 800, 3), dtype=np.uint8
        )
        image.paste(Image.fromarray(noise), (0, 0))
        result = layout.choose_layout(image, request())
        self.assertGreaterEqual(result["x"], 800)
        self.assertEqual(result["backdropOpacity"], 0)

    def test_uniform_wallpaper_keeps_wide_layout(self) -> None:
        result = layout.choose_layout(Image.new("RGB", (1440, 900), "black"), request())
        self.assertEqual(result["name"], "wide")
        self.assertEqual(result["backdropOpacity"], 0)
        self.assert_centered(result, request())

    def test_busy_wallpaper_backdrop_meets_text_contrast(self) -> None:
        pixels = np.random.default_rng(12).integers(
            0, 256, (900, 1440, 3), dtype=np.uint8
        )
        query = request()
        result = layout.choose_layout(Image.fromarray(pixels), query)
        self.assertEqual(result["name"], "wide")
        self.assert_centered(result, query)
        self.assertGreater(result["backdropOpacity"], 0)
        foreground, accent, backing = layout.readable_colors(query)
        background = (
            pixels / 255 * (1 - result["backdropOpacity"])
            + backing * result["backdropOpacity"]
        )
        text = foreground * 0.72 + background * 0.28
        self.assertGreaterEqual(np.min(layout.contrast(text, background)), 4.5)
        self.assertGreaterEqual(np.min(layout.contrast(accent, background)), 4.5)

    def test_smooth_colorful_wallpaper_uses_center(self) -> None:
        y, x = np.mgrid[0:900, 0:1440]
        pixels = np.stack(
            (0.2 + 0.7 * x / 1440, 0.1 + 0.6 * y / 900, 0.9 - 0.5 * x / 1440), axis=2
        )
        result = layout.choose_layout(
            Image.fromarray((pixels * 255).astype(np.uint8)), request()
        )
        self.assertEqual(result["name"], "wide")
        self.assert_centered(result, request())

    def test_small_highlight_is_included_in_contrast(self) -> None:
        image = Image.new("RGB", (1440, 900), "black")
        for x in range(80, image.width, 160):
            for y in range(80, image.height, 160):
                image.putpixel((x, y), (255, 255, 255))
        result = layout.choose_layout(image, request())
        self.assertGreater(result["backdropOpacity"], 0)

    def test_light_theme_and_low_contrast_accent(self) -> None:
        query = {
            **request(),
            "foreground": [0.05, 0.05, 0.05],
            "accent": [0.95, 0.95, 0.95],
        }
        result = layout.choose_layout(Image.new("RGB", (1440, 900), "white"), query)
        self.assertEqual(result["backdropColor"], "#ffffff")
        self.assertNotEqual(result["accent"], "#f2f2f2")
        self.assertEqual(result["backdropOpacity"], 0)

    def test_mid_gray_theme_text_is_adjusted_for_contrast(self) -> None:
        query = {**request(), "foreground": [0.5, 0.5, 0.5]}
        foreground, _, backing = layout.readable_colors(query)
        text = foreground * 0.72 + backing * 0.28
        self.assertGreaterEqual(float(layout.contrast(text, backing)), 4.5)

    def test_small_and_portrait_screens_fit(self) -> None:
        for width, height in [(640, 480), (900, 1440), (1920, 1080), (3440, 1440)]:
            with self.subTest(width=width, height=height):
                query = request(width, height)
                result = layout.choose_layout(
                    Image.new("RGB", (width, height), "black"), query
                )
                self.assert_in_bounds(result, query)
                self.assert_in_bounds(layout.fallback(query), query)

    def test_saved_avoid_region_is_respected(self) -> None:
        result = layout.choose_layout(
            Image.new("RGB", (1440, 900), "black"),
            request(),
            {"prefer": "right", "avoid": [[0, 0, 0.6, 1]]},
        )
        self.assertGreaterEqual(result["x"], 864)

    def test_center_crop_matches_monitor_aspect(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "wallpaper.png"
            image = Image.new("RGB", (1200, 600), "red")
            image.paste(Image.new("RGB", (600, 600), "blue"), (300, 0))
            image.save(source)
            result = layout.render_wallpaper(source, (600, 600), "fill", "black")
            self.assertEqual(result.getpixel((20, 300)), (0, 0, 255))
            self.assertEqual(result.getpixel((580, 300)), (0, 0, 255))

    def test_cache_reuses_result_and_invalidates_changed_image(self) -> None:
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.dict(os.environ, {"XDG_CACHE_HOME": tmp}),
        ):
            path = Path(tmp) / "wallpaper.png"
            Image.new("RGB", (1440, 900), "black").save(path)
            with patch.object(
                layout, "wallpaper_source", return_value=(path, "fill", "#000000", 1.0)
            ):
                first = layout.analyse(request())
                with patch.object(
                    layout,
                    "render_wallpaper",
                    side_effect=AssertionError("cache missed"),
                ):
                    self.assertEqual(layout.analyse(request()), first)
                Image.new("RGB", (1440, 900), "white").save(path)
                self.assertGreater(layout.analyse(request())["backdropOpacity"], 0)

    def test_live_output_source_and_scale_override_stale_config(self) -> None:
        from subprocess import CompletedProcess

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "waypaper").mkdir()
            (root / "waypaper/config.ini").write_text(
                "[Settings]\nwallpaper = /old.png\nfill = fit\n"
            )
            response = CompletedProcess(
                ["awww", "query"],
                0,
                stdout=": eDP-1: 1440x900, scale: 2, currently displaying: image: /current.png\n",
            )
            with (
                patch.object(layout, "config_home", return_value=root),
                patch.object(layout.subprocess, "run", return_value=response),
            ):
                path, fill, _, scale = layout.wallpaper_source("eDP-1")
                self.assertEqual(path, Path("/current.png"))
                self.assertEqual(fill, "fill")
                self.assertEqual(scale, 2)

    def test_animated_wallpaper_uses_safe_fallback(self) -> None:
        with self.assertRaises(ValueError):
            layout.render_wallpaper(Path("animated.mp4"), (1440, 900), "fill", "black")
        self.assertEqual(layout.fallback(request())["backdropOpacity"], 1)


if __name__ == "__main__":
    unittest.main()
