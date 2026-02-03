#!/usr/bin/env bash

STATE_FILE="/tmp/focus_mode_state"
BLACK_WALLPAPER="/home/rupan/nixos/modules/home-manager/assets/wallpapers/black.png"
KITTY_CONFIG_DIR="/home/rupan/nixos/modules/home-manager/configs/kitty"
KITTY_COLORS="$KITTY_CONFIG_DIR/colors.conf"
KITTY_THEME_NORMAL="$KITTY_CONFIG_DIR/themes/noctalia.conf"
KITTY_THEME_FOCUS="$KITTY_CONFIG_DIR/themes/focus.conf"
NOCTALIA_SETTINGS="$HOME/.config/noctalia/settings.json"

if [ ! -f "$BLACK_WALLPAPER" ]; then
  convert -size 1920x1080 xc:black "$BLACK_WALLPAPER" 2>/dev/null || \
  echo "convert not found, creating dummy file" && touch "$BLACK_WALLPAPER"
fi

toggle_focus() {
  if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
    noctalia-shell ipc call wallpaper enableAutomation
    noctalia-shell ipc call wallpaper random
    if command -v jq &> /dev/null; then
        tmp=$(mktemp)
        jq '.colorSchemes.useWallpaperColors = true' "$NOCTALIA_SETTINGS" > "$tmp" && mv "$tmp" "$NOCTALIA_SETTINGS"
    fi
    cp "$KITTY_THEME_NORMAL" "$KITTY_COLORS"
    for pid in $(pgrep kitty); do kill -SIGUSR1 $pid 2>/dev/null; done

    notify-send "Focus Mode" "Disabled"
  else
    touch "$STATE_FILE"
    noctalia-shell ipc call wallpaper disableAutomation
    if command -v jq &> /dev/null; then
        tmp=$(mktemp)
        jq '.colorSchemes.useWallpaperColors = false | .colorSchemes.predefinedScheme = "Focus"' "$NOCTALIA_SETTINGS" > "$tmp" && mv "$tmp" "$NOCTALIA_SETTINGS"
    fi
    noctalia-shell ipc call colorScheme set "Focus"
    if command -v jq &> /dev/null && command -v niri &> /dev/null; then
        OUTPUTS=$(niri msg -j outputs | jq -r 'keys[]')
        for screen in $OUTPUTS; do
            noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "$screen"
        done
    else
        noctalia-shell ipc call wallpaper set "$BLACK_WALLPAPER" "eDP-1"
    fi
    cp "$KITTY_THEME_FOCUS" "$KITTY_COLORS"
    for pid in $(pgrep kitty); do kill -SIGUSR1 $pid 2>/dev/null; done

    notify-send "Focus Mode" "Enabled"
  fi
}

toggle_focus
