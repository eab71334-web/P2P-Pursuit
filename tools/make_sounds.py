"""Generates every sound effect of the game (no external assets). Run: python3 tools/make_sounds.py"""
import numpy as np
from scipy.io import wavfile
import os

SR = 22050
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
os.makedirs(OUT, exist_ok=True)


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def periodic_noise(seconds, lo, hi, slope=0.0):
    """noise that loops perfectly: built in the frequency domain"""
    n = int(SR * seconds)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    mag = ((freqs >= lo) & (freqs <= hi)).astype(float)
    mag *= (np.maximum(freqs, 1.0) / 1000.0) ** slope
    # soft edges
    mag *= np.clip((freqs - lo * 0.7) / (lo * 0.3 + 1e-9), 0, 1) if lo > 0 else 1
    ph = rng.uniform(0, 2 * np.pi, len(freqs))
    return np.fft.irfft(mag * np.exp(1j * ph), n)


def env_decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


# ---------------------------------------------------------------- engine (1 s loop, 56 Hz fundamental)
t = np.arange(SR) / SR
f0 = 56.0
x = np.zeros_like(t)
for k in range(1, 16):
    amp = 1.0 / (k ** 0.85)
    if k % 2 == 0:
        amp *= 1.25                       # V8-ish burble
    x += amp * np.sin(2 * np.pi * k * f0 * t + k * 0.7)
am = 1.0 + 0.35 * np.sin(2 * np.pi * (f0 / 2) * t) + 0.12 * np.sin(2 * np.pi * (f0 / 4) * t + 1.0)
x = x * am
x /= np.max(np.abs(x))
x = np.tanh(2.6 * x)                      # rasp
x += 0.22 * periodic_noise(1.0, 90, 1100) / 0.3
save("engine_loop", x)

# intake / turbo whoosh
save("intake_loop", periodic_noise(1.5, 700, 4200, slope=-0.5))
# road rumble + gravel crackle
r = periodic_noise(2.0, 20, 320) * 1.0
g = np.zeros(2 * SR)
for pos in rng.integers(0, 2 * SR, 220):
    L = 140
    seg = rng.normal(0, 1, L) * env_decay(L, 0.004) * rng.uniform(0.2, 1.0)
    idx = (pos + np.arange(L)) % (2 * SR)
    g[idx] += seg
save("road_loop", r / np.max(np.abs(r)) * 0.7 + g / np.max(np.abs(g)) * 0.5)
# tyre skid
sk = periodic_noise(1.5, 1200, 3800)
sk *= 1.0 + 0.4 * np.sin(2 * np.pi * 9 * np.arange(len(sk)) / SR)
save("skid_loop", sk)

# ---------------------------------------------------------------- crashes
def crash(dur, hard):
    n = int(SR * dur)
    tt = np.arange(n) / SR
    noise = rng.normal(0, 1, n) * env_decay(n, 0.10 if hard else 0.05)
    thump = np.sin(2 * np.pi * (70 - 35 * tt / dur) * tt) * env_decay(n, 0.18 if hard else 0.08)
    ring = sum(np.sin(2 * np.pi * f * tt) * env_decay(n, tau) * a for f, tau, a in [(410, 0.25, 0.35), (623, 0.18, 0.25), (1140, 0.1, 0.2), (2210, 0.06, 0.12)])
    return 0.8 * noise + 1.2 * thump + (0.7 if hard else 0.4) * ring
save("crash_hard", crash(1.0, True))
save("crash_soft", crash(0.45, False))
# explosion
n = int(SR * 2.0)
tt = np.arange(n) / SR
boom = rng.normal(0, 1, n) * env_decay(n, 0.35) + 1.6 * np.sin(2 * np.pi * (55 - 25 * tt / 2.0) * tt) * env_decay(n, 0.5)
save("boom", boom)

# ---------------------------------------------------------------- fire / extinguisher
fl = periodic_noise(2.0, 30, 420) * 0.7
cr = np.zeros(2 * SR)
for pos in rng.integers(0, 2 * SR, 260):
    L = int(SR * 0.006)
    seg = rng.normal(0, 1, L) * env_decay(L, 0.0015) * rng.uniform(0.15, 1.0)
    idx = (pos + np.arange(L)) % (2 * SR)
    cr[idx] += seg
save("fire_loop", fl / np.max(np.abs(fl)) * 0.6 + cr / np.max(np.abs(cr)))
hs = periodic_noise(1.0, 1800, 9000) + 0.4 * periodic_noise(1.0, 150, 700)
save("spray_loop", hs)
sm = periodic_noise(1.5, 2500, 7000)
save("smoke_hiss", sm * 0.6)

# ---------------------------------------------------------------- mechanical clicks / thuds
def click():
    out = np.zeros(int(SR * 0.16))
    for pos, a in [(0, 1.0), (int(SR * 0.07), 0.7)]:
        L = int(SR * 0.012)
        seg = (rng.normal(0, 1, L) * 0.5 + np.sin(2 * np.pi * 2400 * np.arange(L) / SR)) * env_decay(L, 0.002) * a
        out[pos:pos + L] += seg
    return out
save("click", click())
n = int(SR * 0.4)
tt = np.arange(n) / SR
save("thud", np.sin(2 * np.pi * (95 - 50 * tt / 0.4) * tt) * env_decay(n, 0.12) + 0.25 * rng.normal(0, 1, n) * env_decay(n, 0.03))
n = int(SR * 0.7)
tt = np.arange(n) / SR
save("clang", sum(np.sin(2 * np.pi * f * tt) * env_decay(n, tau) * a for f, tau, a in [(520, 0.3, 1.0), (781, 0.22, 0.6), (1303, 0.15, 0.4), (2011, 0.08, 0.25)]) + 0.3 * rng.normal(0, 1, n) * env_decay(n, 0.01))
# horn-like beeps
def tone(f, dur, fade=0.01):
    n = int(SR * dur)
    tt = np.arange(n) / SR
    e = np.minimum(1, tt / fade) * np.minimum(1, (dur - tt) / 0.05)
    return (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)) * e
save("beep", tone(880, 0.18))
save("go", tone(1320, 0.55))
chime = np.concatenate([tone(f, 0.16) for f in (660, 880, 1320)])
save("success", chime)
warn = np.concatenate([tone(740, 0.12), np.zeros(int(SR * 0.05)), tone(740, 0.12)])
save("warn", warn)
print("done", sorted(os.listdir(OUT)))

# ---------------------------------------------------------------- gearbox: lever slide + gate "clunk" (manual / auto) and a soft detent (buttons)
def gear_sound(heavy):
    n = int(SR * 0.32)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    L = int(SR * 0.09)                                   # lever scraping through the gate
    out[:L] += rng.normal(0, 1, L) * np.hanning(L) * 0.18
    p = int(SR * 0.09)                                   # the clunk when it lands in the gate
    m = n - p
    t2 = np.arange(m) / SR
    body = np.sin(2 * np.pi * (150 if heavy else 210) * t2) * env_decay(m, 0.045)
    knock = rng.normal(0, 1, m) * env_decay(m, 0.006) * 0.7
    ring = np.sin(2 * np.pi * 1850 * t2) * env_decay(m, 0.012) * 0.25
    out[p:] += body + knock + ring
    return out
save("gear_clunk", gear_sound(True), 0.8)
save("gear_tick", gear_sound(False), 0.6)
