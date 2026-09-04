#!/usr/bin/env python3
"""Render the shell's sound set.

Names come from services/Audio.qml and audioconfig.hpp and are fixed. The notification tones
are named for celestial objects, matching the shell's own vocabulary -- and unlike the Android
set they replace, a star's name is not anyone's property.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from synth import NOTES as N, noise, seq, tone, write

ROOT = Path(__file__).resolve().parents[3]
UI = ROOT / "assets" / "sounds"
NOTIF = UI / "notifications"

BELL = dict(partials=(1.0, 2.01, 3.02, 4.04), weights=(1.0, 0.32, 0.13, 0.06))
SOFT = dict(partials=(1.0, 2.0), weights=(1.0, 0.18))


def build():
    out = {}

    # --- interface -------------------------------------------------------------
    # A tick must be felt, not heard: very short, high, almost no tail.
    out["Effect_Tick.wav"] = tone(N["E6"], 0.045, decay=90, attack=0.0012, **SOFT)

    # Lock falls, unlock rises. Same two notes, opposite order -- they read as a pair.
    out["Lock.wav"] = seq((0.0, tone(N["G5"], 0.13, decay=26, **SOFT)),
                          (0.055, tone(N["C5"], 0.16, decay=20, **SOFT)))
    out["Unlock.wav"] = seq((0.0, tone(N["C5"], 0.13, decay=26, **SOFT)),
                            (0.055, tone(N["G5"], 0.18, decay=17, **SOFT)))

    # Charging: a confident rise, three notes, ringing on.
    out["ChargingStarted.wav"] = seq((0.00, tone(N["C5"], 0.9, decay=5.0, **BELL)),
                                     (0.10, tone(N["E5"], 0.9, decay=4.6, **BELL)),
                                     (0.20, tone(N["G5"], 1.1, decay=3.4, **BELL)))

    # Low battery: two falling notes, deliberately duller, twice -- attention without alarm.
    beep = lambda t: seq((t, tone(N["A4"], 0.30, decay=12, **SOFT)),
                         (t + 0.16, tone(N["D4"], 0.42, decay=9, **SOFT)))
    out["LowBattery.wav"] = seq((0.0, beep(0.0)), (0.62, beep(0.0)))

    # Shutter: a filtered noise burst with a woody click under it.
    out["camera_click.wav"] = seq((0.0, [v * 0.55 for v in noise(0.055, decay=70)]),
                                  (0.0, tone(N["A5"], 0.05, decay=95, attack=0.0008, **SOFT)),
                                  (0.075, [v * 0.30 for v in noise(0.05, decay=80)]))

    # Record starts up, stops down; longer tails than lock/unlock so they feel deliberate.
    out["VideoRecord.wav"] = seq((0.0, tone(N["D5"], 0.20, decay=16, **SOFT)),
                                 (0.10, tone(N["A5"], 0.30, decay=11, **BELL)))
    out["VideoStop.wav"] = seq((0.0, tone(N["A5"], 0.20, decay=16, **SOFT)),
                               (0.10, tone(N["D5"], 0.30, decay=11, **BELL)))

    # --- notifications ---------------------------------------------------------
    # Eight characters, one scale, so a user can pick by feel and none of them clash.
    notif = {
        "Iapetus.wav":  seq((0.0, tone(N["G5"], 0.75, decay=5.5, **BELL))),
        "Callisto.wav": seq((0.0, tone(N["E5"], 0.5, decay=7, **BELL)),
                            (0.09, tone(N["C6"], 0.75, decay=5, **BELL))),
        "Rhea.wav":     seq((0.0, tone(N["C5"], 0.5, decay=8, **SOFT)),
                            (0.08, tone(N["E5"], 0.5, decay=7, **SOFT)),
                            (0.16, tone(N["G5"], 0.85, decay=4.5, **BELL))),
        "Titania.wav":  seq((0.0, tone(N["A5"], 0.42, decay=9, **BELL)),
                            (0.11, tone(N["E5"], 0.62, decay=6.5, **BELL))),
        "Dione.wav":    seq((0.0, tone(N["D5"], 0.55, decay=6.5, **SOFT)),
                            (0.13, tone(N["A5"], 0.7, decay=5.2, **SOFT))),
        "Umbriel.wav":  seq((0.0, tone(N["C4"], 0.9, decay=4.2, **BELL, detune=-4))),
        "Mimas.wav":    seq((0.0, tone(N["E6"], 0.3, decay=14, **SOFT)),
                            (0.07, tone(N["G6"], 0.42, decay=11, **SOFT))),
        "Oberon.wav":   seq((0.0, tone(N["G4"], 0.7, decay=5.5, **BELL)),
                            (0.14, tone(N["D5"], 0.55, decay=6.5, **BELL)),
                            (0.28, tone(N["G5"], 0.9, decay=4.0, **BELL))),
    }
    return out, notif


if __name__ == "__main__":
    ui, notif = build()
    for name, buf in ui.items():
        print(f"  {name:24} {write(UI / name, buf):.2f}s")
    for name, buf in notif.items():
        print(f"  notifications/{name:22} {write(NOTIF / name, buf):.2f}s")
