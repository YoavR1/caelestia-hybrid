#!/usr/bin/env python3
"""Draw the Caelestia sparkle -- the shell's own mascot -- as SVG.

The shape is the four-pointed sparkle from assets/logo.svg, softened into a character: the
same concave-sided star, the same cyan (#6AE5E1), with a face. That is the point -- the
replacement should look like it belongs to this shell rather than like a substitute for
something else.

Every frame is this one function with different arguments, so the character stays on-model
across the shimeji sprites, both GIFs and the runner game.
"""

CYAN_LIGHT = "#8FF3EF"
CYAN = "#6AE5E1"
CYAN_DEEP = "#35A9A6"
EYE = "#0E2E2E"


def sparkle(
    w=128, h=128, *, rx=42, ry=52, waist=0.26, squash=1.0, lean=0.0, dy=0.0,
    eyes="open", mouth=None, blush=False, glow=True, cheer=False,
):
    """One frame. `squash` <1 flattens, `lean` rotates in degrees, `dy` shifts vertically."""
    cx, cy = w / 2, h / 2 + dy
    # squashing widens as it flattens, so the character keeps its volume
    sx = 1.0 + (1.0 - squash) * 0.55
    ex, ey = rx * sx, ry * squash

    k = waist
    body = (
        f"M {cx},{cy - ey} "
        f"Q {cx + ex * k},{cy - ey * k} {cx + ex},{cy} "
        f"Q {cx + ex * k},{cy + ey * k} {cx},{cy + ey} "
        f"Q {cx - ex * k},{cy + ey * k} {cx - ex},{cy} "
        f"Q {cx - ex * k},{cy - ey * k} {cx},{cy - ey} Z"
    )

    eye_dx, eye_y, er = ex * 0.30, cy - ey * 0.06, 4.6
    if eyes == "closed":
        lid = (f'<path d="M {cx - eye_dx - er},{eye_y} q {er},{er * 0.9} {er * 2},0" '
               f'stroke="{EYE}" stroke-width="3.1" stroke-linecap="round" fill="none"/>'
               f'<path d="M {cx + eye_dx - er},{eye_y} q {er},{er * 0.9} {er * 2},0" '
               f'stroke="{EYE}" stroke-width="3.1" stroke-linecap="round" fill="none"/>')
    elif eyes == "up":
        lid = "".join(
            f'<ellipse cx="{cx + s * eye_dx}" cy="{eye_y - 3}" rx="{er}" ry="{er * 1.15}" fill="{EYE}"/>'
            f'<circle cx="{cx + s * eye_dx + 1.5}" cy="{eye_y - 5.5}" r="1.7" fill="#FFFFFF" opacity="0.9"/>'
            for s in (-1, 1))
    else:
        lid = "".join(
            f'<ellipse cx="{cx + s * eye_dx}" cy="{eye_y}" rx="{er}" ry="{er * 1.12}" fill="{EYE}"/>'
            f'<circle cx="{cx + s * eye_dx + 1.5}" cy="{eye_y - 2.2}" r="1.8" fill="#FFFFFF" opacity="0.9"/>'
            for s in (-1, 1))

    face = lid
    if mouth == "open":
        face += f'<ellipse cx="{cx}" cy="{eye_y + 12}" rx="5.5" ry="6.5" fill="{EYE}"/>'
    elif mouth == "wide":
        face += f'<ellipse cx="{cx}" cy="{eye_y + 12}" rx="8" ry="8.5" fill="{EYE}"/>'
    elif mouth == "smile":
        face += (f'<path d="M {cx - 6},{eye_y + 9} q 6,6 12,0" stroke="{EYE}" stroke-width="2.8" '
                 f'stroke-linecap="round" fill="none"/>')
    if blush:
        face += "".join(
            f'<ellipse cx="{cx + s * eye_dx * 1.75}" cy="{eye_y + 7}" rx="5" ry="3.2" '
            f'fill="#FF9BB0" opacity="0.55"/>' for s in (-1, 1))

    # two small companion sparkles, as in the logo's cluster
    spark = ""
    if cheer:
        for sx_, sy_, s_ in ((-ex * 1.02, -ey * 0.62, 7), (ex * 1.02, -ey * 0.48, 5.5)):
            spark += (f'<path d="M {cx + sx_},{cy + sy_ - s_} Q {cx + sx_},{cy + sy_} {cx + sx_ + s_},{cy + sy_} '
                      f'Q {cx + sx_},{cy + sy_} {cx + sx_},{cy + sy_ + s_} '
                      f'Q {cx + sx_},{cy + sy_} {cx + sx_ - s_},{cy + sy_} '
                      f'Q {cx + sx_},{cy + sy_} {cx + sx_},{cy + sy_ - s_} Z" fill="{CYAN_LIGHT}" opacity="0.9"/>')

    filt = ('<filter id="g" x="-40%" y="-40%" width="180%" height="180%">'
            '<feDropShadow dx="0" dy="2.5" stdDeviation="4" flood-color="#1C6D6B" flood-opacity="0.35"/>'
            "</filter>") if glow else ""

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>
<linearGradient id="b" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{CYAN_LIGHT}"/><stop offset="0.55" stop-color="{CYAN}"/>
<stop offset="1" stop-color="{CYAN_DEEP}"/>
</linearGradient>{filt}
</defs>
<g transform="rotate({lean} {cx} {cy})"{' filter="url(#g)"' if glow else ''}>
{spark}<path d="{body}" fill="url(#b)"/>
<path d="M {cx - ex * 0.34},{cy - ey * 0.46} q {ex * 0.34},{-ey * 0.16} {ex * 0.62},{ey * 0.06}"
 stroke="#FFFFFF" stroke-opacity="0.33" stroke-width="2.6" stroke-linecap="round" fill="none"/>
{face}
</g>
</svg>'''
