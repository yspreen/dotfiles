#!/bin/zsh
# deps: brew install imagemagick exiftool
SRC_ICC="/System/Library/ColorSync/Profiles/ITU-2020.icc"
DST_ICC="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
mkdir -p sdr

for f in *.png; do
  # 1️⃣ get the literal XMP orientation string
  xmp=$(exiftool -s -s -s -XMP-tiff:Orientation "$f")
  case "$xmp" in
  "Rotate 90 CW") deg=90 ;;
  "Rotate 270 CW") deg=270 ;;
  "Rotate 180") deg=180 ;;
  *) deg=0 ;; # Horizontal / undefined
  esac

  tmp="${TMPDIR}$(basename "$f" .png)_rot.png"
  out="sdr/$(basename "$f" .png)_sdr.png"

  # 2️⃣ rotate pixels, tag BT.2020   → perceptual gamut-map   → embed sRGB
  magick "$f" -rotate "$deg" \
    -profile "$SRC_ICC" \
    -intent perceptual \
    -profile "$DST_ICC" \
    -strip \
    "$out"

  # 3️⃣ blank the orientation tag so nothing re-rotates (no “Permanent” warning)
  exiftool -overwrite_original -XMP-tiff:Orientation="Horizontal (normal)" "$out" >/dev/null
done
