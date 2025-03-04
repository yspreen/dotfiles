#!/bin/sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power' >/dev/null && echo 1 || echo 0)"

sketchybar --set "$NAME" label="$([ $CHARGING = 1 ] && echo "⚡ " || printf '')${PERCENTAGE}%"
