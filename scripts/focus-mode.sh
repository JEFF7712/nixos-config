#!/usr/bin/env bash

STATE_FILE="/tmp/focus_mode_state"
BLACK_WALLPAPER="/home/rupan/nixos/modules/home-manager/assets/wallpapers/black.png"

# Ensure black wallpaper exists
if [ ! -f "$BLACK_WALLPAPER" ]; then
  convert -size 1920x1080 xc:black "$BLACK_WALLPAPER" 2>/dev/null || \
  echo "convert not found, creating dummy file" && touch "$BLACK_WALLPAPER"
fi

toggle_focus() {
  if [ -f "$STATE_FILE" ]; then
    # Disable Focus Mode
    rm "$STATE_FILE"
    
    # 1. Re-enable automation first so random picking works if configured
    noctalia-shell ipc call wallpaper enableAutomation
    
    # 2. Pick a random wallpaper
    # This should trigger noctalia to extract colors and update all templates (kitty, thunar, etc.)
    noctalia-shell ipc call wallpaper random
    
    # Removed explicit color scheme setting to let it restore to standard wallpaper-based colors
    
    notify-send "Focus Mode" "Disabled"
  else
    # Enable Focus Mode
    touch "$STATE_FILE"
    
     # Disable wallpaper automation to prevent random switching
    noctalia-shell ipc call wallpaper disableAutomation
    
    # Set wallpaper to black
    # This should trigger noctalia to extract colors (black/dark) and update all templates
    noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "eDP-1" 
    noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "Dell Inc. D3218HN X9R5K82N1SRE"
    noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "Samsung Electric Company LS24D300G H1AK500000"
    
    notify-send "Focus Mode" "Enabled"
  fi
}

toggle_focus
