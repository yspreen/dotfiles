#!/usr/bin/env nix-shell
#!nix-shell -i bash -p yt-dlp python3

# yt2subs.sh — YouTube URL -> plain subtitle text (stdout only)
# Usage: ./yt2subs.sh "https://www.youtube.com/watch?v=..."
# Env (optional):
#   LANG_PREF="en,en.*"                # yt-dlp --sub-langs value
#   SUBFORMATS="vtt/srv3/ttml/json3"   # yt-dlp --sub-format preference
#   COOKIES="$HOME/cookies.txt"        # for age/consent-gated videos

set -euo pipefail

URL="${1:-}"
if [ -z "$URL" ]; then
  printf 'error: no URL provided\n' >&2
  exit 1
fi

# Ensure tools available (provided by nix-shell above)
command -v yt-dlp >/dev/null 2>&1 || { printf 'error: yt-dlp not found\n' >&2; exit 1; }
command -v python3 >/dev/null 2>&1  || { printf 'error: python3 not found\n' >&2; exit 1; }

TMP="$(mktemp -d)"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

LANG_PREF="${LANG_PREF:-en,en.*}"
SUBFORMATS="${SUBFORMATS:-vtt/srv3/ttml/json3/srv2}"

cd "$TMP"

COMMON=( --no-warnings --skip-download --sub-langs "$LANG_PREF" --sub-format "$SUBFORMATS" )
[ -n "${COOKIES:-}" ] && COMMON+=( --cookies "$COOKIES" )

# Try creator subtitles first, then auto-captions. Stay silent on stdout.
yt-dlp "${COMMON[@]}" --write-sub "$URL" >/dev/null 2>&1 || true

shopt -s nullglob
candidates=( *.vtt *.ttml *.json3 *.srv3 *.srv2 *.srt )

if [ ${#candidates[@]} -eq 0 ]; then
  yt-dlp "${COMMON[@]}" --write-auto-sub "$URL" >/dev/null 2>&1 || true
  candidates=( *.vtt *.ttml *.json3 *.srv3 *.srv2 *.srt )
fi

# No subs available → print nothing and exit successfully.
if [ ${#candidates[@]} -eq 0 ]; then
  exit 0
fi

# Pick the first candidate (preference by glob order above: vtt → ttml → json3 → srv3 → srv2 → srt)
caption_file="${candidates[0]}"

# Parse and print ONLY the text
python3 - "$caption_file" <<'PY'
import sys, os, re, html, json, xml.etree.ElementTree as ET

path = sys.argv[1]
ext = os.path.splitext(path)[1].lower().lstrip('.')

def vtt_to_text(s: str) -> str:
    out, in_cue = [], False
    for line in s.splitlines():
        if line.startswith(('WEBVTT','Kind:','Language:','NOTE')): continue
        if re.fullmatch(r'\s*\d+\s*', line): continue
        if '-->' in line: in_cue = True; continue
        if not line.strip(): in_cue = False; continue
        if in_cue:
            clean = re.sub(r'</?[^>]+>', '', line)         # strip tags
            clean = html.unescape(clean).strip()
            if clean: out.append(clean)
    # collapse consecutive duplicates
    final, prev = [], None
    for t in out:
        if t != prev: final.append(t); prev = t
    return '\n'.join(final)

def srt_to_text(s: str) -> str:
    out, in_cue = [], False
    for line in s.splitlines():
        if re.fullmatch(r'\s*\d+\s*', line): continue
        if re.search(r'\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}', line):
            in_cue = True
            continue
        if not line.strip():
            in_cue = False
            continue
        if in_cue:
            clean = html.unescape(line.strip())
            if clean: out.append(clean)
    final, prev = [], None
    for t in out:
        if t != prev: final.append(t); prev = t
    return '\n'.join(final)

def ttml_to_text(s: str) -> str:
    try:
        root = ET.fromstring(s)
    except ET.ParseError:
        return ""
    out=[]
    for p in root.findall('.//{*}p'):
        t=''.join(p.itertext()).strip()
        if t: out.append(t)
    return '\n'.join(out)

def json_like_to_text(s: str) -> str:
    # Handles YouTube json3/srv2/srv3 structures
    try:
        j = json.loads(s)
    except Exception:
        return ""
    out=[]
    events = j.get('events') or j.get('body') or []
    for ev in events:
        segs = ev.get('segs') or []
        if isinstance(segs, list):
            txt = ''.join((seg.get('utf8') or '') for seg in segs).strip()
            if txt: out.append(txt)
        else:
            # some variants have "utf8" directly
            txt = (ev.get('utf8') or '').strip()
            if txt: out.append(txt)
    return '\n'.join(out)

try:
    raw = open(path, 'rb').read()
    text = ""
    if ext == 'vtt':
        text = vtt_to_text(raw.decode('utf-8', 'ignore'))
    elif ext in ('ttml', 'xml'):
        text = ttml_to_text(raw.decode('utf-8', 'ignore'))
    elif ext in ('json3', 'srv3', 'srv2'):
        text = json_like_to_text(raw.decode('utf-8', 'ignore'))
    elif ext == 'srt':
        text = srt_to_text(raw.decode('utf-8', 'ignore'))
    else:
        # best-effort fallback
        text = vtt_to_text(raw.decode('utf-8', 'ignore')) or raw.decode('utf-8','ignore')
    if text:
        sys.stdout.write(text)
    # else: print nothing
except Exception as e:
    # Fatal error case -> stderr
    sys.stderr.write(f"error: failed to parse captions: {e}\n")
    sys.exit(1)
PY
