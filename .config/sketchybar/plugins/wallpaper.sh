#!/bin/bash

PID_FILE="$HOME/.menu_bar_color_pid"

# check if mint is installed:
if ! command -v mint &>/dev/null; then
    brew install mint
fi

# Kill existing process if running
if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null || true
    rm "$PID_FILE"
fi

PLUGIN_DIR="$1"

if [ "$SENDER" == "system_will_sleep" ]; then
    exit 0
fi

# Start the background process
(
    while true; do
        # If the binary is missing, build it
        if [ ! -f "${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper" ]; then
            "${PLUGIN_DIR}/clisolarwallpaper/build.sh"
        fi
        ${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper "$HOME/Library/Application Support/com.apple.mobileAssetDesktop/The Desert.heic" "$HOME/.wallpaper.jpg"

        # Sample color and blend with black
        COLOR=$(convert "$HOME/.wallpaper.jpg[1x1+3400+1500]" -format '%[hex:p{0,0}]' info:-)
        # Darken color by 10%
        R=$(printf "%02x" $((16#${COLOR:0:2} * 50 / 100)))
        G=$(printf "%02x" $((16#${COLOR:2:2} * 50 / 100)))
        B=$(printf "%02x" $((16#${COLOR:4:2} * 50 / 100)))
        DARKENED_COLOR="${R}${G}${B}"
        mint run yspreen/ChangeMenuBarColor SolidColor "$DARKENED_COLOR" "$HOME/.wallpaper.jpg"
        sketchybar --bar color="0xff${DARKENED_COLOR}"

        sleep 450 # 7.5 minutes
    done
) &

aerospace list-monitors --json | grep -Ei 'built.?in' && sketchybar --bar height=44 || sketchybar --bar height=28

# Store the PID
echo $! >"$PID_FILE"
