#!/bin/bash

if [ "$FOCUSED_WORKSPACE" = "D" ]; then
    sketchybar --set $NAME icon=󰏬 \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
elif [ "$FOCUSED_WORKSPACE" = "A" ]; then
    sketchybar --set $NAME icon=󰾔 \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
elif [ "$FOCUSED_WORKSPACE" = "C" ]; then
    sketchybar --set $NAME icon=󱃖 \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
elif [ "$FOCUSED_WORKSPACE" = "X" ]; then
    sketchybar --set $NAME icon= \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=1
elif [ "$FOCUSED_WORKSPACE" = "E" ]; then
    sketchybar --set $NAME icon=󰴃 \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
elif [ "$FOCUSED_WORKSPACE" = "F" ]; then
    sketchybar --set $NAME icon= \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
elif [ "$FOCUSED_WORKSPACE" = "G" ]; then
    sketchybar --set $NAME icon= \
        icon.font="FiraCode Nerd Font:Regular:16.0" \
        icon.padding_right=0
elif [ "$FOCUSED_WORKSPACE" = "W" ]; then
    sketchybar --set $NAME icon= \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=1
elif [ "$FOCUSED_WORKSPACE" = "V" ]; then
    sketchybar --set $NAME icon=󰋌 \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
else
    sketchybar --set $NAME icon=󱢍 \
        icon.font="FiraCode Nerd Font:Regular:18.0" \
        icon.padding_right=2
fi
