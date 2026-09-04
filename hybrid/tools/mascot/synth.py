"""A small additive synthesiser, standard library only.

The bundled sound set was Android's stock tones -- Aldebaran, Altair, Antares, Betelgeuse,
Beat_Box_Android and 61 more, 16 MB of Google's library. These are generated instead, so they
carry no third-party rights.

Design, rather than taste: UI sounds want a fast attack, an exponential decay and a silent
tail, or they click. Partials slightly above pure harmonics give a bell-like timbre without
the clangour of a real bell's inharmonic series. Everything is tuned to one pentatonic scale
so any two sounds heard together are consonant.
"""
import array
import math
import struct
import wave
from pathlib import Path

RATE = 48000

# A major pentatonic on C -- no semitone clashes, so nothing jars when two sounds overlap.
NOTES = {n: 261.63 * 2 ** (s / 12) for n, s in {
    "C4": 0, "D4": 2, "E4": 4, "G4": 7, "A4": 9,
    "C5": 12, "D5": 14, "E5": 16, "G5": 19, "A5": 21, "C6": 24, "E6": 28, "G6": 31,
}.items()}


def _env(i, n, attack=0.004, decay=6.0, release=0.012):
    """Raised-cosine attack, exponential body, cosine release. Starts and ends at zero."""
    t = i / RATE
    total = n / RATE
    a = 0.5 - 0.5 * math.cos(math.pi * min(1.0, t / attack)) if attack > 0 else 1.0
    d = math.exp(-decay * t)
    left = total - t
    r = 0.5 - 0.5 * math.cos(math.pi * min(1.0, left / release)) if release > 0 else 1.0
    return a * d * r


def tone(freq, dur, partials=(1.0, 2.01, 3.02), weights=(1.0, 0.34, 0.12), decay=6.0,
         attack=0.004, detune=0.0):
    """One struck note. `detune` in cents spreads the partials very slightly, which reads as
    warmth rather than as a beat frequency at these durations."""
    n = int(RATE * dur)
    buf = [0.0] * n
    for p, w in zip(partials, weights):
        f = freq * p * (2 ** (detune / 1200))
        step = 2 * math.pi * f / RATE
        for i in range(n):
            buf[i] += w * math.sin(step * i)
    for i in range(n):
        buf[i] *= _env(i, n, attack, decay)
    return buf


def noise(dur, decay=40.0, seed=7, attack=0.0015):
    """Deterministic pseudo-noise for the shutter. A fixed seed keeps builds reproducible.

    The attack ramp is not optional. Without it the first sample is an arbitrary value and
    the jump from silence to it is a discontinuity -- an audible click in front of the sound
    that is supposed to *be* the click.
    """
    n = int(RATE * dur)
    na = max(1, int(RATE * attack))
    buf = [0.0] * n
    x = seed
    for i in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        a = 0.5 - 0.5 * math.cos(math.pi * min(1.0, i / na))
        buf[i] = ((x / 0x3FFFFFFF) - 1.0) * a * math.exp(-decay * i / RATE)
    return buf


def seq(*parts):
    """Overlay (offset_seconds, samples) pairs onto one buffer."""
    end = max(int(off * RATE) + len(s) for off, s in parts)
    out = [0.0] * end
    for off, s in parts:
        o = int(off * RATE)
        for i, v in enumerate(s):
            out[o + i] += v
    return out


def write(path, buf, peak=0.72):
    """Normalise to `peak` (headroom, so nothing clips downstream) and write 16-bit mono."""
    m = max(abs(v) for v in buf) or 1.0
    g = peak / m
    data = array.array("h", (int(max(-1.0, min(1.0, v * g)) * 32767) for v in buf))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    return len(buf) / RATE
