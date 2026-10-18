"""Podium / ceremony sounds. Run: python3 tools/make_sounds2.py  (needs numpy + scipy)"""
import numpy as np
from scipy.io import wavfile
import os

SR = 22050
rng = np.random.default_rng(11)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))


def env_decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def brass(freq, dur, vib=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    ph = 2 * np.pi * freq * t + vib * np.sin(2 * np.pi * 5.5 * t)
    x = np.zeros(n)
    for k in range(1, 12):
        x += np.sin(k * ph) / (k ** 0.9) * (1.0 if k < 8 else 0.5)
    att = np.clip(t / 0.05, 0, 1) ** 0.7
    rel = np.clip((dur - t) / 0.08, 0, 1)
    swell = 0.75 + 0.25 * np.clip(t / 0.2, 0, 1)
    return np.tanh(1.6 * x) * att * rel * swell


def place(buf, x, start):
    i = int(start * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


# ---- fanfare: "ta ta ta TAAA" + big chord
buf = np.zeros(int(SR * 4.6))
G4, C5, E5, G5, C6 = 392.0, 523.25, 659.25, 783.99, 1046.5
for st, f, d in [(0.0, G4, 0.2), (0.25, G4, 0.2), (0.5, G4, 0.2), (0.78, C5, 0.9), (1.8, G4, 0.22), (2.07, C5, 0.22), (2.34, E5, 0.22)]:
    place(buf, brass(f, d, 0.3), st)
for f in [C5, E5, G5, C6]:
    place(buf, brass(f, 1.9, 0.5) * 0.7, 2.7)
    place(buf, brass(f / 2, 1.9, 0.4) * 0.5, 2.7)
# timpani under the chord
tt = np.arange(int(SR * 1.6)) / SR
place(buf, np.sin(2 * np.pi * (90 - 30 * tt) * tt) * env_decay(len(tt), 0.35) * 1.5, 2.7)
save("fanfare", buf)

# ---- applause: lots of tiny claps, swelling
n = int(SR * 7.0)
ap = np.zeros(n)
for pos in rng.integers(0, n - 500, 5200):
    L = int(rng.integers(80, 260))
    c = rng.normal(0, 1, L) * env_decay(L, rng.uniform(0.002, 0.006))
    ap[pos:pos + L] += c * rng.uniform(0.15, 1.0)
ap = band(ap, 500, 7000)
ap += 0.25 * band(rng.normal(0, 1, n), 700, 3500)
# crossfade the ends so it loops
fade = int(SR * 0.5)
w = np.linspace(0, 1, fade)
ap[:fade] = ap[:fade] * w + ap[-fade:] * (1 - w)
ap = ap[:-fade]
save("applause", ap, 0.8)

# ---- cheer: crowd "ooooh/yeaah" using formant-filtered noise with a rising pitch bend
n = int(SR * 3.2)
t = np.arange(n) / SR
ch = np.zeros(n)
for v in range(14):
    f0 = rng.uniform(150, 280) * (1.0 + 0.25 * np.clip(t / 1.2, 0, 1))
    ph = 2 * np.pi * np.cumsum(f0) / SR
    src = np.sign(np.sin(ph)) * 0.5 + np.sin(ph)
    d = rng.uniform(0, 0.2)
    e = np.clip((t - d) / 0.25, 0, 1) * np.clip((3.0 - t) / 0.8, 0, 1)
    ch += band(src, 600, 1100) * e + 0.6 * band(src, 1700, 2600) * e
ch += 0.5 * band(rng.normal(0, 1, n), 800, 3000) * np.clip(t / 0.4, 0, 1) * np.clip((3.0 - t) / 0.6, 0, 1)
save("cheer", ch, 0.8)

# ---- confetti cannon pop
n = int(SR * 0.7)
tt = np.arange(n) / SR
pop = rng.normal(0, 1, n) * env_decay(n, 0.05) + 1.4 * np.sin(2 * np.pi * (140 - 90 * tt / 0.7) * tt) * env_decay(n, 0.09)
pop += 0.5 * band(rng.normal(0, 1, n), 2500, 8000) * env_decay(n, 0.25)
save("pop", pop)

# ---- camera shutter / flash
n = int(SR * 0.22)
sh = np.zeros(n)
for st, a in [(0.0, 1.0), (0.07, 0.7)]:
    L = int(SR * 0.04)
    c = band(rng.normal(0, 1, L), 1800, 7000) * env_decay(L, 0.008)
    sh[int(st * SR):int(st * SR) + L] += c * a
save("shutter", sh, 0.6)

# ---- medal "ding" and trophy shine
n = int(SR * 1.4)
tt = np.arange(n) / SR
ding = sum(np.sin(2 * np.pi * f * tt) * env_decay(n, tau) * a for f, tau, a in [(1568, 0.5, 1.0), (2349, 0.35, 0.5), (3136, 0.25, 0.3), (4186, 0.15, 0.2)])
save("ding", ding, 0.7)

# ---- stage whoosh (podium block rising)
n = int(SR * 0.9)
tt = np.arange(n) / SR
wo = band(rng.normal(0, 1, n), 200, 2500) * np.sin(np.pi * tt / 0.9) ** 2
wo += 0.6 * np.sin(2 * np.pi * (60 + 80 * tt) * tt) * np.sin(np.pi * tt / 0.9)
save("whoosh", wo, 0.7)

# ---- radio tuning static
n = int(SR * 0.5)
tt = np.arange(n) / SR
st = band(rng.normal(0, 1, n), 300, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * tt)) * np.sin(np.pi * tt / 0.5)
st += 0.3 * np.sin(2 * np.pi * (700 + 900 * np.sin(2 * np.pi * 3 * tt)) * tt) * np.sin(np.pi * tt / 0.5)
save("tune", st, 0.6)
print("ok")
