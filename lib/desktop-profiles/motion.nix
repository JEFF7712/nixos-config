# Wallpaper / lock / OSD / launcher timings, named like niri-animations.nix.
# wallpaperDuration is seconds for `awww img --transition-duration`.
# hyprlockFade/Dots are hyprlock speed steps (1 = 100ms).
{
  default = {
    wallpaperType = "fade";
    wallpaperDuration = 1.0;
    hyprlockFade = 4;
    hyprlockDots = 2;
    osdMs = 120;
    launcherFadeMs = 140;
  };

  snappy = {
    wallpaperType = "fade";
    wallpaperDuration = 0.35;
    hyprlockFade = 2;
    hyprlockDots = 1;
    osdMs = 70;
    launcherFadeMs = 90;
  };

  glide = {
    wallpaperType = "fade";
    wallpaperDuration = 0.7;
    hyprlockFade = 3;
    hyprlockDots = 2;
    osdMs = 140;
    launcherFadeMs = 140;
  };

  soft = {
    wallpaperType = "fade";
    wallpaperDuration = 1.4;
    hyprlockFade = 5;
    hyprlockDots = 2;
    osdMs = 220;
    launcherFadeMs = 200;
  };
}
