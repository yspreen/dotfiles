#!/bin/sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power' >/dev/null && echo 1 || echo 0)"

sketchybar --set "$NAME" y_offset=$([ $CHARGING = 1 ] && printf '2' || printf '0.5') label="$([ $CHARGING = 1 ] && echo "⚡ " || printf '')${PERCENTAGE}%"
