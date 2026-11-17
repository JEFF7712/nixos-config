# Wallpaper-aware idle workspace

The Quickshell idle greeting evaluates a wide layout and a compact column against
the wallpaper on each monitor. It scores visual detail, luminance and saturation,
text contrast, screen margins and optional exclusions. The compact layout fits
beside central artwork. Automatic placement requires a clearly quiet region;
otherwise the greeting uses the centered wide layout when it fits. A uniform
wallpaper also retains the centered layout. The widgets are drawn directly over
the wallpaper without a background panel. Explicit placement preferences and
exclusions remain available.

`services/WallpaperLayout.qml` runs `services/internal/wallpaper_layout.py` with
the existing `iris-python` environment. Analysis uses a thumbnail with a maximum
dimension of 320 pixels. Text and accent colors are adjusted when necessary for
contrast. Placement and color analysis do not add a visible backdrop.

The current source comes from `awww query`, with Waypaper configuration as the
fallback. Fill, fit, stretch, center and tile modes follow Waypaper's setting.
Results are cached per output under `$XDG_CACHE_HOME/quickshell/idle-layout/`.
The cache key includes the source path, modification time, image size, monitor
geometry, widget footprint, colors and overrides. There is no periodic analysis.
Configuration changes and idle entry trigger a refresh; direct external wallpaper
commands are picked up on the next idle entry. Superseded results are discarded.
Initial and hidden placement updates snap before reveal, while wallpaper changes
while the greeting is visible smoothly animate position, layout, scale and color.

This is visual-detail analysis, without semantic face or object recognition.
Animated wallpapers, missing images and analyzer failures use a centered layout.

## Optional per-wallpaper placement

Create `~/.config/desktop-profiles/idle-layout.json` with an absolute wallpaper
path or basename as the key. `prefer` accepts `auto`, `left`, `right`, `top`,
`bottom` or `center`. `avoid` contains rectangles `[x, y, width, height]`, normalized
to the visible monitor after wallpaper cropping. Changes are watched live.

```json
{
  "fis.png": {
    "prefer": "left",
    "avoid": [[0.35, 0.1, 0.3, 0.8]]
  }
}
```

The default works without this file. Preferences bias placement; exclusions
strongly penalize overlap but do not make an impossible layout disappear.

## Validation

```sh
bash tests/quickshell/run-wallpaper-layout.bash
just check-changed
just eval laptop
```

The image tests cover quiet regions, bright and busy images, small highlights,
light themes, monitor crops, small screens, exclusions and cache invalidation.
The integration fixture checks stale-process results, malformed output fallback
and the absence of repeated work after settling.

Related work: [Verseglade](https://github.com/VasiHemanth/verseglade) uses quiet-region
and contrast scoring for text rendered into wallpapers. This implementation is
written for live widgets and does not vendor that project's code.
