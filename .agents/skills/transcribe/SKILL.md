---
name: transcribe
description: Use to transcribe an audio or video file into text with a whisper model
---

**Needs:** Superwhisper, `ffmpeg`, `uv` (all installed already).

**Steps:**
1. Set `IN` to the input file (audio or video).
2. Set `OUT` only if the user asks for a location. Default is the input path with `.txt`.
3. Run the block below as one shell call. The `trap` only cleans up if everything runs in the same shell.
4. Read `$OUT` and report back.

```sh
IN="/path/to/input.mp4"
OUT="${OUT:-${IN%.*}.txt}"
M="$HOME/Library/Application Support/superwhisper/ggml-medium.bin"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export UV_CACHE_DIR=$T/uv UV_PYTHON_INSTALL_DIR=$T/py UV_TOOL_DIR=$T/tools
ffmpeg -v error -i "$IN" -vn -ar 16000 -ac 1 "$T/a.wav" && \
uvx -q --from pywhispercpp python -c '
import sys; from pywhispercpp.model import Model
m = Model(sys.argv[1], print_progress=False, redirect_whispercpp_logs_to=None)
open(sys.argv[3],"w").write("\n".join(s.text.strip() for s in m.transcribe(sys.argv[2], no_context=True)))
' "$M" "$T/a.wav" "$OUT" >/dev/null 2>&1
cat "$OUT"
```

**What it does:**
- `ffmpeg` turns any audio or video into 16 kHz mono WAV inside the temp dir.
- `uvx` puts pywhispercpp into the temp dir. The `UV_*` vars keep it out of `~/.cache`.
- `no_context=True` stops Whisper repeating one line over and over during hold music or silence. That bug showed up in the Thai thread.
- `trap` deletes the temp dir, so the WAV, the packages and any downloaded Python all go. Only `$OUT` is left.

**Options:**
- Known language: add `, language="en"` after `no_context=True`. If you leave it out, Whisper detects the language itself.
- Need timestamps: change the join to `f"[{s.t0//6000}:{s.t0//100%60:02}] {s.text.strip()}"`. `t0` counts in 10 ms units.

**Rules:**
- Check `$M` exists first. If it doesn't, Superwhisper probably moved or renamed its model, so stop and tell the user.
- Label the result a machine transcript. Put any guessed words in `[brackets]`.
