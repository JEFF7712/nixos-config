import subprocess
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFont

from src.backend.PluginManager.ActionBase import ActionBase

SIZE = 256
COLORS = {
    "claude": (217, 119, 87, 255),
    "codex": (59, 130, 246, 255),
}
TRACK = (55, 55, 60, 255)
LABEL = (200, 200, 205, 255)
REDRAW_EVERY = 10


@lru_cache(maxsize=None)
def font(size: int):
    try:
        path = subprocess.run(
            ["fc-match", "-f", "%{file}", "Inter:bold"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default(size=size)


def render(source: str, window: str, used: float | None) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)
    draw.text((18, 12), window, font=font(46), fill=LABEL)

    x0, x1 = 18, SIZE - 18
    y0, y1 = 120, 200
    radius = 18
    draw.rounded_rectangle((x0, y0, x1, y1), radius=radius, fill=TRACK)
    remaining = None if used is None else 100 - used
    if remaining is None:
        draw.text(
            (SIZE // 2, (y0 + y1) // 2),
            "?",
            anchor="mm",
            font=font(46),
            fill=LABEL,
        )
    if remaining is not None and remaining > 0:
        width = max(2 * radius, round((x1 - x0) * remaining / 100))
        draw.rounded_rectangle(
            (x0, y0, x0 + width, y1), radius=radius, fill=COLORS[source]
        )
    return img


class UsageBar(ActionBase):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._drawn = None
        self._ticks = 0

    def _target(self) -> tuple[str, str]:
        settings = self.get_settings()
        return settings.get("source", "claude"), settings.get("window", "5h")

    def on_ready(self):
        self.plugin_base.usage.start()
        self._drawn = None
        self._draw()

    def on_tick(self):
        self._ticks += 1
        if (
            self._drawn != self.plugin_base.usage.version
            or self._ticks % REDRAW_EVERY == 0
        ):
            self._draw()

    def on_key_down(self):
        self.plugin_base.usage.refresh()

    def _draw(self):
        source, window = self._target()
        data = self.plugin_base.usage.get(source, window)
        self._drawn = self.plugin_base.usage.version
        self.set_media(
            image=render(source, window, data.used_now() if data else None), size=1.0
        )
