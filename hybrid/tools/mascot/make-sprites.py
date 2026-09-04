#!/usr/bin/env python3
"""Render the shimeji sprite set for the Caelestia sparkle.

modules/shimeji/ShimejiSprite.qml names its frames by number, so the filenames are fixed:
only the sixteen listed there are ever loaded, and those are the only ones generated. The
previous set shipped 46 files of which 30 were never referenced.
"""
import subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparkle import sparkle

OUT = Path(__file__).resolve().parents[3] / "assets" / "shimeji" / "sparkle"

# frame number -> pose. Names match the animations in ShimejiSprite.qml.
FRAMES = {
    1:  dict(),                                                        # idle / stand / walk
    2:  dict(squash=0.90, lean=-6, dy=3),                              # walk, contact
    3:  dict(squash=1.05, lean=6, dy=-3),                              # walk, passing
    11: dict(mouth="smile", blush=True, cheer=True),                   # eat, satisfied
    15: dict(mouth="open", squash=0.97),                               # eat
    16: dict(mouth="wide", squash=0.94),                               # eat
    17: dict(mouth="open", squash=0.97),                               # eat
    20: dict(eyes="closed", squash=0.85, dy=6),                        # sleep
    21: dict(eyes="closed", squash=0.72, dy=12),                       # sleep / lay down
    26: dict(eyes="up", dy=-2),                                        # look up
    27: dict(mouth="wide", eyes="closed", squash=0.93),                # eat
    28: dict(mouth="open", dy=1),                                      # eat
    29: dict(mouth="wide", blush=True, squash=0.95),                   # eat
    31: dict(lean=14, dy=-4, squash=1.04),                             # dangle
    32: dict(lean=24, dy=-4, squash=1.06),                             # dangle
    33: dict(lean=4, dy=-4, squash=1.02),                              # dangle
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = OUT / ".frame.svg"
    for n, kw in sorted(FRAMES.items()):
        tmp.write_text(sparkle(**kw))
        subprocess.run(["rsvg-convert", "-w", "128", "-h", "128",
                        str(tmp), "-o", str(OUT / f"shime{n}.png")], check=True)
    tmp.unlink()
    print(f"{len(FRAMES)} sprites -> {OUT}")

if __name__ == "__main__":
    main()
