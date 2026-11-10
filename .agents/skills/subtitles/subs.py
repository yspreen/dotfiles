"""Best English subs per video: download candidates, strip ads, sync by transcribing three 1-min windows.
Usage: subs.py MODEL CACHE_DIR VIDEO...   (one JSON line per video; writes <video>.en.srt and <video>.en.sdh.srt)"""
import json, os, re, shutil, subprocess, sys, tempfile, statistics as st
from difflib import SequenceMatcher
from babelfish import Language
from subliminal import scan_video, list_subtitles, download_subtitles, compute_score, region
from pywhispercpp.model import Model

region.configure("dogpile.cache.memory")
AD = re.compile(r"subtitles? by|subbed by|sync(ed)? (by|and|&)|correct(ed|ions) by|free movies|www\.|https?:|\.(com|org|net)\b"
                r"|\byts\b|yify|osdb|opensub|addic7ed|explosiveskull|rip(ped)? by|encoded by", re.I)
MARKS, WIN, TOL = (.10, .50, .80), 60, 400  # windows past the intro, mid, before credits; 1 min each; ms accepted after sync
NUDGE, MIN_WORDS = (0, .05, -.05, .10, -.10, .15), 30  # quiet window (silence, music, montage): try nearby ones
EXTRA = (.30, .65, .88)  # 3 more windows, only for files where the first 3 sync no candidate
TEXT_SUBS = {"subrip", "ass", "ssa", "mov_text", "webvtt"}  # embedded tracks we can read as text
PROVIDERS = ["opensubtitles", "podnapisi", "addic7ed", "tvsubtitles", "gestdown"]
model, cache_dir, videos = Model(sys.argv[1], print_progress=False, redirect_whispercpp_logs_to=None), sys.argv[2], sys.argv[3:]
tmp = tempfile.mkdtemp()
run = lambda *a: subprocess.run(a, capture_output=True, text=True, check=True).stdout

def ms(t):
    h, m, s, f = map(int, re.split(r"[:,.]", t)); return ((h * 60 + m) * 60 + s) * 1000 + f

def fmt(x):
    x = max(0, int(x)); return f"{x//3600000:02}:{x//60000%60:02}:{x//1000%60:02},{x%1000:03}"

def parse(text):  # -> [(start_ms, end_ms, text)] with ad cues dropped
    cues = []
    for block in re.split(r"\r?\n\s*\r?\n", text.replace("﻿", "").strip()):
        lines = block.strip().splitlines()
        i = next((i for i, l in enumerate(lines) if "-->" in l), None)
        if i is None: continue
        m = re.match(r"\s*(\S+)\s*-->\s*(\S+)", lines[i]); body = "\n".join(lines[i + 1:]).strip()
        if not (m and body and not AD.search(body)): continue
        try: cues.append((ms(m[1]), ms(m[2]), body))
        except ValueError: pass  # malformed timestamp: drop this cue, keep the file
    return cues

def words(items):  # -> [(word, time_ms)], time interpolated across the cue; drops [sfx], (sfx), <tags>, SPEAKER:
    out = []
    for t0, t1, text in items:
        w = re.findall(r"[a-z0-9']+", re.sub(r"\[.*?\]|\(.*?\)|<.*?>|^[A-Z ]+:", " ", text, flags=re.M).lower())
        out += [(x, t0 + (t1 - t0) * (i + .5) / len(w)) for i, x in enumerate(w)]
    return out

def transcribe(video, start):  # English audio track, not a default dub
    langs = run("ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream_tags=language", "-of", "csv=p=0", video).splitlines()
    a = next((i for i, l in enumerate(langs) if l == "eng"), 0)
    run("ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(WIN), "-i", video, "-map", f"0:a:{a}", "-ar", "16000", "-ac", "1", f"{tmp}/w.wav")
    return [(s.t0 * 10 + start * 1000, s.t1 * 10 + start * 1000, s.text) for s in model.transcribe(f"{tmp}/w.wav", no_context=True, language="en")]

def sample(video, dur, m):  # first window near mark m with real speech -> ((lo_ms, hi_ms), transcript)
    for d in NUDGE:
        s = int(dur * min(max(m + d, .03), .88)); seg = transcribe(video, s)
        if len(words(seg)) >= MIN_WORDS: break
    return (s * 1000, (s + WIN) * 1000), seg

def offset(cues, segs, lo, hi):  # median (transcript - subtitle) ms of matched words near window, plus match rate
    sw = [w for w in words(cues) if lo - 60000 <= w[1] <= hi + 60000]; ww = words(segs)
    if not sw or not ww: return None, 0.0
    sm = SequenceMatcher(None, [w for w, _ in sw], [w for w, _ in ww], autojunk=False)
    offs = [ww[b.b + k][1] - sw[b.a + k][1] for b in sm.get_matching_blocks() if b.size >= 3 for k in range(b.size)]
    if len(offs) < 8: return None, 0.0
    med = st.median(offs); inl = [o for o in offs if abs(o - med) < 1500]
    if len(inl) < .6 * len(offs): return None, 0.0  # scattered: false anchors or a different cut
    return st.median(inl), min(1.0, len(inl) / (sum(1 for w in sw if lo <= w[1] <= hi) or 1))

def evaluate(cues, segs, wins):  # -> {window: (center_in_sub_time, offset)}, quality
    pts, q = {}, 0.0
    for i, (seg, (lo, hi)) in enumerate(zip(segs, wins)):
        o, r = offset(cues, seg, lo, hi); q += r / len(wins)
        if o is not None: pts[i] = ((lo + hi) / 2 - o, o)
    return pts, q

def retime(cues, pts, piecewise=False):  # offset(t): least-squares line through the window anchors,
    pts = sorted(pts.values())             # or (piecewise, for fallbacks with cut differences) linear between anchors
    if piecewise and len(pts) > 1:
        def g(t):
            for (t0, o0), (t1, o1) in zip(pts, pts[1:]):
                if t <= t1: return o0 + (o1 - o0) * max(0, t - t0) / ((t1 - t0) or 1)
            return pts[-1][1]
        f = lambda t: t + g(t)
    else:
        if len(pts) == 1: a, b = 0.0, pts[0][1]
        else:
            mt, mo = st.mean(t for t, _ in pts), st.mean(o for _, o in pts)
            a = sum((t - mt) * (o - mo) for t, o in pts) / sum((t - mt) ** 2 for t, _ in pts); b = mo - a * mt
        f = lambda t: t + a * t + b
    kept = [(f(s), f(e), x) for s, e, x in cues if f(e) > 0]
    return "\n".join(f"{i}\n{fmt(s)} --> {fmt(e)}\n{x}\n" for i, (s, e, x) in enumerate(kept, 1))

def embedded(video):  # English or untagged text subtitle tracks inside the file: usually cut for this exact release
    out = []
    for s in json.loads(run("ffprobe", "-v", "error", "-select_streams", "s", "-show_entries",
                            "stream=index,codec_name:stream_tags=language,title", "-of", "json", video)).get("streams", []):
        tags = s.get("tags", {})
        if s.get("codec_name") in TEXT_SUBS and tags.get("language", "und") in ("eng", "en", "und"):
            text = run("ffmpeg", "-v", "error", "-i", video, "-map", f"0:{s['index']}", "-f", "srt", "-")
            out.append((f"embedded:{s['index']}", bool(re.search(r"sdh|\bhi\b|hearing", tags.get("title", ""), re.I)), parse(text)))
    return out

def select(cands, segs, wins):  # -> (clean syncs, partial fits) as (quality, name, hi, srt_text, shifts_ms)
    good, partial = [], []  # good: retimed output lands within TOL in at least 2 windows and fails none
    for n, hi, c in cands:
        if len(c) < 50: continue
        pts, q = evaluate(c, segs, wins)
        if not pts: continue  # matched no window: different film or cut, never written
        partial.append((q, n, hi, retime(c, pts, piecewise=True), [round(o) for _, o in pts.values()]))
        fits = [pts] + ([{k: v for k, v in pts.items() if k != i} for i in pts] if len(pts) > 2 else [])  # noisy window: refit without it
        for fit in fits:
            out = retime(c, fit); chk, _ = evaluate(parse(out), segs, wins)
            if sum(abs(o) < TOL for _, o in chk.values()) >= 2 and all(i in chk and abs(chk[i][1]) <= max(TOL, abs(pts[i][1])) for i in pts):
                good.append((q, n, hi, out, [round(o) for _, o in pts.values()])); break
    return sorted(good, key=lambda g: -g[0]), partial

for video in videos:
    r = dict(video=video)
    try:
        dur = float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video))
        key = os.path.join(cache_dir, re.sub(r"\W+", "_", os.path.basename(video)))
        os.makedirs(cache_dir, exist_ok=True)
        if os.path.exists(key + ".tx.json"): wins, segs = json.load(open(key + ".tx.json"))
        else: wins, segs = zip(*[sample(video, dur, m) for m in MARKS]); json.dump([wins, segs], open(key + ".tx.json", "w"))
        base = os.path.splitext(video)[0]
        existing = [p for p in (base + ".en.srt", base + ".srt") if os.path.exists(p)]
        cands = [("existing", False, parse(open(existing[0], encoding="utf-8", errors="replace").read()))] if existing else []
        cands += embedded(video)
        if os.path.exists(key + ".cands.json"): cands += [tuple(c) for c in json.load(open(key + ".cands.json"))]
        else:
            v = scan_video(video)
            subs = sorted(list_subtitles({v}, {Language("eng")}, providers=PROVIDERS)[v], key=lambda s: -compute_score(s, v))[:8]
            download_subtitles(subs)
            found = [(f"{s.provider_name}:{s.id}", bool(s.hearing_impaired), parse(s.text)) for s in subs if s.content]
            if found: json.dump(found, open(key + ".cands.json", "w"))  # empty = rate limited; retry next run
            cands += found
        good, partial = select(cands, segs, wins)
        if not good and cands:  # nothing syncs on 3 windows: transcribe 3 more, only for these files
            if os.path.exists(key + ".tx2.json"): w2, s2 = json.load(open(key + ".tx2.json"))
            else: w2, s2 = zip(*[sample(video, dur, m) for m in EXTRA]); json.dump([w2, s2], open(key + ".tx2.json", "w"))
            wins, segs = list(wins) + list(w2), list(segs) + list(s2)
            good, partial = select(cands, segs, wins)
        r["candidates"] = [(n, hi, round(q, 2)) for q, n, hi, _, _ in good]
        if not good and not partial: raise RuntimeError("no candidate matches this video" if cands else "no subtitles found")
        if not good:  # an okay subtitle beats none: best partial fit, retimed piecewise between matched windows
            good, r["fallback"] = [max(partial, key=lambda g: g[0])], True
        for want_hi, suffix in ((False, ".en.srt"), (True, ".en.sdh.srt")):
            pick = next((g for g in good if g[2] == want_hi and g[0] >= good[0][0] - .08), None)
            if pick is None and not want_hi: pick = good[0]  # only HI exists: still use it as the main track
            if pick is None: continue
            for p in existing: shutil.copy2(p, os.path.join(cache_dir, os.path.basename(p)))
            open(base + suffix, "w", encoding="utf-8").write(pick[3])
            r[suffix] = dict(src=pick[1], q=round(pick[0], 2), shifts_ms=pick[4])
        for p in existing:
            if p != base + ".en.srt": os.remove(p)
    except Exception as e:
        r["error"] = repr(e)
    print(json.dumps(r), flush=True)
