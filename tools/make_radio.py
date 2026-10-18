"""Synthesises the in-car radio stations (no external assets). Run: python3 tools/make_radio.py
Five stations, every one is a seamless ~25-30 s loop (22.05 kHz mono)."""
import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter, butter, fftconvolve
import os

SR = 22050
rng = np.random.default_rng(2024)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "radio")
os.makedirs(OUT, exist_ok=True)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def lp(x, fc, order=2):
    b, a = butter(order, min(fc, SR * 0.45) / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), "high")
    return lfilter(b, a, x)


def bp(x, lo_, hi_):
    b, a = butter(2, [lo_ / (SR / 2), min(hi_, SR * 0.45) / (SR / 2)], "band")
    return lfilter(b, a, x)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.1):
    e = np.ones(n)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = max(1, min(na, n))
    e[:na] = np.linspace(0, 1, na)
    if nd > 0 and na + nd < n:
        e[na:na + nd] = np.linspace(1, s, nd)
        e[na + nd:] = s
    else:
        e[na:] = s
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def saw(f, n, detune=0.0):
    t = np.arange(n) / SR
    x = 2 * ((t * f) % 1.0) - 1
    if detune:
        x = 0.5 * x + 0.5 * (2 * ((t * f * (1 + detune)) % 1.0) - 1)
    return x


def square(f, n, pw=0.5):
    t = np.arange(n) / SR
    return np.where(((t * f) % 1.0) < pw, 1.0, -1.0)


def tri(f, n):
    t = np.arange(n) / SR
    return 2 * np.abs(2 * ((t * f) % 1.0) - 1) - 1


def sine(f, n):
    return np.sin(2 * np.pi * f * np.arange(n) / SR)


def pluck(f, dur, damp=0.5):
    """Karplus-Strong string (oud / guitar-ish)"""
    n = int(dur * SR)
    d = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, d)
    buf = lp(buf, 3500)
    out = np.zeros(n)
    k = 0
    for i in range(n):
        out[i] = buf[k]
        nxt = (k + 1) % d
        buf[k] = (buf[k] + buf[nxt]) * 0.5 * (0.996 - 0.0 * damp)
        k = nxt
    return out


def reverb(x, secs=1.2, wet=0.25, bright=0.5):
    n = int(secs * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (secs * SR / 4.0))
    ir = lp(ir, 6000 * bright + 1500)
    ir /= np.sqrt(np.sum(ir ** 2))
    y = fftconvolve(x, ir)[: len(x) + n]
    return y, wet


class Song:
    def __init__(self, bpm, bars, beats=4):
        self.bpm = bpm
        self.bars = bars
        self.beat = 60.0 / bpm
        self.bar = self.beat * beats
        self.n = int(self.bar * bars * SR)
        self.tail = int(2.5 * SR)
        self.tracks = {}

    def buf(self, name):
        if name not in self.tracks:
            self.tracks[name] = np.zeros(self.n + self.tail)
        return self.tracks[name]

    def put(self, name, x, t, gain=1.0):
        b = self.buf(name)
        i = int(t * SR)
        if i >= len(b):
            return
        j = min(len(b), i + len(x))
        b[i:j] += x[: j - i] * gain

    def render(self, mix, rev=None, master=0.9):
        total = np.zeros(self.n + self.tail)
        for name, gain in mix.items():
            x = self.tracks.get(name)
            if x is None:
                continue
            if rev and name in rev:
                wetx, w = reverb(x, rev[name][0], rev[name][1])
                x = x + w * wetx[: len(x)]
            total += x * gain
        # fold the tail so the loop is seamless
        out = total[: self.n].copy()
        tail = total[self.n:]
        out[: len(tail)] += tail[: len(out)]
        out = np.tanh(out * 0.9)
        out = out / (np.max(np.abs(out)) + 1e-9) * master
        return out


def kick(vol=1.0, punch=1.0):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 28)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    x += 0.35 * punch * lp(rng.normal(0, 1, n), 800) * np.exp(-t * 70)
    return x * vol


def snare(vol=1.0, tone=190):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    x = hp(rng.normal(0, 1, n), 900) * np.exp(-t * 20) * 0.9
    x += np.sin(2 * np.pi * tone * t) * np.exp(-t * 30) * 0.6
    return x * vol


def clap(vol=1.0):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for off in [0.0, 0.012, 0.024, 0.038]:
        i = int(off * SR)
        x[i:] += bp(rng.normal(0, 1, n - i), 900, 3800) * np.exp(-t[: n - i] * 40)
    x += bp(rng.normal(0, 1, n), 900, 3000) * np.exp(-t * 14) * 0.3
    return x * vol


def hat(vol=1.0, open_=False):
    n = int((0.22 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    x = hp(rng.normal(0, 1, n), 7000) * np.exp(-t * (14 if open_ else 80))
    return x * vol


def darbuka(kind, vol=1.0):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    if kind == "dum":
        f = 90 + 60 * np.exp(-t * 35)
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 13)
        x += 0.25 * lp(rng.normal(0, 1, n), 500) * np.exp(-t * 60)
    elif kind == "tek":
        x = bp(rng.normal(0, 1, n), 1800, 4500) * np.exp(-t * 55)
        x += 0.5 * np.sin(2 * np.pi * 620 * t) * np.exp(-t * 60)
    else:  # ka
        x = bp(rng.normal(0, 1, n), 2500, 6000) * np.exp(-t * 80)
        x += 0.3 * np.sin(2 * np.pi * 880 * t) * np.exp(-t * 90)
    return x * vol


def note_synth(kind, nn, dur, vol=1.0, **k):
    f = midi(nn)
    n = int(dur * SR)
    if kind == "bass_saw":
        x = lp(saw(f, n), 600 + k.get("cut", 0)) * adsr(n, 0.005, 0.1, 0.8, 0.05)
    elif kind == "bass_sub":
        x = (sine(f, n) + 0.3 * sine(2 * f, n)) * adsr(n, 0.005, 0.1, 0.9, 0.05)
    elif kind == "pad":
        x = lp(saw(f, n, 0.006) + saw(f * 0.5, n, 0.004) * 0.6, k.get("cut", 1800)) * adsr(n, 0.35, 0.3, 0.8, 0.5)
    elif kind == "lead":
        x = lp(saw(f, n, 0.004) + 0.5 * square(f * 2, n, 0.35), k.get("cut", 3500)) * adsr(n, 0.01, 0.15, 0.7, 0.12)
        x *= 1.0 + 0.04 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR)
    elif kind == "arp":
        x = lp(square(f, n, 0.4), k.get("cut", 3000)) * adsr(n, 0.003, 0.12, 0.25, 0.05)
    elif kind == "epiano":
        t = np.arange(n) / SR
        mod = np.sin(2 * np.pi * f * 2 * t) * 1.4 * np.exp(-t * 4)
        x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 1.6) + 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 9)
        x *= adsr(n, 0.004, 0.2, 0.9, 0.12)
    elif kind == "stab":
        x = lp(saw(f, n, 0.01) + saw(f * 2, n) * 0.4, 2600) * adsr(n, 0.002, 0.12, 0.1, 0.06)
    elif kind == "guitar":
        x = np.tanh(3.5 * lp(saw(f, n, 0.003) + 0.7 * saw(f * 1.4983, n), 3000)) * adsr(n, 0.004, 0.08, 0.85, 0.06)
    elif kind == "strings":
        x = lp(saw(f, n, 0.01) + saw(f, n, -0.008), 2400) * adsr(n, 0.25, 0.2, 0.8, 0.4)
        x *= 1.0 + 0.03 * np.sin(2 * np.pi * 5.0 * np.arange(n) / SR)
    else:
        x = sine(f, n)
    return x * vol


# =============================================================== 1. RALLY FM (rock)
def rally_fm():
    s = Song(138, 16)
    prog = [(45, 52), (41, 48), (48, 55), (43, 50)]   # Am F C G  (root, fifth)
    for bar in range(s.bars):
        r, f5 = prog[(bar // 2) % 4]
        t0 = bar * s.bar
        # drums
        for b in range(4):
            tb = t0 + b * s.beat
            if b in (0, 2) or (bar % 4 == 3 and b == 3):
                s.put("kick", kick(1.0), tb)
            if b in (1, 3):
                s.put("snare", snare(1.0), tb)
            for h in (0, 0.5):
                s.put("hat", hat(0.45 if h else 0.7), tb + h * s.beat)
            if bar % 4 == 3 and b == 3:
                for q in (0.5, 0.75):
                    s.put("snare", snare(0.6), tb + q * s.beat)
        # driving 8th bass
        for e in range(8):
            s.put("bass", note_synth("bass_saw", r, s.beat * 0.5 * 0.92, 0.9, cut=250), t0 + e * s.beat * 0.5)
        # power chords, palm-muted on 8ths in the chorus (bars 8-15), long in the verse
        for nn in (r + 12, f5 + 12, r + 24):
            if bar >= 8:
                for e in range(8):
                    s.put("gtr", note_synth("guitar", nn, s.beat * 0.5 * (0.55 if e % 4 else 0.9), 0.35), t0 + e * s.beat * 0.5)
            else:
                s.put("gtr", note_synth("guitar", nn, s.bar * 0.98, 0.28), t0)
        # lead riff in the second half
        if bar >= 4:
            riff = [0, 3, 5, 7, 5, 3, 0, -2] if bar % 2 == 0 else [0, 3, 5, 3, 7, 5, 3, 5]
            for e, iv in enumerate(riff):
                s.put("lead", note_synth("lead", r + 36 + iv, s.beat * 0.45, 0.28, cut=3000), t0 + e * s.beat * 0.5)
        if bar % 8 == 0:
            s.put("crash", hat(1.0, True) * 3.0, t0)
    return s.render({"kick": 0.95, "snare": 0.7, "hat": 0.35, "bass": 0.55, "gtr": 0.55, "lead": 0.5, "crash": 0.3},
                    rev={"snare": (0.7, 0.3), "lead": (0.9, 0.3), "gtr": (0.6, 0.15)})


# =============================================================== 2. NIGHT DRIVE (synthwave)
def night_drive():
    s = Song(100, 12)
    prog = [(41, [0, 3, 7]), (37, [0, 4, 7]), (44, [0, 4, 7]), (39, [0, 4, 7])]  # Fm Db Ab Eb
    mel = [12, 10, 7, 8, 7, 3, 0, 3]
    for bar in range(s.bars):
        r, tri_ = prog[bar % 4]
        t0 = bar * s.bar
        for b in range(4):
            tb = t0 + b * s.beat
            s.put("kick", kick(0.9), tb) if b % 2 == 0 else None
            if b in (1, 3):
                s.put("snare", snare(0.9, 210), tb)
                s.put("clap", clap(0.6), tb)
            s.put("hat", hat(0.5), tb + 0.5 * s.beat)
        # pulsing bass
        for e in range(8):
            s.put("bass", note_synth("bass_saw", r, s.beat * 0.45, 0.9, cut=500), t0 + e * s.beat * 0.5)
        # arpeggio 16ths
        for e in range(16):
            iv = tri_[(e * 2 + (e // 4)) % 3] + (12 if e % 4 >= 2 else 0)
            s.put("arp", note_synth("arp", r + 24 + iv, s.beat * 0.22, 0.3, cut=2800), t0 + e * s.beat * 0.25)
        # pad
        for iv in tri_:
            s.put("pad", note_synth("pad", r + 24 + iv, s.bar * 1.0, 0.22, cut=1500), t0)
        # lead melody (bars 4..11)
        if bar >= 4:
            for e, iv in enumerate(mel):
                if (e + bar) % 4 == 3:
                    continue
                s.put("lead", note_synth("lead", r + 36 + iv - (12 if bar % 4 == 2 else 0), s.beat * 0.9, 0.3, cut=3200), t0 + e * s.beat * 0.5)
    return s.render({"kick": 0.9, "snare": 0.55, "clap": 0.5, "hat": 0.28, "bass": 0.6, "arp": 0.4, "pad": 0.55, "lead": 0.5},
                    rev={"snare": (1.4, 0.5), "clap": (1.4, 0.5), "lead": (1.5, 0.45), "pad": (2.0, 0.3), "arp": (0.8, 0.25)})


# =============================================================== 3. SAHARA WAVES (hijaz / darbuka)
def sahara():
    s = Song(96, 12)
    # D hijaz: D Eb F# G A Bb C
    D = 50
    sc = [0, 1, 4, 5, 7, 8, 10, 12, 13, 16, 17, 19]
    phrases = [
        [7, 8, 7, 5, 4, 5, 4, 1],
        [4, 5, 7, 8, 10, 8, 7, 5],
        [12, 10, 8, 7, 8, 7, 5, 4],
        [5, 4, 1, 0, 1, 4, 1, 0],
    ]
    rhythm = {0: "dum", 1.0: "tek", 1.5: "tek", 2.0: "dum", 2.5: "dum", 3.0: "tek"}   # maqsum
    for bar in range(s.bars):
        t0 = bar * s.bar
        for pos, kind in rhythm.items():
            s.put("perc", darbuka(kind, 1.0), t0 + pos * s.beat)
        for pos in (0.5, 3.5):
            s.put("perc", darbuka("ka", 0.5), t0 + pos * s.beat)
        s.put("drone", note_synth("strings", D - 12, s.bar * 1.0, 0.3), t0)
        s.put("drone", note_synth("strings", D - 5, s.bar * 1.0, 0.22), t0)
        if bar >= 2:
            ph = phrases[(bar // 2) % 4] if bar % 2 == 0 else phrases[(bar // 2) % 4][::-1]
            for e, iv in enumerate(ph):
                dur = s.beat * 0.48
                s.put("oud", pluck(midi(D + 12 + iv), dur * 2.2) * 0.9, t0 + e * s.beat * 0.5)
        else:
            s.put("oud", pluck(midi(D + 12 + 4), s.beat * 3) * 0.7, t0)
            s.put("oud", pluck(midi(D + 12 + 7), s.beat * 3) * 0.7, t0 + 2 * s.beat)
        if bar % 4 >= 2:
            for e, iv in enumerate([0, 1, 4, 5]):
                s.put("str", note_synth("strings", D + 24 + iv, s.beat * 0.95, 0.12), t0 + e * s.beat)
    return s.render({"perc": 0.85, "drone": 0.5, "oud": 0.75, "str": 0.5}, rev={"oud": (1.3, 0.35), "str": (1.8, 0.4), "perc": (0.5, 0.1)})


# =============================================================== 4. LO-FI GARAGE
def lofi():
    s = Song(80, 10)
    chords = [(48, [0, 4, 7, 11]), (45, [0, 3, 7, 10]), (50, [0, 3, 7, 10]), (43, [0, 4, 7, 10])]   # Cmaj7 Am7 Dm7 G7
    for bar in range(s.bars):
        r, ch = chords[bar % 4]
        t0 = bar * s.bar
        # swung drums
        s.put("kick", kick(0.8, 0.6), t0)
        s.put("kick", kick(0.7, 0.6), t0 + 2.5 * s.beat)
        s.put("snare", snare(0.55, 170), t0 + 1 * s.beat)
        s.put("snare", snare(0.55, 170), t0 + 3 * s.beat)
        for e in range(8):
            sw = 0.1 * s.beat if e % 2 else 0.0
            s.put("hat", hat(0.35 + 0.15 * (e % 2)), t0 + e * s.beat * 0.5 + sw)
        # rhodes chords with a lazy strum
        for k, iv in enumerate(ch):
            s.put("keys", note_synth("epiano", r + 12 + iv, s.beat * 3.5, 0.3), t0 + k * 0.025 + (0.5 * s.beat if bar % 2 else 0.0) * 0)
            if bar % 2 == 1:
                s.put("keys", note_synth("epiano", r + 24 + iv, s.beat * 1.2, 0.18), t0 + 2.0 * s.beat + k * 0.03)
        s.put("bass", note_synth("bass_sub", r - 12, s.beat * 1.8, 0.9), t0)
        s.put("bass", note_synth("bass_sub", r - 12 + 7, s.beat * 1.4, 0.8), t0 + 2.5 * s.beat)
        # sparse melody
        if bar >= 2 and bar % 2 == 0:
            for e, iv in enumerate([12, 11, 7, 9]):
                s.put("mel", note_synth("epiano", r + 24 + iv, s.beat * 0.9, 0.22), t0 + (e * 1.0 + 0.5) * s.beat)
    # vinyl crackle
    n = s.n + s.tail
    crackle = np.zeros(n)
    for pos in rng.integers(0, n - 300, 260):
        L = int(rng.integers(30, 160))
        crackle[pos:pos + L] += rng.normal(0, 1, L) * np.exp(-np.arange(L) / 18.0) * rng.uniform(0.1, 0.8)
    s.tracks["crackle"] = hp(crackle, 1500) * 0.5 + 0.02 * lp(rng.normal(0, 1, n), 4000)
    out = s.render({"kick": 0.8, "snare": 0.6, "hat": 0.3, "keys": 0.75, "bass": 0.6, "mel": 0.5, "crackle": 0.4},
                   rev={"keys": (1.4, 0.35), "mel": (1.4, 0.4), "snare": (0.6, 0.2)})
    return lp(out, 5200)          # tape-dull


# =============================================================== 5. TURBO BEATS (house)
def turbo():
    s = Song(128, 14)
    prog = [(45, [0, 3, 7, 10]), (45, [0, 3, 7, 10]), (41, [0, 4, 7, 11]), (43, [0, 4, 7, 10])]   # Am7 Am7 Fmaj7 G7
    for bar in range(s.bars):
        r, ch = prog[(bar // 1) % 4]
        t0 = bar * s.bar
        build = 4 <= bar < 8
        for b in range(4):
            tb = t0 + b * s.beat
            s.put("kick", kick(1.0, 1.2), tb)
            s.put("hat", hat(0.8, True), tb + 0.5 * s.beat)
            if b in (1, 3) and bar >= 2:
                s.put("clap", clap(0.8), tb)
        if build:
            for e in range(16):
                s.put("hat", hat(0.25 + 0.04 * e), t0 + e * s.beat * 0.25)
        # side-chained pump on the bass / chords (volume dips on every kick)
        for e in range(8):
            ts = t0 + e * s.beat * 0.5
            if e % 2 == 1:
                s.put("bass", note_synth("bass_saw", r - 12 + (12 if e % 4 == 3 else 0), s.beat * 0.4, 0.85, cut=300), ts)
        for k, iv in enumerate(ch):
            for e in (1, 3, 5, 7) if bar % 2 == 0 else (0, 3, 6):
                s.put("stab", note_synth("stab", r + 24 + iv, s.beat * 0.4, 0.2), t0 + e * s.beat * 0.5)
        if bar >= 8:
            for e, iv in enumerate([0, 7, 12, 10, 7, 3, 7, 10]):
                s.put("lead", note_synth("lead", r + 36 + iv, s.beat * 0.4, 0.22, cut=3500), t0 + e * s.beat * 0.5)
    # sidechain ducking applied to melodic tracks
    n = s.n + s.tail
    duck = np.ones(n)
    for bar in range(s.bars):
        for b in range(4):
            i = int((bar * s.bar + b * s.beat) * SR)
            L = int(0.22 * SR)
            duck[i:i + L] = np.minimum(duck[i:i + L], np.linspace(0.15, 1.0, min(L, n - i)))
    for name in ("bass", "stab", "lead"):
        if name in s.tracks:
            s.tracks[name] = s.tracks[name] * duck
    return s.render({"kick": 1.0, "hat": 0.3, "clap": 0.55, "bass": 0.75, "stab": 0.6, "lead": 0.5},
                    rev={"stab": (0.9, 0.3), "lead": (1.0, 0.35), "clap": (0.6, 0.3)})


def save(name, x):
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    print(name, round(len(x) / SR, 1), "s")


if __name__ == "__main__":
    import sys
    which = sys.argv[1:] or ["rally", "night", "sahara", "lofi", "turbo"]
    fns = {"rally": rally_fm, "night": night_drive, "sahara": sahara, "lofi": lofi, "turbo": turbo}
    for w in which:
        save("st_" + w, fns[w]())
