#!/usr/bin/env python3
"""Generate starting point SVG tiles for all combinations of N/S/E/W contacts."""

from itertools import combinations
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# Trace dimensions matching the track tiles
# Tile is 64x64, trace runs from 22 to 42 (width 20), centre at 32
TRACE_MIN = 22
TRACE_MAX = 42
TRACE_MID = 32
TILE = 64
BODY_MARGIN = 14  # component body starts here from each edge

PCB_BG = '#1e3a1e'
PCB_FILL = '#1a5c2a'
COPPER = '#d4a017'
COPPER_DARK = '#b8860b'
COPPER_HIGHLIGHT = '#e8c040'
VIA = '#c8a020'
VIA_STROKE = '#e8d060'
BODY_FILL = '#1a0a00'
BODY_STROKE = '#ff6600'
BODY_ACCENT = '#ff4400'
GLOW = '#ff8800'
LABEL_COLOR = '#ff9900'
ARROW_COLOR = '#ffcc00'


def contact_trace(side: str) -> str:
    """Return SVG for the copper trace segment from a body edge to the tile edge."""
    if side == 'N':
        return (
            f'<rect x="{TRACE_MIN}" y="0" width="20" height="{BODY_MARGIN}" fill="{COPPER_DARK}"/>'
            f'<rect x="{TRACE_MIN+2}" y="0" width="16" height="{BODY_MARGIN}" fill="{COPPER}"/>'
            f'<rect x="{TRACE_MIN+2}" y="0" width="2" height="{BODY_MARGIN}" fill="{COPPER_HIGHLIGHT}" opacity="0.5"/>'
            f'<circle cx="{TRACE_MID}" cy="2" r="4" fill="{VIA}" stroke="{VIA_STROKE}" stroke-width="1"/>'
        )
    if side == 'S':
        return (
            f'<rect x="{TRACE_MIN}" y="{TILE-BODY_MARGIN}" width="20" height="{BODY_MARGIN}" fill="{COPPER_DARK}"/>'
            f'<rect x="{TRACE_MIN+2}" y="{TILE-BODY_MARGIN}" width="16" height="{BODY_MARGIN}" fill="{COPPER}"/>'
            f'<rect x="{TRACE_MIN+2}" y="{TILE-BODY_MARGIN}" width="2" height="{BODY_MARGIN}" fill="{COPPER_HIGHLIGHT}" opacity="0.5"/>'
            f'<circle cx="{TRACE_MID}" cy="{TILE-2}" r="4" fill="{VIA}" stroke="{VIA_STROKE}" stroke-width="1"/>'
        )
    if side == 'E':
        return (
            f'<rect x="{TILE-BODY_MARGIN}" y="{TRACE_MIN}" width="{BODY_MARGIN}" height="20" fill="{COPPER_DARK}"/>'
            f'<rect x="{TILE-BODY_MARGIN}" y="{TRACE_MIN+2}" width="{BODY_MARGIN}" height="16" fill="{COPPER}"/>'
            f'<rect x="{TILE-BODY_MARGIN}" y="{TRACE_MIN+2}" width="{BODY_MARGIN}" height="2" fill="{COPPER_HIGHLIGHT}" opacity="0.5"/>'
            f'<circle cx="{TILE-2}" cy="{TRACE_MID}" r="4" fill="{VIA}" stroke="{VIA_STROKE}" stroke-width="1"/>'
        )
    if side == 'W':
        return (
            f'<rect x="0" y="{TRACE_MIN}" width="{BODY_MARGIN}" height="20" fill="{COPPER_DARK}"/>'
            f'<rect x="0" y="{TRACE_MIN+2}" width="{BODY_MARGIN}" height="16" fill="{COPPER}"/>'
            f'<rect x="0" y="{TRACE_MIN+2}" width="{BODY_MARGIN}" height="2" fill="{COPPER_HIGHLIGHT}" opacity="0.5"/>'
            f'<circle cx="2" cy="{TRACE_MID}" r="4" fill="{VIA}" stroke="{VIA_STROKE}" stroke-width="1"/>'
        )
    return ''


def arrow_for_side(side: str, cx: int = TRACE_MID, cy: int = TRACE_MID) -> str:
    """Small arrow pointing inward from a contact side."""
    s = 5
    if side == 'N':
        # pointing down (into tile from north)
        return f'<polygon points="{cx},{cy+s} {cx-s},{cy-s} {cx+s},{cy-s}" fill="{ARROW_COLOR}" opacity="0.9"/>'
    if side == 'S':
        return f'<polygon points="{cx},{cy-s} {cx-s},{cy+s} {cx+s},{cy+s}" fill="{ARROW_COLOR}" opacity="0.9"/>'
    if side == 'E':
        return f'<polygon points="{cx-s},{cy} {cx+s},{cy-s} {cx+s},{cy+s}" fill="{ARROW_COLOR}" opacity="0.9"/>'
    if side == 'W':
        return f'<polygon points="{cx+s},{cy} {cx-s},{cy-s} {cx-s},{cy+s}" fill="{ARROW_COLOR}" opacity="0.9"/>'
    return ''


def generate(sides: tuple[str, ...]) -> str:
    key = ''.join(sorted(sides, key='NSEW'.index))
    n = len(sides)

    # Body rectangle sits inside where traces don't cut into it
    bx1 = BODY_MARGIN if 'W' in sides else BODY_MARGIN
    by1 = BODY_MARGIN if 'N' in sides else BODY_MARGIN
    bx2 = TILE - BODY_MARGIN if 'E' in sides else TILE - BODY_MARGIN
    by2 = TILE - BODY_MARGIN if 'S' in sides else TILE - BODY_MARGIN
    bw = bx2 - bx1
    bh = by2 - by1
    bcx = (bx1 + bx2) // 2
    bcy = (by1 + by2) // 2

    traces = '\n  '.join(contact_trace(s) for s in sides)

    # Inward arrows near each contact entrance on body edge
    arrows = []
    if 'N' in sides:
        arrows.append(arrow_for_side('N', TRACE_MID, by1 + 6))
    if 'S' in sides:
        arrows.append(arrow_for_side('S', TRACE_MID, by2 - 6))
    if 'E' in sides:
        arrows.append(arrow_for_side('E', bx2 - 6, TRACE_MID))
    if 'W' in sides:
        arrows.append(arrow_for_side('W', bx1 + 6, TRACE_MID))
    arrows_svg = '\n  '.join(arrows)

    label_y = bcy + 4
    sublabel_y = bcy + 13

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {TILE} {TILE}" width="{TILE}" height="{TILE}">
  <!-- Copper traces to contacts: {key} -->
  {traces}
  <!-- Component body -->
  <rect x="{bx1}" y="{by1}" width="{bw}" height="{bh}" rx="3" fill="{BODY_FILL}" stroke="{BODY_STROKE}" stroke-width="2"/>
  <!-- Body inner highlight -->
  <rect x="{bx1+3}" y="{by1+3}" width="{bw-6}" height="{bh-6}" rx="2" fill="none" stroke="{BODY_ACCENT}" stroke-width="0.75" opacity="0.5"/>
  <!-- Glow dot -->
  <circle cx="{bcx}" cy="{bcy-6}" r="5" fill="{GLOW}" opacity="0.85"/>
  <circle cx="{bcx}" cy="{bcy-6}" r="3" fill="#ffeeaa" opacity="0.9"/>
  <!-- Inward arrows -->
  {arrows_svg}
  <!-- Label -->
  <text x="{bcx}" y="{label_y}" font-family="monospace" font-size="8" font-weight="bold" fill="{LABEL_COLOR}" text-anchor="middle">IN</text>
  <text x="{bcx}" y="{sublabel_y}" font-family="monospace" font-size="5" fill="#ffcc66" text-anchor="middle">{key}</text>
</svg>
"""
    return key, svg


ALL_SIDES = ('N', 'S', 'E', 'W')

for count in range(1, 5):
    for combo in combinations(ALL_SIDES, count):
        key, svg = generate(combo)
        filename = os.path.join(OUT_DIR, f'start_{key}.svg')
        with open(filename, 'w') as f:
            f.write(svg)
        print(f'Written: start_{key}.svg  (contacts: {key})')

print('Done.')
