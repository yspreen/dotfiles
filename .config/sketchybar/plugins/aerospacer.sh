#!/bin/bash

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    if [ -f ~/.aerospaceservice ]; then
        bg_color=0x62EA2B58 # Color for service mode
    else
        bg_color=0x3640ffff # Color for main mode
    fi
    sketchybar --set $NAME background.drawing=on background.color=$bg_color
else
    sketchybar --set $NAME background.drawing=off
fi
