#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash imagemagick

# rotate-pngs.sh — bake orientation into pixels for every *.png in the cwd
# Usage:  ./rotate-pngs.sh
# Notes:
#   • Requires no global installs; nix-shell pulls bash & ImageMagick.
#   • Orientation is auto-detected; if none is present, the file is still
#     re-saved with the Orientation tag removed (+set orientation).

set -euo pipefail

for f in *.png; do
    [[ -e "$f" ]] || continue # skip if no PNGs match
    # Read the current orientation (returns "Undefined" if none)
    orientation=$(identify -quiet -format '%[orientation]' "$f" 2>/dev/null || true)

    # Create a secure temp file (portable between GNU/BSD mktemp flavours)
    tmp=$(mktemp "${TMPDIR:-/tmp}/rot_png.XXXXXXXXXX").png

    if [[ "$orientation" == "Undefined" || "$orientation" == "TopLeft" ]]; then
        # No rotation needed—just strip the tag so it won’t exist anymore
        magick "$f" +set orientation "$tmp"
    else
        # Rotate pixels to match metadata, then wipe the tag
        magick "$f" -auto-orient +set orientation "$tmp"
    fi

    # Atomically replace the original
    mv -f -- "$tmp" "$f"
    echo "✓ Processed $f (orientation was: ${orientation:-none})"
done
