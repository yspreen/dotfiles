---
name: subtitles
description: Get high-quality English subtitles for movies or TV episodes, strip ad/credit lines ("subtitles by", "www.", addic7ed...), and fix misalignment by transcribing three 1-minute samples. Use when asked for subtitles, to fix out-of-sync subs, or to clean subtitle ads, for one file or a whole library (Jellyfin/Plex sidecars).
---

**Needs:** `ffmpeg`, `uv`, Superwhisper model at `$HOME/Library/Application Support/superwhisper/ggml-medium.bin` (all installed). If the model is missing, stop and tell the user.

## Sync rule: never transcribe the whole video

Alignment transcribes **three 1-minute windows at ~10%, ~50% and ~80%** of the runtime. Nothing else.
- 10% skips the cold open, recap and title sequence. The first minutes are often music or silence and match nothing.
- 80% stays clear of end credits.
- 50% catches drift and cut differences between the two.
- Self-healing: a window with fewer than 30 spoken words (silence, music, montage, action scene) is retried at nearby marks: +5%, -5%, +10%, -10%, +15% of the runtime, clamped to 3–88%. The first window with speech wins. Windows stay 1 minute, so the worst case is about 6 minutes per mark.
- A window that has speech but no candidate matches it (foreign-language scene, a scene missing from that cut) is skipped. A sync needs at least 2 matching windows.
- Three minutes of audio is enough to measure a shift and a linear drift. Transcribing a full episode or movie just to fix timestamps wastes 20 to 60 minutes per file. Don't do it, even as a fallback.

## Run

```sh
SK=~/.claude/skills/subtitles
M="$HOME/Library/Application Support/superwhisper/ggml-medium.bin"
C=$TMPDIR/subs-cache   # transcripts, candidate subs, backups of replaced srt; reruns reuse it
W=$HOME/.local/share/whisper-uv   # shared Python env, persistent (see below)
export UV_CACHE_DIR=$W/uv UV_PYTHON_INSTALL_DIR=$W/py UV_TOOL_DIR=$W/tools
uvx -q --from subliminal --with pywhispercpp python $SK/subs.py "$M" "$C" VIDEO... > results.jsonl 2> err.log
```

- Pass many videos in one call (model loads once). For a library, use `find ... -print0 | xargs -0` and `run_in_background`. Roughly 1 min per file.
- Output per video: `<video base>.en.srt` (best non-HI) and `<video base>.en.sdh.srt` (best HI, if it is close in quality). These names are what Jellyfin/Plex pick up. An existing `<base>.srt` is backed up to the cache and replaced.
- Each JSON line has `src`, quality `q` (share of subtitle words matched) and `shifts_ms` (offset found at each window before the fix), or an `error`.

## Production use

`~/Documents/proj/media/subs/worker.py` runs this `subs.py` automatically after every Unmanic encode (cache `data/subs-cache`, log `data/subs.log`).
- Changes here go live on the next queued file. Keep the CLI (`MODEL CACHE VIDEO...`) and the one-JSON-line-per-video output stable, and syntax-check before saving.
- Don't move or rename this skill without setting `SUBS_SKILL_DIR` for the worker.
- `~/.local/share/whisper-uv` holds the Python env shared with the `transcribe` skill and the worker. Don't delete it.

## What subs.py does

1. Downloads the top 8 English candidates by subliminal score from opensubtitles, podnapisi, addic7ed, tvsubtitles and gestdown. Any existing sidecar srt is a candidate too.
2. Drops ad/credit cues (regex `AD`).
3. Transcribes the 3 windows from the **English** audio track. Many files have a dubbed default track (Italian, Hindi...), and whisper on that matches nothing.
4. Matches words with difflib per window. Takes the median offset of runs of 3+ matching words and rejects scattered matches (wrong cut).
5. Fits a line offset(t) through the window anchors (shift plus drift). Retimes and drops cues that land before 0.
6. Keeps a candidate only if the retimed result is within 400 ms in at least 2 windows and no window gets worse or stops matching. If the 3-window fit fails (one noisy window, e.g. a montage with overlapping voices), it refits on each pair of windows and takes the first that passes. Picks the highest-quality candidate.

## Errors

- `no subtitles found`: providers returned nothing. Empty results are not cached, so rerun later (addic7ed and opensubtitles rate-limit big batches). Brand-new releases may have no real subs yet. Check that candidates are the right film, not commentary tracks.
- Candidates also include English or untagged text subtitle tracks embedded in the file (`embedded:<idx>`). They are usually cut for this exact release.
- If no candidate syncs cleanly on the 3 windows, subs.py transcribes 3 more (30%, 65%, 88%) for that file only, then tries again.
- `"fallback": true`: still nothing synced cleanly (different cut, TV recap). An okay sub beats none, so subs.py writes the best partial fit, retimed piecewise between the windows that matched. Report these so the user knows sync may drift.
- `no candidate matches this video`: candidates matched zero windows. That means the wrong film (sequels, commentary tracks) or subs for a new release are not out yet. Nothing is written. Retry later.

## Embedded subtitle tracks

Check them before downloading. Extract with `ffmpeg -i V -map 0:<idx> out.srt`, then grep for ads and check sync with the same three windows.
- Remove ads: `python3 $SK/clean_embedded.py VIDEO IDX[,IDX]`. It remuxes with stream copy, keeps the filename, language, title and default/forced flags, and verifies duration and stream count before replacing the file.
- Out of sync: run subs.py. The sidecar `.en.srt` then appears next to the embedded track. Tell the user to pick the external track.

## Rules

- Never pick low-resolution releases when replacing media. Don't touch video or audio streams except through stream-copy remuxes.
- Report per file: source, shift fixed, and anything skipped.
