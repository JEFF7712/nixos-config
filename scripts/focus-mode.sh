#!/usr/bin/env bash

STATE_FILE="/tmp/focus_mode_state"
BLACK_WALLPAPER="/tmp/black_1x1.png"

# Ensure simple black wallpaper exists
if [ ! -f "$BLACK_WALLPAPER" ]; then
  convert -size 1x1 xc:black "$BLACK_WALLPAPER" 2>/dev/null || \
  echo "convert not found, creating dummy file" && touch "$BLACK_WALLPAPER"
  # Fallback generation if imagemagick isn't present, though it likely is or won't be critical if niri handles colors
fi

toggle_focus() {
  if [ -f "$STATE_FILE" ]; then
    # Disable Focus Mode
    rm "$STATE_FILE"
    noctalia-shell ipc call wallpaper random
    noctalia-shell ipc call colorScheme set "Ayu" # Default fallback
    notify-send "Focus Mode" "Disabled"
  else
    # Enable Focus Mode
    touch "$STATE_FILE"
     # Disable wallpaper automation to prevent random switching
    noctalia-shell ipc call wallpaper disableAutomation
    # Set wallpaper to black - assuming we can set by path or just rely on color
    # The config shows fillColor is black, so maybe just disabling wallpaper shows background?
    # Let's try setting a specific image first.
    noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "eDP-1" 
    noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "Dell Inc. D3218HN X9R5K82N1SRE"
    noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "Samsung Electric Company LS24D300G H1AK500000"
    
    noctalia-shell ipc call colorScheme set "Material"
    notify-send "Focus Mode" "Enabled"
  fi
}

toggle_focus
