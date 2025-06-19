#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob # loop is harmless when no PSDs are present

for psd in *.psd *.PSD; do # match either case on macOS
    base="${psd%.*}"
    magick "${psd}[0]" \
        -auto-orient \
        -resize "2000x2000>" \
        -quality 80 \
        "${base}.jpg"
    echo "✔  $psd ➜ ${base}.jpg"
done
