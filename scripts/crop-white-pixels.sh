#!/usr/bin/env bash
# crop-pastes.sh
# Crop all ~/Downloads/paste.*.png to the bounding box of their white pixels.
# Requirements: nix-shell (installed) + ImageMagick (pulled on‑demand)

set -euo pipefail

DIR="$HOME/Downloads"

# One nix‑shell invocation for all files (faster than spawning per‑file)
nix-shell -p imagemagick --run '
  shopt -s nullglob              # Don’t treat globs that match nothing as literals
  for img in "'"$DIR"'/paste."*".png"; do
    [ -e "$img" ] || continue    # Skip if the glob found nothing
    echo "Cropping $(basename "$img")"

    #   • -alpha off       : ignore any existing alpha when detecting white
    #   • -fuzz 2%         : treat near‑white (anti‑aliased) pixels as white
    #   • -trim +repage    : trim to the bounding box of non‑white pixels,
    #                        then reset canvas information
    # This works because the icon itself is pure white (or near white) and the
    # area we want to discard is everything else (transparent or non‑white).
    magick "$img" \
           -alpha off -fuzz 2% -fill black +opaque "#FFFFFF" \
           -fill white -opaque "#FFFFFF" \
           -trim +repage "$img"
  done
'
