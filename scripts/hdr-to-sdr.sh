#!/usr/bin/env bash
# Convert HDR (PQ/BT.2020) video to SDR (BT.709) with proper tone mapping.
# Designed for macOS screen recordings and similar low-nit HDR content
# that looks gray/washed out when uploaded to YouTube or viewed on SDR displays.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: hdr-to-sdr <input_file> [output_file]"
  echo "  If no output file is given, appends .sdr before the extension."
  exit 1
fi

input="$1"

if [ ! -f "$input" ]; then
  echo "Error: file not found: $input"
  exit 1
fi

if [ $# -ge 2 ]; then
  output="$2"
else
  ext="${input##*.}"
  base="${input%.*}"
  output="${base}.sdr.${ext}"
fi

if [ -f "$output" ]; then
  echo "Error: output file already exists: $output"
  exit 1
fi

echo "Converting HDR → SDR: $(basename "$input")"

ffmpeg -i "$input" \
  -vf "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=mobius:param=0.01:desat=0:peak=1.0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p" \
  -c:v libx264 -crf 18 -preset slow -profile:v high \
  -c:a aac -b:a 256k \
  -movflags +faststart \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  "$output"

echo "Done: $output"
