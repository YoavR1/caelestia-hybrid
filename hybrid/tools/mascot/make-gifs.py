#!/usr/bin/env python3
"""Render the two bundled GIFs from the same mascot.

media   (paths.mediaGif)   sits under the dashboard's player controls. AnimatedImage drives
                           its speed from Audio.beatTracker.bpm, so the loop has to read as a
                           beat: a clear down-and-up bounce with squash on the landing, not a
                           smooth drift. 12 frames divide evenly into common time.
session (paths.sessionGif) sits in the session menu, where nothing is playing and nothing is
                           urgent. A slow drift and a blink.
"""
import subprocess, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparkle import sparkle

ROOT = Path(__file__).resolve().parents[3]


def render(frames, out, delay, w, h):
    with tempfile.TemporaryDirectory() as td:
        pngs = []
        for i, kw in enumerate(frames):
            svg = Path(td) / f"{i:02d}.svg"
            png = Path(td) / f"{i:02d}.png"
            svg.write_text(sparkle(w=w, h=h, **kw))
            subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), str(svg), "-o", str(png)], check=True)
            pngs.append(str(png))
        subprocess.run(["magick", "-dispose", "background", "-delay", str(delay), "-loop", "0",
                        *pngs, str(out)], check=True)
    print(f"{len(frames)} frames -> {out.relative_to(ROOT)}")


def bounce(n=12):
    """One beat: fall, land with a squash, recover, float back up."""
    import math
    out = []
    for i in range(n):
        t = i / n
        # a quick fall and a slow float, so the landing lands on the beat
        y = math.sin(t * 2 * math.pi - math.pi / 2)
        drop = 9 * (1 - y) / 2
        impact = max(0.0, 1 - abs(t - 0.5) * 6)      # only near the bottom
        out.append(dict(rx=54, ry=66, dy=drop * 2.1 - 11, squash=1.0 - 0.22 * impact,
                        lean=5 * math.sin(t * 2 * math.pi),
                        cheer=impact > 0.55, mouth="smile" if impact > 0.55 else None))
    return out


def drift(n=16):
    """Idle: a slow sway with a blink two thirds through."""
    import math
    out = []
    for i in range(n):
        t = i / n
        blink = i in (10, 11)
        out.append(dict(rx=56, ry=70, dy=4 * math.sin(t * 2 * math.pi),
                        lean=4 * math.sin(t * 2 * math.pi),
                        eyes="closed" if blink else "open"))
    return out


if __name__ == "__main__":
    render(bounce(), ROOT / "assets" / "media-sparkle.gif", 6, 200, 170)
    render(drift(), ROOT / "assets" / "session-sparkle.gif", 9, 220, 200)
