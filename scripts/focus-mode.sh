#!/usr/bin/env bash

STATE_FILE="/tmp/focus_mode_state"
BLACK_WALLPAPER="/home/rupan/nixos/modules/home-manager/assets/wallpapers/black.png"
KITTY_CONFIG_DIR="/home/rupan/nixos/modules/home-manager/configs/kitty"
KITTY_COLORS="$KITTY_CONFIG_DIR/colors.conf"
KITTY_THEME_NORMAL="$KITTY_CONFIG_DIR/themes/noctalia.conf"
KITTY_THEME_FOCUS="$KITTY_CONFIG_DIR/themes/focus.conf"
FISH_THEME_FOCUS="/home/rupan/nixos/modules/home-manager/configs/fish/focus.fish"
STARSHIP_THEME_FOCUS="/home/rupan/nixos/modules/home-manager/configs/starship/focus.toml"
FISH_THEME_OUTPUT="$HOME/.config/fish/conf.d/matugen_theme.fish"
STARSHIP_THEME_OUTPUT="$HOME/.config/starship_matugen.toml"
FISH_THEME_BACKUP="/tmp/focus_mode_fish_backup"
STARSHIP_THEME_BACKUP="/tmp/focus_mode_starship_backup"
NOCTALIA_SETTINGS="$HOME/.config/noctalia/settings.json"

apply_focus_shell_themes() {
  if [ -f "$FISH_THEME_FOCUS" ]; then
    mkdir -p "$(dirname "$FISH_THEME_OUTPUT")"
    if [ -f "$FISH_THEME_OUTPUT" ]; then
      cp "$FISH_THEME_OUTPUT" "$FISH_THEME_BACKUP"
    fi
    cp "$FISH_THEME_FOCUS" "$FISH_THEME_OUTPUT"
  fi

  if [ -f "$STARSHIP_THEME_FOCUS" ]; then
    mkdir -p "$(dirname "$STARSHIP_THEME_OUTPUT")"
    if [ -f "$STARSHIP_THEME_OUTPUT" ]; then
      cp "$STARSHIP_THEME_OUTPUT" "$STARSHIP_THEME_BACKUP"
    fi
    cp "$STARSHIP_THEME_FOCUS" "$STARSHIP_THEME_OUTPUT"
  fi
}

restore_shell_themes() {
  if [ -f "$FISH_THEME_BACKUP" ]; then
    mkdir -p "$(dirname "$FISH_THEME_OUTPUT")"
    cp "$FISH_THEME_BACKUP" "$FISH_THEME_OUTPUT"
    rm -f "$FISH_THEME_BACKUP"
  fi

  if [ -f "$STARSHIP_THEME_BACKUP" ]; then
    mkdir -p "$(dirname "$STARSHIP_THEME_OUTPUT")"
    cp "$STARSHIP_THEME_BACKUP" "$STARSHIP_THEME_OUTPUT"
    rm -f "$STARSHIP_THEME_BACKUP"
  fi
}

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
    noctalia-shell ipc call colorScheme set "Peche"
    restore_shell_themes
    notify-send "Focus Mode" "Disabled"
  else
    touch "$STATE_FILE"
    noctalia-shell ipc call wallpaper disableAutomation
    if command -v jq &> /dev/null; then
        tmp=$(mktemp)
        jq '.colorSchemes.useWallpaperColors = false | .colorSchemes.predefinedScheme = "Focus"' "$NOCTALIA_SETTINGS" > "$tmp" && mv "$tmp" "$NOCTALIA_SETTINGS"
    fi
    noctalia-shell ipc call colorScheme set "Focus"
    noctalia-shell ipc call powerProfile toggleNoctaliaPerformance
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
    apply_focus_shell_themes
    notify-send "Focus Mode" "Enabled"
  fi
}

toggle_focus
