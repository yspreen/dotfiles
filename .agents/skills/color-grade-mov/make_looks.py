# Build per-location 65^3 .cube LUTs: python make_looks.py <outdir>
# NEO = "Capcut Color Grading | NeoTokyo" (EHmQgy7AXHI) values; OMOIDE = user's warm/contrast intent, de-pinked.
import sys, numpy as np
N = 65
g = np.linspace(0, 1, N)
b_, g_, r_ = np.meshgrid(g, g, g, indexing="ij")
RGB0 = np.stack([r_, g_, b_], -1).reshape(-1, 3)
LUMA = np.array([0.2627, 0.6780, 0.0593])
ss = lambda e0, e1, x: np.clip((x - e0) / (e1 - e0), 0, 1) ** 2 * (3 - 2 * np.clip((x - e0) / (e1 - e0), 0, 1))

def rgb2hsv(c):
    mx, mn = c.max(1), c.min(1); d = mx - mn; h = np.zeros(len(c))
    r, g, b = c.T; m = d > 1e-6
    i = m & (mx == r); h[i] = ((g - b)[i] / d[i]) % 6
    i = m & (mx == g) & (mx != r); h[i] = (b - r)[i] / d[i] + 2
    i = m & (mx == b) & (mx != r) & (mx != g); h[i] = (r - g)[i] / d[i] + 4
    return np.stack([h * 60, np.where(mx > 0, d / np.maximum(mx, 1e-6), 0), mx], 1)

def hsv2rgb(c):
    h, s, v = c.T; h = (h % 360) / 60; i = np.floor(h).astype(int) % 6; f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    return np.select([i[:, None] == k for k in range(6)],
                     [np.stack(x, 1) for x in ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))])

BANDS = [0, 30, 60, 120, 180, 240, 270, 300]                  # red orange yellow green cyan blue purple magenta
def band_w(h):
    c = np.array(BANDS + [360]); w = np.zeros((len(h), 8))
    for k in range(8):
        lo, hi = c[k], c[k + 1]; t = (h - lo) / (hi - lo); i = (h >= lo) & (h < hi)
        w[i, k] += 1 - t[i]; w[i, (k + 1) % 8] += t[i]
    return w

def hsl(c, H, S, L):                                            # CapCut-style ±100 sliders per band
    hsv = rgb2hsv(c); w = band_w(hsv[:, 0])
    hsv[:, 0] += w @ (np.array(H) * 0.30)                        # 100 -> 30 deg
    hsv[:, 1] = np.clip(hsv[:, 1] * (1 + w @ (np.array(S) / 100)), 0, 1)
    hsv[:, 2] = hsv[:, 2] * (1 + (w @ (np.array(L) / 100)) * 0.5 * hsv[:, 1])
    return hsv2rgb(hsv)

def tones(c, contrast=0, brilliance=0, highlights=0, shadows=0, whites=0, blacks=0, tint=0):
    c = c * np.array([1 + tint / 100 * 0.06, 1 - tint / 100 * 0.12, 1 + tint / 100 * 0.06])   # tint<0 -> green
    k = (1 + contrast / 100 * 0.6) * (1 + brilliance / 100 * 0.3)
    c = 0.5 + (c - 0.5) * k
    c = c + highlights / 100 * 0.25 * ss(0.35, 0.85, c) * (1 - c) * 2.5
    c = c + shadows / 100 * 0.25 * (1 - ss(0.15, 0.65, c)) * c * 2.5
    c = c + whites / 100 * 0.15 * ss(0.7, 1, c) + blacks / 100 * 0.15 * (1 - ss(0, 0.3, c))
    y = (c * LUMA).sum(1, keepdims=True); c = y + (c - y) * (1 + brilliance / 100 * 0.15)
    return c

def curves(c, master, rgb):                                     # midpoint (in,out) on 0-255, power curve through it
    pw = lambda x, p: np.sign(x) * np.abs(x) ** (np.log(p[1] / 255) / np.log(p[0] / 255))
    c = pw(c, master)
    return np.stack([pw(c[:, i], rgb[i]) for i in range(3)], 1)

def primaries(c, lift=(0, 0, 0), gamma=(0, 0, 0), gain=(0, 0, 0), offset=(0, 0, 0)):
    c = c + np.array(offset); c = c + np.array(lift) * (1 - c)
    c = np.sign(c) * np.abs(c) ** (1 / (1 + np.array(gamma))); return c * (1 + np.array(gain))

def skin_mask(c):
    h, s, v = rgb2hsv(c).T
    hue = np.clip(1 - np.abs(h - 25) / 22, 0, 1)               # ~3-47 deg
    return hue * ss(0.12, 0.25, s) * (1 - ss(0.6, 0.8, s)) * ss(0.15, 0.3, v)

NEO_HSL = dict(H=[0, -15, 16, 37, 28, -26, 0, 0], S=[14, 12, 16, 18, 18, 28, 0, 0], L=[14, 0, 19, 0, 18, 14, 0, 0])
def neo(c):
    c = tones(c, contrast=-15, brilliance=-20, highlights=10, shadows=10, whites=-4, blacks=-4, tint=-15)
    c = hsl(np.clip(c, 0, 1), **NEO_HSL)
    return curves(np.clip(c, 0, 1), (129, 97), [(127, 89), (126, 156), (124, 158)])

def omoide(c):
    c = primaries(c, lift=(-0.02, 0, 0.015), gamma=(0.015, 0.008, -0.01), gain=(0.035, 0.02, -0.04))   # orange, not pink
    c = tones(np.clip(c, 0, 1), contrast=12, shadows=-4, highlights=4)                                  # contrast via S, no crush
    c = hsl(np.clip(c, 0, 1), H=[0, 0, 8, 25, 20, -15, 0, 0], S=[14, 8, 16, 12, 15, 20, 0, 0], L=[8, 0, 10, 0, 10, 8, 0, 0])
    return c

def build(fn, strength, protect, hi_protect=0.0):
    out = fn(RGB0.copy())
    y = (RGB0 * LUMA).sum(1)
    m = (strength * (1 - protect * skin_mask(RGB0)) * (1 - hi_protect * ss(0.8, 1.0, y)))[:, None]
    return np.clip(RGB0 + (np.clip(out, 0, 1) - RGB0) * m, 0, 1)

LOOKS = {"night": (neo, 0.9, 0.3, 0.5), "walkway": (neo, 0.45, 0.75, 0.5), "platform": (neo, 0.45, 0.75, 0.5), "omoide": (omoide, 1.0, 0.0, 0.0)}
for name, (fn, st, pr, hp) in LOOKS.items():
    x = build(fn, st, pr, hp)
    with open(f"{sys.argv[1]}/{name}.cube", "w") as f:
        f.write(f'TITLE "{name}"\nLUT_3D_SIZE {N}\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n')
        f.writelines(f"{a:.6f} {b:.6f} {d:.6f}\n" for a, b, d in x)
    print(name, "ok")
