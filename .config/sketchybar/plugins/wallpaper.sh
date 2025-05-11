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
bg() {
    # Store this process's PID
    MY_PID=$$

    # get screen resolution:
    MONITORS_HASH=$(aerospace list-monitors --json | md5)

    SHOULD_RUN_TWICE=0

    # check if monitors changed:
    if [ -f "$HOME/.monitors_hash" ]; then
        OLD_MONITORS_HASH=$(cat "$HOME/.monitors_hash")
        if [ "$MONITORS_HASH" != "$OLD_MONITORS_HASH" ]; then
            # Monitors changed, update the hash
            echo "$MONITORS_HASH" >"$HOME/.monitors_hash"

            SHOULD_RUN_TWICE=1
        fi
    else
        # First run, create the hash file
        echo "$MONITORS_HASH" >"$HOME/.monitors_hash"
    fi

    while true; do
        # If the binary is missing, build it
        if [ ! -f "${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper" ]; then
            "${PLUGIN_DIR}/clisolarwallpaper/build.sh"
        fi
        while [ ! -f "$HOME/.wallpaper.jpg" ]; do
            ts=$(${PLUGIN_DIR}/clisolarwallpaper/clisolarwallpaper.app/Contents/MacOS/clisolarwallpaper "$HOME/Library/Application Support/com.apple.mobileAssetDesktop/Solar Gradients.heic" "$HOME/.wallpaper.jpg")
            sleep 1
        done
        echo "Next change at $ts"

        # Sample color and blend with black
        COLOR=$(convert "$HOME/.wallpaper.jpg[1x1+3400+1500]" -format '%[hex:p{0,0}]' info:-)
        # Darken color by 10%
        R=$(printf "%02x" $((16#${COLOR:0:2} * 50 / 100)))
        G=$(printf "%02x" $((16#${COLOR:2:2} * 50 / 100)))
        B=$(printf "%02x" $((16#${COLOR:4:2} * 50 / 100)))
        DARKENED_COLOR="${R}${G}${B}"
        sleep 2
        while ! mint run yspreen/ChangeMenuBarColor SolidColor "$DARKENED_COLOR" "$HOME/.wallpaper.jpg"; do
            sleep 1
        done
        if [ "$SHOULD_RUN_TWICE" -eq 1 ]; then
            sleep 5

            # Run it again to ensure the color is set correctly
            mint run yspreen/ChangeMenuBarColor SolidColor "$DARKENED_COLOR" "$HOME/.wallpaper.jpg"
            SHOULD_RUN_TWICE=0
        fi
        sketchybar --bar color="0xff${DARKENED_COLOR}"

        while [ "$(date +%s)" -lt "$ts" ]; do
            sleep 2
        done
        echo TS passed: "$ts"

        # Check if we're still the active process
        if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE")" != "$MY_PID" ]; then
            # Another instance has taken over, exit this one
            exit 0
        fi
    done
}

bg >/tmp/wallpaper.log 2>&1 &

# Store the PID
echo $! >"$PID_FILE"

aerospace list-monitors --json | grep -Ei 'built.?in' && sketchybar --bar height=44 || sketchybar --bar height=28
