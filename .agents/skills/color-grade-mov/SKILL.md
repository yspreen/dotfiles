---
name: color-grade-mov
description: Color grade iPhone MOV/HEVC (HLG HDR) footage with 3D LUTs while keeping HDR, rotation, audio and metadata. Use when asked to color grade, apply a look/LUT, copy CapCut color-wheel values, or build a Tokyo/NeoTokyo/film look for video files. For HDR-to-SDR conversion use the hdr-to-sdr skill (it can grade in the same encode).
---

# Color grade MOV files

Scripts in this folder:
- `make_looks.py <outdir>`: builds 65^3 `.cube` LUTs. Contains reusable building blocks
  (`primaries` lift/gamma/gain/offset, `tones` contrast/brilliance/highlights/shadows/whites/blacks/tint,
  `hsl` CapCut-style 8-band HSL in +-100 units, `curves` midpoint curves on 0-255, `skin_mask`)
  and three looks: `night` (NeoTokyo 90%, no faces), `day` (skin-safe daylight: teal shadows only, green/yellow/cyan pop,
  skin hues untouched), `omoide` (warm orange skin + contrast).
  Edit `LOOKS` to add looks: `name: (fn, strength, skin_protect, highlight_protect)`.
- `grade.sh <in> <out> <look.cube> [ffmpeg input args]`: one file, HDR kept (10-bit HLG BT.2020).

Run python with numpy via `uvx -q --with numpy python -I make_looks.py <dir>` (set UV_CACHE_DIR etc. to a scratch dir).

## Workflow
1. Probe sources: `ffprobe -show_entries stream=pix_fmt,color_transfer,color_primaries:stream_side_data=rotation`.
   iPhone = HEVC Main10, `arib-std-b67` (HLG), BT.2020, Dolby Vision 8.4, B-roll often `rotation=-90`.
2. Turn the user's values into a look in `make_looks.py`. Read screenshots by measuring pixels (arc sliders = small
   offsets; calibrate on a value the user states). Read video tutorials without speech by OCR of frames (macOS Vision
   via pyobjc-framework-Vision), 4 fps, keep the last value of each drag.
3. Back up first: `cp -p IMG_x.MOV IMG_x_unadjusted.MOV && cmp` before touching originals. Always encode FROM the
   backup so re-grades never stack.
4. Preview before batch: render the same frame before/after per location
   (`ffmpeg -ss T -i backup -frames:v 1 -vf "<grade chain>,scale=-2:560"`), hstack, look at it. Check skin and blacks.
5. Batch with real throttling: `ls *_unadjusted.MOV | xargs -P 2 -n 1 <per-file script>`. Per file: encode to temp,
   verify duration (+-0.1 s) and color tags, `mv` over original, `touch -r backup original`, write a done marker
   so reruns are idempotent.

## Look guidance (from research, see Tokyo writeup)
- Grade per location, not one look for all. Correct exposure/WB first, then apply the look.
- Keep gain light (big gain R = pink highlights). Don't crush blacks with negative offset; use an S-curve.
- Tokyo reads as: neon red/magenta/cyan, teal shadows + warm highlights (Fuji Classic Negative), green
  fluorescent cast kept, lifted blacks by day, dense blacks at night. Protect skin (hue ~3-47 deg) from teal looks.
- Judge the final look in SDR (after hdr-to-sdr), not on the HDR signal: teal reads stronger in SDR.

## Pitfalls
- Skin protection backfires under hard top light: `skin_mask` only catches saturated skin, so the nose stays orange
  while the rest of the face goes teal. The user likes a uniformly teal face; use protect=0 there (station look).
- Missing raw? Pull from the iPhone over USB with ImageCaptureCore (Photos export stalls on iCloud-optimized originals).
- zsh scripts: `jobs -r` does not work non-interactively, so `while jobs -r ...` throttling launches EVERYTHING at
  once (fills disk, VideoToolbox "-12903 encoder busy"). Use `xargs -P`.
- In zsh, quote `'0:a?'` (glob). Use `-noautorotate` so the rotation display matrix is copied, not baked in.
- `lut3d` needs RGB: convert with `in_color_matrix=bt2020` explicitly, else ffmpeg uses BT.601.
- Apple `mebx` metadata tracks and the Dolby Vision RPU are dropped (stale after grading anyway). AAC + APAC audio copy fine.
- OneDrive can evict files ("compressed,dataless"); reads then time out. Check `ls -lO`, keep files local.
- Sandboxed CapCut cannot read OneDrive paths until linked via its own dialog; never move footage out of OneDrive
  if the user wants it there.
