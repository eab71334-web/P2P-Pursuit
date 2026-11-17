"""Layered engine loops per engine type (physical-ish synthesis: firing pulses -> exhaust resonances -> saturation).
Run: python3 tools/make_engines.py   -> audio/eng_<type>_<layer>.wav  (3 rpm layers each, seamless 2 s loops)"""
import numpy as np
from scipy.io import wavfile
import os

SR = 22050
T = 2.0
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(11)

# cyl, firing jitter pattern (fraction of the firing interval), exhaust resonances (Hz, gain), layer rpms, drive, rasp, noise
TYPES = {
    "i4t": dict(cyl=4, jit=[0, 0, 0, 0], res=[(140, 1.0), (430, 0.7), (950, 0.35)], rpm=[900, 3200, 6200], drive=1.7, rasp=0.25, nz=0.25),
    "i4r": dict(cyl=4, jit=[0, 0.04, -0.03, 0.02], res=[(190, 1.0), (560, 0.8), (1300, 0.5)], rpm=[1100, 3800, 7200], drive=2.1, rasp=0.4, nz=0.3),
    "v8": dict(cyl=8, jit=[0, 0.22, -0.1, 0.12, -0.2, 0.08, -0.05, 0.16], res=[(85, 1.0), (260, 0.8), (620, 0.4)], rpm=[700, 2600, 5600], drive=2.2, rasp=0.3, nz=0.3),
    "v8d": dict(cyl=8, jit=[0, 0.25, -0.12, 0.15, -0.22, 0.1, -0.06, 0.18], res=[(70, 1.0), (210, 0.9), (480, 0.4)], rpm=[600, 2200, 4400], drive=2.6, rasp=0.45, nz=0.4),
    "v6d": dict(cyl=6, jit=[0, 0.2, -0.08, 0.14, -0.18, 0.06], res=[(80, 1.0), (240, 0.9), (520, 0.45)], rpm=[650, 2300, 4300], drive=2.5, rasp=0.45, nz=0.4),
    "i6": dict(cyl=6, jit=[0] * 6, res=[(110, 1.0), (340, 0.75), (700, 0.45), (1500, 0.2)], rpm=[900, 3500, 7000], drive=1.9, rasp=0.2, nz=0.22),
    "f6": dict(cyl=6, jit=[0, 0.02, -0.02, 0.03, -0.01, 0.01], res=[(125, 1.0), (500, 0.8), (1150, 0.6), (2400, 0.3)], rpm=[1000, 4500, 8800], drive=2.0, rasp=0.5, nz=0.3),
    "v12": dict(cyl=12, jit=[0] * 12, res=[(150, 1.0), (620, 0.8), (1500, 0.55), (3000, 0.25)], rpm=[1000, 5000, 9000], drive=1.5, rasp=0.35, nz=0.25),
}


def fft_filter(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.clip((f - lo * 0.7) / (lo * 0.3 + 1e-9), 0, 1) * np.clip((hi * 1.3 - f) / (hi * 0.3 + 1e-9), 0, 1)
    return np.fft.irfft(X * m, len(x))


def layer(p, rpm):
    n = int(SR * T)
    F = rpm / 60.0 * p["cyl"] / 2.0
    N = max(2, int(round(F * T)))
    # whole number of firing cycles of the pattern (so the loop is seamless)
    cyc = p["cyl"]
    N = max(cyc, int(round(N / cyc)) * cyc)
    F = N / T
    ivl = 1.0 / F
    out = np.zeros(n)
    hz_scale = 0.75 + 0.5 * (rpm / p["rpm"][-1])               # exhaust note rises a little with load
    for i in range(N):
        t0 = (i * ivl + p["jit"][i % len(p["jit"])] * ivl * 0.6 + rng.normal(0, 0.012) * ivl) % T
        amp = 1.0 + rng.normal(0, 0.06)
        k = int(t0 * SR)
        L = int(min(0.06, 3.2 * ivl) * SR)
        tt = np.arange(L) / SR
        pulse = np.zeros(L)
        for f, g in p["res"]:
            pulse += g * np.sin(2 * np.pi * f * hz_scale * tt + rng.uniform(0, 0.6)) * np.exp(-tt / (0.0045 + 0.012 / (1 + f / 200)))
        burst = rng.normal(0, 1, L) * np.exp(-tt / 0.0035)
        pulse = amp * (pulse + p["nz"] * 0.8 * burst)
        idx = (k + np.arange(L)) % n
        out[idx] += pulse
    # mechanical / intake layer
    out += p["rasp"] * 0.12 * fft_filter(rng.normal(0, 1, n), 800, 5000) * (0.4 + rpm / p["rpm"][-1])
    d = p["drive"] * (0.6 + 0.8 * rpm / p["rpm"][-1])
    out = out / (np.std(out) + 1e-9)
    out = np.tanh(d * out * 0.8)
    out = fft_filter(out, 35, 7000)
    out = out / (np.sqrt(np.mean(out ** 2)) + 1e-9) * 0.16              # equal loudness for every layer
    return out


for name, p in TYPES.items():
    for li, rpm in enumerate(p["rpm"]):
        x = layer(p, rpm)
        x = np.clip(x, -0.98, 0.98)
        wavfile.write(os.path.join(OUT, f"eng_{name}_{li}.wav"), SR, (x * 32767).astype(np.int16))
print("ok", len(TYPES) * 3, "files")
