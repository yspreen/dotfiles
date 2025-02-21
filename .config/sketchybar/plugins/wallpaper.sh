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
        ${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper "/Users/user/Library/Application Support/com.apple.mobileAssetDesktop/The Desert.heic" "$HOME/.wallpaper.jpg"
        mint run igorkulman/ChangeMenuBarColor SolidColor "000000" "$HOME/.wallpaper.jpg"
        sleep 450 # 7.5 minutes
    done
) &

# Store the PID
echo $! >"$PID_FILE"
