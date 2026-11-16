"""Weather + engine extras: rain, thunder, waves, turbo whistle, exhaust pop. Run: python3 tools/make_sounds4.py"""
import numpy as np, os
from scipy.io import wavfile
from scipy.signal import butter, lfilter
SR = 22050
rng = np.random.default_rng(23)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
def save(name, x, gain=0.8):
    x = np.asarray(x, float); x = x / (np.abs(x).max() + 1e-9) * gain
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))
def band(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)
def low(x, f):
    b, a = butter(2, f / (SR / 2), btype="low")
    return lfilter(b, a, x)
def loopify(x, fade):
    n = int(fade * SR)
    out = x[:-n].copy()
    w = np.linspace(0, 1, n)
    out[:n] = out[:n] * w + x[-n:] * (1 - w)
    return out
# rain: hissing band noise + a layer of random tiny drops
n = SR * 5; t = np.arange(n) / SR
hiss = band(rng.normal(0, 1, n), 1500, 7500) * (0.7 + 0.3 * low(rng.normal(0, 1, n), 2) * 8)
drops = np.zeros(n)
for i in rng.integers(0, n - 400, 900):
    L = 300; tt = np.arange(L) / SR
    drops[i:i + L] += rng.uniform(0.2, 1.0) * np.sin(2 * np.pi * rng.uniform(2500, 6000) * tt) * np.exp(-tt / 0.002)
save("rain_loop", loopify(hiss * 0.9 + drops * 0.5, 0.4), 0.7)
# thunder: sharp crack then a long rolling rumble
n = int(SR * 4.5); t = np.arange(n) / SR
crack = band(rng.normal(0, 1, n), 800, 4000) * np.exp(-t / 0.08)
rumble = low(rng.normal(0, 1, n), 140) * (np.exp(-t / 1.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 3.2 * t)) ** 2)
rumble2 = low(rng.normal(0, 1, n), 60) * np.exp(-t / 2.3) * 2
save("thunder", crack * 0.6 + rumble * 3 + rumble2, 0.9)
# waves: slow swells of filtered noise
n = SR * 8; t = np.arange(n) / SR
sw = 0.5 + 0.5 * np.sin(2 * np.pi * t / 8 * 1.0 - 1.0)
sw2 = 0.5 + 0.5 * np.sin(2 * np.pi * t / 4 * 1.0 + 0.5)
w = band(rng.normal(0, 1, n), 200, 2500) * (0.2 + 0.8 * sw * (0.6 + 0.4 * sw2))
save("waves_loop", loopify(w, 0.5), 0.6)
# turbo whistle: thin rising tone with a little breath noise (pitch is set in game)
n = SR * 2; t = np.arange(n) / SR
f = 2200
tone = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) + 0.15 * np.sin(2 * np.pi * f * 3 * t)
tone *= 0.85 + 0.15 * np.sin(2 * np.pi * 11 * t)
tone += 0.25 * band(rng.normal(0, 1, n), 3000, 7000)
save("turbo_loop", loopify(tone, 0.1), 0.5)
# exhaust pop / crackle: a few short bangs with a low thump
n = int(SR * 0.6); t = np.arange(n) / SR
out = np.zeros(n)
for t0, a in ((0.0, 1.0), (0.12, 0.6), (0.24, 0.8), (0.4, 0.4)):
    i = int(t0 * SR); L = int(0.09 * SR); tt = np.arange(L) / SR
    out[i:i + L] += a * (band(rng.normal(0, 1, L), 300, 3500) * np.exp(-tt / 0.012) + np.sin(2 * np.pi * 90 * tt) * np.exp(-tt / 0.03) * 0.6)
save("exhaust_pop", out, 0.8)
