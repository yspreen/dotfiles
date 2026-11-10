"""Remux VIDEO replacing embedded text sub tracks INDEXES with ad-stripped copies (stream copy, same filename).
Usage: clean.py VIDEO INDEX[,INDEX...]"""
import json, os, re, subprocess, sys, tempfile
AD = re.compile(r"subtitles? by|subbed by|sync(ed)? (by|and|&)|correct(ed|ions) by|www\.|https?:|addic7ed|opensub", re.I)
video, idxs = sys.argv[1], [int(i) for i in sys.argv[2].split(",")]
probe = lambda f: json.loads(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=index,codec_type:stream_disposition=default,forced:format=duration",
                                             "-of", "json", f], capture_output=True, text=True).stdout)
info, tmp = probe(video), tempfile.mkdtemp()
streams, subs = info["streams"], [s["index"] for s in info["streams"] if s["codec_type"] == "subtitle"]
args, maps, extra = ["ffmpeg", "-v", "error", "-i", video], [], []
for k, i in enumerate(idxs, 1):
    srt = f"{tmp}/{i}.srt"
    subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-map", f"0:{i}", srt], check=True)
    blocks = re.split(r"\r?\n\s*\r?\n", open(srt, encoding="utf-8").read().strip())
    kept = [b for b in blocks if not AD.search(b.split("-->", 1)[-1])]
    print(f"track {i}: removed {[b.splitlines()[2:] for b in blocks if b not in kept]}")
    open(srt, "w", encoding="utf-8").write("\n\n".join(kept) + "\n")
    args += ["-i", srt]
    j, d = subs.index(i), streams[i]["disposition"]
    extra += [f"-disposition:s:{j}", "+".join(x for x in ("default", "forced") if d[x]) or "0"]
maps = sum((["-map", f"{idxs.index(s['index']) + 1}:0" if s["index"] in idxs else f"0:{s['index']}"] for s in streams), [])
out = os.path.join(os.path.dirname(video), ".clean." + os.path.basename(video))
subprocess.run(args + maps + ["-map_metadata", "0", "-map_chapters", "0"] + sum(([f"-map_metadata:s:{s['index']}", f"0:s:{s['index']}"] for s in streams), []) + extra + ["-c", "copy", out], check=True)
o = probe(out)
assert abs(float(info["format"]["duration"]) - float(o["format"]["duration"])) < 1 and len(o["streams"]) == len(streams)
os.replace(out, video)
print("cleaned", video)
