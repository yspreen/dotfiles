---
name: hdr-to-sdr
description: Convert HDR video (iPhone HLG / Dolby Vision HEVC MOV) to proper SDR Rec.709 with Apple's tone mapping, keeping the best colors, rotation, audio and metadata. Use when footage looks washed out/blown out in CapCut, TikTok or other SDR tools, or when asked to make HDR files non-HDR. Optionally applies a grading LUT in the same encode.
---

# HDR -> SDR

Script: `to_sdr.sh <in> <out> [look.cube|-] [ffmpeg input args]`
- Tone maps with VideoToolbox `scale_vt` (same engine as Photos/iMovie), outputs HEVC Main10 Rec.709 (10-bit avoids
  banding in skies/gradients), copies all audio, Apple metadata and the rotation matrix, retries a busy encoder.
- With a LUT: grade (float RGB on the HLG signal) + tone map happen in ONE encode. Always prefer this over grading and
  converting in two passes (avoids double generation loss). Encode from the untouched original/backup.

## Method choice (tested side by side on iPhone 17 Pro HLG footage)
- Apple `scale_vt` / `avconvert`: natural skin, highlights keep detail, looks preserved. Use this.
- ffmpeg `zscale + tonemap=hable|mobius`: oversaturated flat cyan skies, blown faces. Avoid.
- `avconvert -p Preset3840x2160` gives the same Apple mapping but only 8-bit H.264. `Preset1920x1080` shrinks
  portrait video to fit a landscape box. Use only for quick checks.
- No libplacebo in the Homebrew ffmpeg build.

## Workflow
1. Back up originals (`cp -p` + `cmp`) unless backups exist.
2. Test 2-3 s of 2-3 clips, extract a frame, compare against the source, check
   `ffprobe ... color_transfer` = `bt709`, rotation kept.
3. Batch: `ls *_unadjusted.MOV | xargs -P 2 -n 1 <per-file script>`; per file encode to temp, verify duration and
   `bt709`, then `mv` over the original and `touch -r` the backup. Write done markers for idempotent reruns.

## Pitfalls
- `-hwaccel_output_format videotoolbox` is invalid in ffmpeg 9; this script avoids hw decode and uses
  `-init_hw_device videotoolbox=vt -filter_hw_device vt` + `hwupload` -> `scale_vt` -> `hwdownload,format=p010le`
  (hevc_videotoolbox will not take GPU frames from scale_vt directly).
- Tag the input frames as HLG BT.2020 with `setparams` before `hwupload`, or scale_vt will not tone map.
- More than ~2 parallel VideoToolbox sessions fail with -12903. Never use zsh `jobs -r` throttling (broken in scripts).
- OneDrive "dataless" files time out on read; check `ls -lO` first.
- For TikTok uploads export H.264/HEVC SDR Rec.709 from the editor; TikTok's own HDR handling is inconsistent.
