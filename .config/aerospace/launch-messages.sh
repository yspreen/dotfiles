#!/bin/bash

if ! [ "$(aerospace list-workspaces --focused)" == "E" ]; then
    aerospace workspace E
    if [ "$(aerospace list-windows --workspace E | wc -l)" -gt "0" ]; then
        exit 0
    fi
fi

# Check if Messages.app is running (using the actual app window/UI process)
messages_running=false
if osascript -e 'tell application "System Events" to (name of processes) contains "Messages"' | grep -q "true"; then
    echo "Messages.app is already running"
    messages_running=true
else
    echo "Messages.app is not running"
fi

# Check if WhatsApp.app is running
whatsapp_running=false
if osascript -e 'tell application "System Events" to (name of processes) contains "WhatsApp"' | grep -q "true"; then
    echo "WhatsApp.app is already running"
    whatsapp_running=true
else
    echo "WhatsApp.app is not running"
fi

# Check if Telegram.app is running
telegram_running=false
if osascript -e 'tell application "System Events" to (name of processes) contains "Telegram"' | grep -q "true"; then
    echo "Telegram.app is already running"
    telegram_running=true
else
    echo "Telegram.app is not running"
fi

# If neither Messages nor WhatsApp are running, kill Telegram and launch Messages
if [ "$messages_running" = false ] && [ "$whatsapp_running" = false ]; then
    echo "Neither Messages nor WhatsApp are running"

    # Kill Telegram if it's running
    if [ "$telegram_running" = true ]; then
        echo "Killing Telegram"
        osascript -e 'quit app "Telegram"' &
    fi

    # Launch Messages
    echo "Launching Messages"
    open -a Messages
    exit 0
fi

# If Messages is running but WhatsApp isn't, kill Telegram and Messages, then launch WhatsApp
if [ "$messages_running" = true ]; then
    echo "Messages is running but WhatsApp isn't"

    # Kill Telegram if it's running
    if [ "$telegram_running" = true ]; then
        echo "Killing Telegram"
        osascript -e 'quit app "Telegram"' &
    fi

    # Kill Messages
    echo "Killing Messages"
    osascript -e 'quit app "Messages"' &

    # Launch WhatsApp
    echo "Launching WhatsApp"
    open -a WhatsApp
    exit 0
fi

# Third case: If WhatsApp is running or both are running, kill both and launch Telegram
if [ "$whatsapp_running" = true ]; then
    echo "WhatsApp is running - switching to Telegram"

    # Kill Messages if it's running
    if [ "$messages_running" = true ]; then
        echo "Killing Messages"
        osascript -e 'quit app "Messages"' &
    fi

    # Kill WhatsApp
    echo "Killing WhatsApp"
    ps -A | grep -i whatsapp.app | grep -v grep | while read pid; do kill $pid; done &

    # Launch Telegram if not already running, otherwise bring to front
    if [ "$telegram_running" = false ]; then
        echo "Launching Telegram"
        open -a Telegram
    else
        echo "Bringing Telegram to front"
        osascript -e 'tell application "Telegram" to activate'
    fi
    exit 0
fi
