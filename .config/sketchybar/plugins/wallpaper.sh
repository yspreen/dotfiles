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

rm "$HOME/.wallpaper.jpg"

# Start the background process
(
    # Store this process's PID
    MY_PID=$$

    while true; do
        # Check if we're still the active process
        if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE")" != "$MY_PID" ]; then
            # Another instance has taken over, exit this one
            exit 0
        fi

        # If the binary is missing, build it
        if [ ! -f "${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper" ]; then
            "${PLUGIN_DIR}/clisolarwallpaper/build.sh"
        fi
        ${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper "$HOME/Library/Application Support/com.apple.mobileAssetDesktop/Solar Gradients.heic" "$HOME/.wallpaper.new.jpg"

        if ! diff "$HOME/.wallpaper.new.jpg" "$HOME/.wallpaper.jpg"; then
            mv "$HOME/.wallpaper.new.jpg" "$HOME/.wallpaper.jpg"
        else
            # unchanged
            rm "$HOME/.wallpaper.new.jpg"

            sleep 450 # 7.5 minutes
            continue
        fi

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

# Store the PID
echo $! >"$PID_FILE"

aerospace list-monitors --json | grep -Ei 'built.?in' && sketchybar --bar height=44 || sketchybar --bar height=28
