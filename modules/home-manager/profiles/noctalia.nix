# Noctalia desktop profile.
# Colors are all null — noctalia-shell manages them dynamically at runtime.
# Only niri settings, cursor, bar, and wallpaperDir are meaningful here.
{ config, ... }:

{
  desktopProfiles.profiles.noctalia = {
    bar = "noctalia";

    cursor = {
      theme = "Adwaita";
      size = 28;
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/noctalia";

    niri = {
      gaps = 5;
      focusRingOff = true;
      borderOff = true;
      borderWidth = 1;
      borderActiveColor = "rgba(220,220,220,0.9)";
      borderInactiveColor = "rgba(20,20,20,0.8)";
      urgentColor = "#ffb4ab";
      shadowSoftness = 30;
      shadowSpread = 5;
      shadowOffsetX = 0;
      shadowOffsetY = 5;
      shadowColor = "#00000070";
      shadowInactiveColor = "#00000054";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = true;
      windowOpacity = 0.8;
    };

    colors = {
      gtk3 = null;
      gtk4 = null;
      qt6 = null;
      kitty = null;
      fish = null;
      starship = null;
    };
  };
}
