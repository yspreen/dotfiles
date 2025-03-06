#!/bin/sh

# The $NAME variable is passed from sketchybar and holds the name of
# the item invoking this script:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

HOUR=$(date "+%-I")
WIDTH=66

case $HOUR in
1) WIDTH=66 ;;
2) WIDTH=66 ;;
3) WIDTH=66 ;;
4) WIDTH=66 ;;
5) WIDTH=66 ;;
6) WIDTH=66 ;;
7) WIDTH=66 ;;
8) WIDTH=66 ;;
9) WIDTH=66 ;;
10) WIDTH=74 ;;
11) WIDTH=74 ;;
12) WIDTH=74 ;;
*) WIDTH=74 ;;
esac

sketchybar --set "$NAME" label="$(date "+%-I:%M:%S")" width=$WIDTH
