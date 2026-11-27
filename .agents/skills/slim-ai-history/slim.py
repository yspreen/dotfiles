#!/usr/bin/env python3
"""Slim Codex / Claude Code chat history: strip base64 media, cap tool outputs.

usage: python3 -I slim.py [--dry-run] HOME...   (HOME = ~/.codex, ~/.claude, a CODEX_HOME copy)
Threads with any file modified in the last DAYS days are never touched. No backups are kept.
"""
import json, os, re, sqlite3, sys, time
from collections import defaultdict
from multiprocessing import Pool

DAYS = 30
HEAD, TAIL = 1500, 500
IMG = "[image removed]"
TOOL_KEYS = {"output", "stdout", "stderr", "aggregated_output", "formatted_output", "result", "toolUseResult"}
KEEP_KEYS = {"signature", "encrypted_content"}  # opaque blobs the API needs on resume
MEDIA_EXT = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".pdf", ".bmp", ".tiff", ".heic"}
DATA_URL = re.compile(r"(data:[\w/+.-]+;base64,)[A-Za-z0-9+/=]{200,}")
RAW_B64 = re.compile(r"[A-Za-z0-9+/=\r\n]{1000,}")
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")

def is_media(o):
    t = o.get("type"); src = o.get("source")
    return (t == "input_image" and len(str(o.get("image_url", ""))) > 1000
            or t == "image" and len(str(o.get("data", ""))) > 1000
            or isinstance(src, dict) and src.get("type") == "base64")

def cut(v, tool):
    if v.startswith("data:") and ";base64," in v[:100] or tool and RAW_B64.fullmatch(v):
        return IMG
    v = DATA_URL.sub(r"\1[removed]", v)
    if tool and len(v) > HEAD + TAIL + 100:
        v = f"{v[:HEAD]}\n[... {len(v) - HEAD - TAIL} chars of tool output removed ...]\n{v[-TAIL:]}"
    return v

def slim(o, tool=False):
    if isinstance(o, str): return cut(o, tool)
    if isinstance(o, list): return [slim(v, tool) for v in o]
    if not isinstance(o, dict): return o
    if is_media(o): return {"type": "input_text" if o["type"] == "input_image" else "text", "text": IMG}
    tr = o.get("type") == "tool_result"
    return {k: v if k in KEEP_KEYS else slim(v, tool or k in TOOL_KEYS or tr and k == "content") for k, v in o.items()}

def texts(o, tool=False, out=None):
    """Non-tool, non-media strings: must be identical before and after slimming."""
    out = [] if out is None else out
    if isinstance(o, str):
        if not tool and o != IMG and not (o.startswith("data:") and ";base64," in o[:100]): out.append(DATA_URL.sub(r"\1[removed]", o))
    elif isinstance(o, list): [texts(v, tool, out) for v in o]
    elif isinstance(o, dict) and not is_media(o) and o.get("text") != IMG:
        tr = o.get("type") == "tool_result"
        for k, v in o.items(): texts(v, tool or k in TOOL_KEYS or tr and k == "content", out)
    return out

def records(path):
    for line in open(path, encoding="utf-8"):
        try: r = json.loads(line)
        except ValueError: yield line, None; continue
        p = r.get("payload") if isinstance(r, dict) else None
        if isinstance(p, dict) and p.get("type") == "token_count": continue  # usage stats only
        yield line, r

def run(job):
    path, home = job
    st = os.stat(path); tmp = path + ".slim"
    if os.path.splitext(path)[1].lower() in MEDIA_EXT:
        os.remove(path); return path, st.st_size, 0
    before, after = [], []
    with open(tmp, "w", encoding="utf-8") as dst:
        if path.endswith(".jsonl"):
            for line, r in records(path):
                if r is None or len(line) < HEAD + TAIL + 100: dst.write(line); continue
                s = slim(r); before += texts(r); after += texts(s)
                dst.write(json.dumps(s, ensure_ascii=False, separators=(",", ":")) + "\n")
        else:  # Claude tool-results/*.txt|json: the whole file is tool output
            dst.write(cut(open(path, encoding="utf-8", errors="replace").read(), True))
    if before != after or os.stat(path).st_mtime_ns != st.st_mtime_ns:
        os.remove(tmp); return path, st.st_size, None
    os.chmod(tmp, st.st_mode & 0o777); os.replace(tmp, path)
    os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns))
    return path, st.st_size, os.path.getsize(path)

def threads(home):
    """{thread key: [files]} for Codex rollouts and Claude Code project sessions."""
    g = defaultdict(list)
    for sub in ("sessions", "archived_sessions"):
        for d, _, fs in os.walk(os.path.join(home, sub)):
            for f in fs:
                m = UUID.search(f)
                if f.endswith(".jsonl") and m: g["codex:" + m.group()].append(os.path.join(d, f))
    proj = os.path.join(home, "projects")
    for d, _, fs in os.walk(proj):
        for f in fs:
            p = os.path.join(d, f); parts = os.path.relpath(p, proj).split(os.sep)
            if len(parts) >= 2 and UUID.fullmatch(parts[1].removesuffix(".jsonl")) and not f.endswith(".slim"):
                g["claude:" + parts[0] + "/" + parts[1].removesuffix(".jsonl")].append(p)
    return g

def drop_codex_projection(home, ids):
    db = os.path.join(home, "thread_history_1.sqlite")
    if not ids or not os.path.exists(db): return
    con = sqlite3.connect(db)  # cached rows hold byte offsets into the rollouts; Codex re-projects
    with con:
        for t in ("thread_items", "thread_turns", "thread_realtime_items", "thread_history_projection_state"):
            con.executemany(f"delete from {t} where thread_id = ?", [(i,) for i in ids])

if __name__ == "__main__":
    dry = "--dry-run" in sys.argv
    cutoff = time.time() - DAYS * 86400
    for home in [os.path.abspath(os.path.expanduser(a)) for a in sys.argv[1:] if a != "--dry-run"]:
        g = threads(home)
        cold = {k: fs for k, fs in g.items() if max(os.path.getmtime(f) for f in fs) < cutoff}
        jobs = [(f, home) for fs in cold.values() for f in fs]
        print(f"{home}: {len(g)} threads, {len(g) - len(cold)} active in last {DAYS}d (skipped), {len(cold)} cold, {len(jobs)} files")
        if dry or not jobs: continue
        b = a = 0; done = set(); failed = []
        with Pool(8) as p:
            for path, x, y in p.imap_unordered(run, jobs, chunksize=4):
                if y is None: failed.append(path); continue
                b += x; a += y; done.add(path)
        drop_codex_projection(home, {k.split(":", 1)[1] for k, fs in cold.items() if k.startswith("codex:") and set(fs) & done})
        print(f"  {b/2**20:.1f} MiB -> {a/2**20:.1f} MiB; failed/skipped: {len(failed)}", *failed[:10], sep="\n  ")
