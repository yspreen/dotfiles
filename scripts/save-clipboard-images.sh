#!/usr/bin/env bash
# save-clipboard-images.sh
# Requires: pngpaste  (brew install pngpaste)

out_dir="$HOME/Downloads"
mkdir -p "$out_dir"

# Start counter after the highest existing paste.*.png
n=$(printf '%d' "$(ls "$out_dir"/paste.*.png 2>/dev/null | wc -l)")  
((n++))

prev_hash=""

while true; do
    # If clipboard currently holds PNG data …
    if pngpaste - >/dev/null 2>&1; then
        # Hash the PNG bytes to detect changes
        hash=$(pngpaste - | shasum | awk '{print $1}')
        if [[ $hash != "$prev_hash" ]]; then
            pngpaste "$out_dir/paste.$n.png"
            echo "Saved: $out_dir/paste.$n.png"
            prev_hash="$hash"
            ((n++))
        fi
    fi
    sleep 0.5   # adjust polling interval if desired
done
