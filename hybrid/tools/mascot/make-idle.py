#!/usr/bin/env python3
"""Render the "nothing to see here" silhouette used for paths.noNotifsPic.

modules/sidebar/NotifDock.qml draws it through a Colouriser that flattens every pixel to
m3outlineVariant, so this must be a *silhouette*: one filled shape with the eyes punched out
as holes, the way the sprite it replaces was. Anything drawn in colour would vanish.

A sleeping sparkle, because the image means "no notifications".
"""
import subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

ROOT = Path(__file__).resolve().parents[3]
W, H = 1200, 520


def star(cx, cy, rx, ry, k=0.26):
    return (f"M {cx},{cy-ry} Q {cx+rx*k},{cy-ry*k} {cx+rx},{cy} "
            f"Q {cx+rx*k},{cy+ry*k} {cx},{cy+ry} Q {cx-rx*k},{cy+ry*k} {cx-rx},{cy} "
            f"Q {cx-rx*k},{cy-ry*k} {cx},{cy-ry} Z")


def zzz(x, y, s):
    """Three strokes of a sleeping z, rising to the right."""
    out = ""
    for i, (dx, dy, k) in enumerate(((0, 0, 1.0), (s * 1.5, -s * 1.15, 0.72), (s * 2.7, -s * 2.05, 0.5))):
        a, b = x + dx, y + dy
        w, h = s * k, s * k
        out += (f'<path d="M {a},{b} h {w} l {-w},{h} h {w}" fill="none" stroke="#000" '
                f'stroke-width="{max(3.0, s * 0.17)}" stroke-linecap="round" stroke-linejoin="round"/>')
    return out


# Body with the eyes as evenodd holes, so a flat colourise still shows a face.
cx, cy, rx, ry = W * 0.42, H * 0.60, 168, 132
eye_dy, eye_dx, er = -8, rx * 0.30, 15
body = star(cx, cy, rx, ry)
# closed eyes: thin lens shapes, punched out
lids = ""
for s in (-1, 1):
    ex = cx + s * eye_dx
    lids += (f"M {ex-er},{cy+eye_dy} q {er},{er*0.85} {er*2},0 q {-er},{-er*0.3} {-er*2},0 Z ")

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<g fill="#000">
<path fill-rule="evenodd" d="{body} {lids}"/>
<path d="{star(W*0.84, H*0.26, 28, 35)}"/>
<path d="{star(W*0.78, H*0.62, 18, 22)}"/>
<path d="{star(W*0.24, H*0.22, 15, 19)}"/>
</g>
{zzz(W*0.575, H*0.44, 40)}
</svg>'''

out = ROOT / "assets" / "no-notifs.png"
tmp = out.with_suffix(".svg")
tmp.write_text(svg)
subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), str(tmp), "-o", str(out)], check=True)
tmp.unlink()
print(f"-> {out.relative_to(ROOT)}")
