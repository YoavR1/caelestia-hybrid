#!/usr/bin/env python3
"""Render the runner-game sprites in the mascot's own idiom.

components/DinoGame.qml draws the runner at 44x42 upright and 59x27 ducking, so the sprite
aspect ratios matter more than their pixel sizes. The obstacles become crystal shards and the
flier a comet, which keeps the whole game inside the same celestial vocabulary as the logo
rather than borrowing another product's character.
"""
import subprocess, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparkle import sparkle, CYAN, CYAN_LIGHT, CYAN_DEEP

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "runner"


def png(svg_text, name, w, h):
    with tempfile.TemporaryDirectory() as td:
        s = Path(td) / "x.svg"
        s.write_text(svg_text)
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), str(s),
                        "-o", str(OUT / name)], check=True)


def shard(w, h, spikes):
    """An angular crystal, drawn as overlapping tapered blades."""
    body = ""
    for i, (x, top, half) in enumerate(spikes):
        body += (f'<path d="M {x},{top} L {x + half},{h - 4} L {x - half},{h - 4} Z" '
                 f'fill="url(#s)" stroke="{CYAN_DEEP}" stroke-width="1.5" stroke-linejoin="round"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{CYAN_LIGHT}"/><stop offset="1" stop-color="{CYAN_DEEP}"/>
</linearGradient></defs>{body}</svg>'''


def comet(w, h):
    cx, cy = w * 0.62, h * 0.5
    r = h * 0.30
    tail = (f'<path d="M {cx - r * 0.6},{cy - r * 0.55} L {w * 0.04},{cy} L {cx - r * 0.6},{cy + r * 0.55} Z" '
            f'fill="{CYAN}" opacity="0.55"/>')
    k = 0.26
    head = (f"M {cx},{cy - r} Q {cx + r * k},{cy - r * k} {cx + r},{cy} "
            f"Q {cx + r * k},{cy + r * k} {cx},{cy + r} "
            f"Q {cx - r * k},{cy + r * k} {cx - r},{cy} "
            f"Q {cx - r * k},{cy - r * k} {cx},{cy - r} Z")
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs><linearGradient id="c" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{CYAN_LIGHT}"/><stop offset="1" stop-color="{CYAN_DEEP}"/>
</linearGradient></defs>
{tail}<path d="{head}" fill="url(#c)"/>
<ellipse cx="{cx - r*0.28}" cy="{cy - r*0.1}" rx="3.2" ry="3.6" fill="#0E2E2E"/>
<ellipse cx="{cx + r*0.28}" cy="{cy - r*0.1}" rx="3.2" ry="3.6" fill="#0E2E2E"/>
</svg>'''


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    # runner: two stride frames, a duck, and a knocked-out frame
    png(sparkle(w=88, h=85, rx=30, ry=36, lean=-8, squash=0.94, dy=2), "run_a.png", 88, 85)
    png(sparkle(w=88, h=85, rx=30, ry=36, lean=8, squash=1.05, dy=-2), "run_b.png", 88, 85)
    png(sparkle(w=118, h=54, rx=44, ry=22, squash=1.0, eyes="open"), "duck_a.png", 118, 54)
    png(sparkle(w=118, h=54, rx=44, ry=22, squash=1.0, lean=3), "duck_b.png", 118, 55)
    png(sparkle(w=88, h=85, rx=30, ry=36, eyes="closed", squash=0.62, dy=12, lean=-14), "dead.png", 88, 85)
    # obstacles
    png(shard(50, 105, [(25, 8, 11)]), "shard_small.png", 50, 105)
    png(shard(104, 105, [(30, 26, 10), (56, 6, 12), (80, 30, 9)]), "shard_large.png", 104, 105)
    png(comet(194, 127), "comet.png", 194, 127)
    print(f"8 sprites -> {OUT.relative_to(ROOT)}")
