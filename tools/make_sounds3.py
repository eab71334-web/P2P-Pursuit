"""Horn + wiper sounds. Run: python3 tools/make_sounds3.py"""
import numpy as np, os
from scipy.io import wavfile
SR = 22050
rng = np.random.default_rng(11)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
def save(name, x, gain=0.85):
    x = np.asarray(x, float); x = x / (np.abs(x).max() + 1e-9) * gain
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))
# horn: two buzzy reed tones (a third apart) with a quick attack and a short release
n = int(SR * 0.55); t = np.arange(n) / SR
def reed(f):
    return sum(np.sin(2 * np.pi * f * k * t + 0.3 * k) / k for k in range(1, 9))
env = np.minimum(1, t / 0.02) * np.minimum(1, (0.55 - t) / 0.08)
save("horn", (reed(415) + reed(523) * 0.9) * env)
# wiper: rubber swish (filtered noise, rises and falls) + a soft motor tick
n = int(SR * 0.7); t = np.arange(n) / SR
nz = rng.normal(0, 1, n)
k = np.ones(40) / 40
lp = np.convolve(nz, k, "same")
sw = lp * np.sin(np.pi * t / 0.7) ** 2
tick = np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.03) * 0.5
save("wiper", sw * 3.0 + tick, 0.6)
# sip / gulp: two soft low "glug" bursts
n = int(SR * 0.9); t = np.arange(n) / SR
out = np.zeros(n)
for t0 in (0.05, 0.45):
    i0 = int(t0 * SR); L = int(0.28 * SR); tt = np.arange(L) / SR
    f = 190 - 90 * tt / 0.28
    g = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.28) ** 1.5
    g += 0.25 * rng.normal(0, 1, L) * np.sin(np.pi * tt / 0.28) ** 3
    out[i0:i0 + L] += g
save("sip", out, 0.7)
# can opening: short fizz
n = int(SR * 0.5); t = np.arange(n) / SR
fz = rng.normal(0, 1, n) * np.exp(-t / 0.15)
fz = np.convolve(fz, np.ones(4) / 4, "same") - np.convolve(fz, np.ones(30) / 30, "same")
pop = np.sin(2 * np.pi * 900 * t) * np.exp(-t / 0.01)
save("fizz", fz * 0.8 + pop * 0.6, 0.6)
# turn-signal ticks (one sound per kind; the game plays "tick" at normal pitch and "tock" a bit lower)
def clack(f0, f1, dur, noise, tau):
    n = int(SR * dur); t = np.arange(n) / SR
    body = np.sin(2 * np.pi * (f0 + (f1 - f0) * t / dur) * t) * np.exp(-t / tau)
    return body + noise * rng.normal(0, 1, n) * np.exp(-t / (tau * 0.25))
save("sig_relay", clack(1500, 800, 0.07, 0.9, 0.012), 0.8)      # old mechanical relay
save("sig_heavy", clack(420, 180, 0.12, 0.7, 0.03), 0.9)        # big deep thunk
save("sig_soft", clack(2600, 2200, 0.035, 0.25, 0.006), 0.55)   # quiet electronic tick
n = int(SR * 0.06); t = np.arange(n) / SR
save("sig_beep", np.sin(2 * np.pi * 1700 * t) * np.minimum(1, t / 0.003) * np.exp(-t / 0.03), 0.6)
