#!/usr/bin/env python3
"""Render a complete theme pack from the shell's own mascot.

    ./hybrid/tools/mascot/make-theme.py nebula

A theme is a directory under `assets/themes/` holding five files, which
`config::UserPaths` resolves from `paths.themeName`:

    wallpaper.jpg   the desktop wallpaper, applied when the theme is selected
    lock.gif        the lock screen's idle animation
    media.gif       under the dashboard's player controls (paths.mediaGif)
    session.gif     in the session menu (paths.sessionGif)
    notif.png       shown when there are no notifications (paths.noNotifsPic)

Everything is drawn from `sparkle.py` -- the four-pointed sparkle from `assets/logo.svg` --
recoloured per theme, so a pack is a palette rather than a pile of borrowed artwork. That
matters here more than it sounds: OP's theme packs are Deadpool, Gojo and Shinchan, which is
third-party character IP, and this shell has already had to remove Pusheen, Bongo Cat and the
Chrome dino for exactly that reason (see hybrid/docs/provenance.md). A generated theme has no
licensing question at all.

Requires `rsvg-convert` (librsvg) and `magick` (ImageMagick), as make-gifs.py does.
"""
import math
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import sparkle as sparkle_mod
from sparkle import sparkle

ROOT = Path(__file__).resolve().parents[3]

# light, base, deep, eye, and the two wallpaper gradient stops.
PALETTES = {
    "nebula": ("#C9A7FF", "#A46BFF", "#5B2FA6", "#1A0E2E", "#150B24", "#2E1A4F"),
    "sparkle": ("#8FF3EF", "#6AE5E1", "#35A9A6", "#0E2E2E", "#08201F", "#12403E"),
}


def recolour(svg: str, pal) -> str:
    """Swap the mascot's cyan for a theme palette.

    Done on the rendered SVG text rather than by parameterising sparkle.py, so the mascot has
    exactly one definition and a theme cannot drift from it.
    """
    light, base, deep, eye = pal[:4]
    for old, new in ((sparkle_mod.CYAN_LIGHT, light), (sparkle_mod.CYAN, base),
                     (sparkle_mod.CYAN_DEEP, deep), (sparkle_mod.EYE, eye)):
        svg = re.sub(old, new, svg, flags=re.IGNORECASE)
    return svg


def render_gif(frames, out, delay, w, h, pal):
    with tempfile.TemporaryDirectory() as td:
        pngs = []
        for i, kw in enumerate(frames):
            svg, png = Path(td) / f"{i:02d}.svg", Path(td) / f"{i:02d}.png"
            svg.write_text(recolour(sparkle(w=w, h=h, **kw), pal))
            subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), str(svg), "-o", str(png)], check=True)
            pngs.append(str(png))
        subprocess.run(["magick", "-dispose", "background", "-delay", str(delay), "-loop", "0",
                        *pngs, str(out)], check=True)


def render_png(kw, out, w, h, pal):
    with tempfile.TemporaryDirectory() as td:
        svg = Path(td) / "a.svg"
        svg.write_text(recolour(sparkle(w=w, h=h, **kw), pal))
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), str(svg), "-o", str(out)], check=True)


def wallpaper(out, pal, w=2560, h=1440):
    """A dark gradient with the mascot scattered across it as starlight.

    Composited with PIL rather than as one big SVG. Nesting the glyph as 34 inner <svg>
    elements looked tidier and does not work: `sparkle()` emits its own <defs> with fixed
    gradient ids, so every copy redefines id="b" and rsvg-convert rejects the document. One
    glyph is rendered once and pasted, which also makes per-copy opacity straightforward.
    """
    from PIL import Image

    top = tuple(int(pal[4][i:i + 2], 16) for i in (1, 3, 5))
    bottom = tuple(int(pal[5][i:i + 2], 16) for i in (1, 3, 5))
    base = tuple(int(pal[1][i:i + 2], 16) for i in (1, 3, 5))

    bg = Image.new("RGB", (w, h))
    px = bg.load()
    for y in range(h):
        t = y / (h - 1)
        row = tuple(round(top[c] + (bottom[c] - top[c]) * t) for c in range(3))
        for x in range(w):
            px[x, y] = row

    # A soft off-centre glow, so the field is not a flat ramp.
    glow = Image.new("L", (w, h), 0)
    gp = glow.load()
    cx, cy, r = 0.28 * w, 0.22 * h, 0.75 * max(w, h)
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            d = math.hypot(x - cx, y - cy) / r
            v = max(0, int(72 * (1 - min(d, 1.0)) ** 2))
            gp[x, y] = v
            if x + 1 < w:
                gp[x + 1, y] = v
            if y + 1 < h:
                gp[x, y + 1] = v
                if x + 1 < w:
                    gp[x + 1, y + 1] = v
    bg = Image.composite(Image.new("RGB", (w, h), base), bg, glow)

    with tempfile.TemporaryDirectory() as td:
        svg, png = Path(td) / "g.svg", Path(td) / "g.png"
        svg.write_text(recolour(sparkle(w=128, h=128, rx=44, ry=54, eyes="none",
                                        mouth=None, glow=False), pal))
        subprocess.run(["rsvg-convert", "-w", "256", "-h", "256", str(svg), "-o", str(png)], check=True)
        glyph = Image.open(png).convert("RGBA")

        # Deterministic placement, so re-running reproduces the same wallpaper rather than a
        # new one each time -- a generated asset that changes every run is a diff for nothing.
        for i in range(34):
            gx = (i * 7919 % 1000) / 1000
            gy = (i * 104729 % 1000) / 1000
            if gx + gy > 1.35 and i % 3:
                continue  # keep the lower right quiet, where icons and the clock sit
            size = int(26 + (i * 31337 % 100) / 100 * 96)
            opacity = 0.12 + (i * 6151 % 100) / 100 * 0.5
            g = glyph.resize((size, size), Image.LANCZOS)
            a = g.getchannel("A").point(lambda v, o=opacity: int(v * o))
            g.putalpha(a)
            bg.paste(g, (int(gx * w), int(gy * h)), g)

    bg.save(out, "JPEG", quality=92, optimize=True)


def bounce(n=12):
    out = []
    for i in range(n):
        t = i / n
        y = math.sin(t * 2 * math.pi - math.pi / 2)
        drop = 9 * (1 - y) / 2
        impact = max(0.0, 1 - abs(t - 0.5) * 6)
        out.append(dict(rx=54, ry=66, dy=drop * 2.1 - 11, squash=1.0 - 0.22 * impact,
                        lean=5 * math.sin(t * 2 * math.pi),
                        cheer=impact > 0.55, mouth="smile" if impact > 0.55 else None))
    return out


def drift(n=16, blink_at=(10, 11)):
    out = []
    for i in range(n):
        t = i / n
        out.append(dict(rx=56, ry=70, dy=4 * math.sin(t * 2 * math.pi),
                        lean=4 * math.sin(t * 2 * math.pi),
                        eyes="closed" if i in blink_at else "open"))
    return out


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("-")] or ["nebula"]
    for name in names:
        if name not in PALETTES:
            sys.exit(f"unknown theme {name!r}; known: {', '.join(sorted(PALETTES))}")
        pal = PALETTES[name]
        out = ROOT / "assets" / "themes" / name
        out.mkdir(parents=True, exist_ok=True)

        wallpaper(out / "wallpaper.jpg", pal)
        render_gif(bounce(), out / "media.gif", 7, 160, 160, pal)
        render_gif(drift(), out / "session.gif", 11, 160, 160, pal)
        # The lock screen is slower still, and never blinks mid-glance.
        render_gif(drift(n=20, blink_at=(14, 15)), out / "lock.gif", 13, 192, 192, pal)
        render_png(dict(rx=52, ry=64, eyes="closed", mouth="smile"), out / "notif.png", 160, 160, pal)

        for f in sorted(out.iterdir()):
            print(f"  {f.relative_to(ROOT)}  {f.stat().st_size:>7,} bytes")


if __name__ == "__main__":
    main()
