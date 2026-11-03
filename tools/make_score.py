"""Synthesises the interactive race score (no external assets). Run: python3 tools/make_score.py
Three seamless 16 s stems (120 BPM, 8 bars, Am-F-C-G) that play in sync and fade in/out with speed,
plus short stingers (crash / win / lose). Output: audio/score_*.wav and audio/stinger_*.wav (22.05 kHz mono)."""
import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter, butter
import os

SR = 22050
BPM = 120
BEAT = 60.0 / BPM
BARS = 8
N = int(SR * BEAT * 4 * BARS)
rng = np.random.default_rng(77)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def lp(x, fc):
    b, a = butter(2, min(fc, SR * 0.45) / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, fc):
    b, a = butter(2, fc / (SR / 2), "high")
    return lfilter(b, a, x)


def env(n, a=0.01, r=0.1):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / max(r, 1e-3))
    return e


def add(buf, x, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def tone(f, dur, kind="saw", vol=1.0, a=0.01, r=0.2):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "saw":
        x = 2 * ((f * t) % 1.0) - 1
        x = lp(x, 2500)
    elif kind == "sq":
        x = np.sign(np.sin(2 * np.pi * f * t)) * 0.6
        x = lp(x, 2200)
    else:
        x = np.sin(2 * np.pi * f * t)
    return x * env(n, a, r) * vol


def kick(vol=1.0):
    n = int(SR * 0.28)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vol


def snare(vol=1.0):
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    x = hp(rng.normal(0, 1, n), 1500) * np.exp(-t * 22) + 0.4 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return x * vol


def hat(vol=1.0, open_=False):
    n = int(SR * (0.18 if open_ else 0.05))
    t = np.arange(n) / SR
    return hp(rng.normal(0, 1, n), 6500) * np.exp(-t * (18 if open_ else 70)) * vol


# chords per 2 bars: Am F C G (root midi, minor/major triad)
PROG = [(57, [0, 3, 7]), (53, [0, 4, 7]), (60, [0, 4, 7]), (55, [0, 4, 7])]


def fix_loop(x):
    """seamless: tiny fade at both ends"""
    f = int(SR * 0.004)
    x = x.copy()
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


# ---- stem 1: calm pad + sub (always on)
calm = np.zeros(N)
for ci, (root, ints) in enumerate(PROG):
    start = ci * 2 * 4 * BEAT
    for k in ints:
        add(calm, tone(midi(root + k), 8 * BEAT, "saw", 0.25, a=0.6, r=6.0), start)
        add(calm, tone(midi(root + k + 12), 8 * BEAT, "sin", 0.12, a=0.8, r=6.0), start)
    add(calm, tone(midi(root - 24), 8 * BEAT, "sin", 0.6, a=0.05, r=5.0), start)
calm = lp(calm, 1800)
save("score_calm", fix_loop(calm), 0.7)

# ---- stem 2: drive - four on the floor, off-beat hats, pulsing bass
drive = np.zeros(N)
for bar in range(BARS):
    ci = bar // 2
    root = PROG[ci][0] - 24
    for beat in range(4):
        t0 = (bar * 4 + beat) * BEAT
        add(drive, kick(0.9), t0)
        add(drive, hat(0.35), t0 + BEAT / 2)
        for e in range(2):
            add(drive, tone(midi(root + (0 if e == 0 else 12)), BEAT / 2, "saw", 0.4, a=0.005, r=0.12), t0 + e * BEAT / 2)
    add(drive, snare(0.5), (bar * 4 + 1) * BEAT)
    add(drive, snare(0.5), (bar * 4 + 3) * BEAT)
save("score_drive", fix_loop(drive), 0.8)

# ---- stem 3: intense - 16th arpeggio lead + driving hats + open hat + riser on the last bar
inten = np.zeros(N)
for bar in range(BARS):
    root, ints = PROG[bar // 2]
    notes = [root + 12 + ints[0], root + 12 + ints[1], root + 12 + ints[2], root + 24 + ints[0]]
    for s in range(16):
        t0 = (bar * 16 + s) * BEAT / 4
        add(inten, tone(midi(notes[s % 4]), BEAT / 4, "sq", 0.3, a=0.003, r=0.09), t0)
        if s % 2 == 0:
            add(inten, hat(0.3), t0)
    add(inten, hat(0.5, True), (bar * 4 + 2) * BEAT + BEAT / 2)
n = int(SR * BEAT * 4)
rise = hp(rng.normal(0, 1, n), 800) * np.linspace(0, 1, n) ** 2 * 0.5
add(inten, rise, (BARS - 1) * 4 * BEAT)
save("score_intense", fix_loop(inten), 0.7)

# ---- stingers
n = int(SR * 1.4)
t = np.arange(n) / SR
cr = (np.sin(2 * np.pi * 55 * t) + 0.7 * np.sin(2 * np.pi * 58.3 * t) + 0.5 * np.sin(2 * np.pi * 82.4 * t * (1 - 0.1 * t))) * np.exp(-t * 3.2)
cr += hp(rng.normal(0, 1, n), 400) * np.exp(-t * 14) * 0.6
save("stinger_crash", cr, 0.85)
win = np.zeros(int(SR * 2.2))
for i, k in enumerate([0, 4, 7, 12, 16, 19, 24]):
    add(win, tone(midi(67 + k), 1.4, "sq", 0.5, a=0.005, r=0.5) + tone(midi(55 + k), 1.4, "saw", 0.3, a=0.005, r=0.6), i * 0.11)
save("stinger_win", win, 0.8)
lose = np.zeros(int(SR * 2.0))
for i, k in enumerate([0, -2, -5, -9]):
    add(lose, tone(midi(64 + k), 1.2, "saw", 0.5, a=0.01, r=0.5), i * 0.28)
save("stinger_lose", lose, 0.75)
print("ok")
