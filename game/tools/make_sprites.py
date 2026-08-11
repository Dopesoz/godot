#!/usr/bin/env python3
"""Generates every world sprite in assets/sprites/ — run it, commit the result.

    python3 tools/make_sprites.py

The SVGs are build output, but they are committed: the game must run for
someone who only cloned the repository, without Python. Re-run this after
changing a colour or a shape; never hand-edit the generated files.

Each entry below is a small piece of "art code": boxes, discs and panels in
cell units (see isolib.py). That keeps every object anchored to the same
isometric grid as the floor it stands on, and makes a palette change a
one-line edit rather than eighteen files to repaint.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from isolib import Sprite, Tile, darken, lighten, mix  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites")

WOOD = "#8a6a4b"
WOOD_LIGHT = "#a98a63"
METAL = "#9aa2ab"
WHITE = "#eceff3"
DARK = "#2c3038"


# --- floors -----------------------------------------------------------------

def floor_wood() -> Tile:
    t = Tile("floor_wood")
    base = "#b18b5c"
    t.rect(0, 0, 1, 1, base)
    # Planks run along u, which is the world's +x — down-right on screen.
    for i in range(5):
        v = i * 0.2
        t.rect(0, v, 1, 0.2, base if i % 2 == 0 else darken(base, 0.045))
        t.rect(0, v, 1, 0.012, darken(base, 0.26))
    # Butt joints, offset per plank so the floor does not read as one long deck.
    for i, u in enumerate([0.42, 0.68, 0.18, 0.86, 0.55]):
        t.rect(u, i * 0.2, 0.010, 0.2, darken(base, 0.22))
    return t


def floor_tile() -> Tile:
    t = Tile("floor_tile")
    base = "#ccd2d8"
    t.rect(0, 0, 1, 1, darken(base, 0.16))
    for iu in range(2):
        for iv in range(2):
            tone = base if (iu + iv) % 2 == 0 else lighten(base, 0.05)
            t.rect(iu * 0.5 + 0.022, iv * 0.5 + 0.022, 0.456, 0.456, tone)
    return t


def floor_carpet() -> Tile:
    t = Tile("floor_carpet")
    base = "#8d6066"
    t.rect(0, 0, 1, 1, base)
    # A weave: short strokes at two tones, dense enough to read as texture and
    # sparse enough not to shimmer when the camera moves.
    for i in range(8):
        for j in range(8):
            u, v = i / 8.0, j / 8.0
            if (i + j) % 2 == 0:
                t.rect(u + 0.02, v + 0.03, 0.07, 0.05, lighten(base, 0.06))
            else:
                t.rect(u + 0.04, v + 0.06, 0.05, 0.04, darken(base, 0.07))
    return t


## Three grass tiles rather than one. A single tile over a 40x40 map is a
## wallpaper: the eye finds the repeat immediately. Three, chosen per cell from
## its coordinates, is enough to break it up for free.
GRASS_VARIANTS = [
    [(0.14, 0.20), (0.58, 0.12), (0.32, 0.52), (0.76, 0.60),
     (0.10, 0.76), (0.50, 0.86), (0.88, 0.32), (0.24, 0.94)],
    [(0.36, 0.08), (0.72, 0.28), (0.08, 0.44), (0.52, 0.62),
     (0.86, 0.74), (0.28, 0.82), (0.62, 0.94), (0.18, 0.16)],
    [(0.06, 0.30), (0.44, 0.18), (0.80, 0.06), (0.22, 0.66),
     (0.64, 0.48), (0.92, 0.86), (0.38, 0.92), (0.70, 0.72)],
]


def floor_grass(index: int) -> Tile:
    t = Tile("ground_grass_%d" % index)
    base = "#597f45"
    t.rect(0, 0, 1, 1, base)
    for u, v in GRASS_VARIANTS[index]:
        t.rect(u, v, 0.05, 0.11, lighten(base, 0.10))
        t.rect(u + 0.10, v + 0.05, 0.04, 0.09, darken(base, 0.09))
        t.dot(u + 0.18, v + 0.14, 0.012, lighten(base, 0.16))
    return t


# --- walls ------------------------------------------------------------------
#
# A wall lives on a cell edge, so its sprite is exactly the quad the edge
# extrudes: one cell along the edge, 1.5 units (48 px) tall. The horizontal
# variant faces the camera's right shoulder and is the lit one; the vertical
# variant faces left and is darker. See Art.wall_rect for the placement.

WALL_HEIGHT_UNITS = 1.5
WALL_BASE = "#ded7cb"
## Where the glass sits inside a window sprite, as fractions of the wall quad.
## Painters re-uses these numbers to make the pane glow after dark.
PANE_X = (0.22, 0.78)
PANE_Z = (0.42, 1.16)


def _wall_body(s: Sprite, color: str) -> None:
    h = WALL_HEIGHT_UNITS
    s.poly([(0, 0, 0), (1, 0, 0), (1, 0, h), (0, 0, h)], color)
    # Top cap and skirting: two bands are all it takes for a flat plane to read
    # as a built wall rather than a painted rectangle.
    s.poly([(0, 0, h - 0.07), (1, 0, h - 0.07), (1, 0, h), (0, 0, h)], lighten(color, 0.22))
    s.poly([(0, 0, 0), (1, 0, 0), (1, 0, 0.09), (0, 0, 0.09)], darken(color, 0.16))


def wall(color: str, name: str) -> Sprite:
    s = Sprite(1, 0, WALL_HEIGHT_UNITS, name)
    _wall_body(s, color)
    return s


def door(color: str, name: str) -> Sprite:
    s = Sprite(1, 0, WALL_HEIGHT_UNITS, name)
    _wall_body(s, color)
    frame = darken(WOOD, 0.25)
    s.poly([(0.14, 0, 0), (0.86, 0, 0), (0.86, 0, 1.16), (0.14, 0, 1.16)], frame)
    s.poly([(0.19, 0, 0), (0.81, 0, 0), (0.81, 0, 1.10), (0.19, 0, 1.10)], WOOD)
    s.poly([(0.26, 0, 0.18), (0.74, 0, 0.18), (0.74, 0, 1.02), (0.26, 0, 1.02)],
           lighten(WOOD, 0.08))
    s.disc(0.71, 0.0, 0.60, 0.045, "#e8c766", squash=2.0)
    return s


def window(color: str, name: str) -> Sprite:
    s = Sprite(1, 0, WALL_HEIGHT_UNITS, name)
    _wall_body(s, color)
    x0, x1 = PANE_X
    z0, z1 = PANE_Z
    s.poly([(x0 - 0.05, 0, z0 - 0.07), (x1 + 0.05, 0, z0 - 0.07),
            (x1 + 0.05, 0, z1 + 0.07), (x0 - 0.05, 0, z1 + 0.07)], lighten(color, 0.30))
    s.poly([(x0, 0, z0), (x1, 0, z0), (x1, 0, z1), (x0, 0, z1)], "#8fbdd0")
    # A diagonal glint, so a pane is a pane even before the light hits it.
    s.poly([(x0, 0, z0 + 0.12), (x0 + 0.26, 0, z0), (x0 + 0.40, 0, z0),
            (x0, 0, z0 + 0.34)], lighten("#8fbdd0", 0.45))
    s.poly([(0.48, 0, z0), (0.52, 0, z0), (0.52, 0, z1), (0.48, 0, z1)], lighten(color, 0.30))
    return s


# --- furniture --------------------------------------------------------------

def bed_single() -> Sprite:
    s = Sprite(1, 2, 0.62, "bed_single")
    s.shadow()
    frame = WOOD
    s.box(0.06, 0.02, 0.0, 0.88, 0.10, 0.62, frame)          # headboard
    s.box(0.06, 1.88, 0.0, 0.88, 0.10, 0.30, frame)          # footboard
    s.box(0.08, 0.10, 0.0, 0.84, 1.80, 0.26, darken(frame, 0.10))
    s.box(0.08, 0.10, 0.26, 0.84, 1.80, 0.10, "#e7e3da")     # mattress
    s.box(0.10, 0.70, 0.36, 0.80, 1.22, 0.06, "#4a6ea8")     # blanket
    s.box(0.14, 0.18, 0.36, 0.72, 0.42, 0.09, "#f4f1ea")     # pillow
    return s


def bookshelf() -> Sprite:
    s = Sprite(1, 1, 1.25, "bookshelf")
    s.shadow()
    body = "#8c6b4c"
    s.box(0.10, 0.10, 0.0, 0.80, 0.42, 1.25, body)
    books = ["#a8494a", "#3f6ea8", "#c99a3f", "#4f8a5b", "#8e5aa0"]
    for level in range(3):
        z = 0.14 + level * 0.36
        s.poly([(0.14, 0.10, z + 0.30), (0.86, 0.10, z + 0.30),
                (0.86, 0.10, z + 0.32), (0.14, 0.10, z + 0.32)], darken(body, 0.35))
        x = 0.16
        for i in range(5):
            color = books[(i + level) % len(books)]
            w = 0.10 + 0.03 * ((i + level) % 3)
            s.poly([(x, 0.10, z), (x + w, 0.10, z), (x + w, 0.10, z + 0.28), (x, 0.10, z + 0.28)],
                   color)
            x += w + 0.015
    return s


def chair() -> Sprite:
    s = Sprite(1, 1, 0.60, "chair")
    s.shadow(inset=0.24)
    body = "#94714f"
    s.legs(0.26, 0.26, 0.48, 0.48, 0.28, darken(body, 0.18), thickness=0.07)
    s.box(0.24, 0.24, 0.28, 0.52, 0.52, 0.07, body)
    s.box(0.24, 0.24, 0.35, 0.52, 0.08, 0.25, lighten(body, 0.05))
    return s


def coffee_machine() -> Sprite:
    s = Sprite(1, 1, 0.86, "coffee_machine")
    s.shadow()
    counter = "#c9c2b4"
    s.box(0.08, 0.08, 0.0, 0.84, 0.84, 0.52, counter)
    body = "#5d4038"
    s.box(0.22, 0.24, 0.52, 0.50, 0.44, 0.34, body)
    s.box(0.26, 0.62, 0.52, 0.42, 0.10, 0.10, METAL)
    s.disc(0.47, 0.70, 0.62, 0.09, WHITE, squash=1.0)
    s.plate(0.28, 0.28, 0.86, 0.20, 0.16, "#d8a24a")
    return s


def computer() -> Sprite:
    s = Sprite(1, 1, 0.84, "computer")
    s.shadow()
    desk = "#7e6248"
    s.legs(0.10, 0.10, 0.80, 0.80, 0.44, darken(desk, 0.20))
    s.box(0.06, 0.06, 0.44, 0.88, 0.88, 0.06, desk)
    s.box(0.42, 0.36, 0.50, 0.16, 0.14, 0.06, DARK)
    s.box(0.20, 0.34, 0.56, 0.58, 0.06, 0.28, "#3a4150")
    s.poly([(0.24, 0.34, 0.60), (0.74, 0.34, 0.60), (0.74, 0.34, 0.82), (0.24, 0.34, 0.82)],
           "#79b6d9")
    s.poly([(0.24, 0.34, 0.72), (0.44, 0.34, 0.60), (0.52, 0.34, 0.60), (0.24, 0.34, 0.80)],
           lighten("#79b6d9", 0.45))
    s.box(0.26, 0.62, 0.50, 0.46, 0.18, 0.03, "#cfd4da")     # keyboard
    return s


def desk() -> Sprite:
    s = Sprite(2, 1, 0.50, "desk")
    s.shadow()
    body = "#9e7852"
    s.legs(0.08, 0.10, 1.84, 0.76, 0.44, darken(body, 0.20))
    s.box(0.04, 0.06, 0.44, 1.92, 0.84, 0.06, body)
    s.box(1.20, 0.14, 0.16, 0.68, 0.66, 0.28, darken(body, 0.08))
    s.poly([(1.24, 0.14, 0.28), (1.84, 0.14, 0.28), (1.84, 0.14, 0.30), (1.24, 0.14, 0.30)],
           darken(body, 0.40))
    return s


def dining_bench() -> Sprite:
    s = Sprite(2, 1, 0.34, "dining_bench")
    s.shadow(inset=0.14)
    body = "#99805f"
    s.box(0.10, 0.28, 0.0, 0.14, 0.44, 0.26, darken(body, 0.22))
    s.box(1.76, 0.28, 0.0, 0.14, 0.44, 0.26, darken(body, 0.22))
    s.box(0.04, 0.22, 0.26, 1.92, 0.56, 0.08, body)
    return s


def easel() -> Sprite:
    s = Sprite(1, 1, 1.05, "easel")
    s.shadow(inset=0.22)
    leg = "#a08050"
    s.box(0.20, 0.66, 0.0, 0.07, 0.07, 0.92, leg)
    s.box(0.73, 0.66, 0.0, 0.07, 0.07, 0.92, leg)
    s.box(0.46, 0.18, 0.0, 0.07, 0.07, 1.00, darken(leg, 0.12))
    s.box(0.16, 0.52, 0.42, 0.68, 0.10, 0.05, darken(leg, 0.20))
    s.wall_panel(0.16, 0.52, 0.46, 0.68, -0.30, 0.52, "#f2eee1")
    s.poly([(0.30, 0.40, 0.66), (0.52, 0.40, 0.62), (0.62, 0.40, 0.86), (0.34, 0.40, 0.88)],
           "#7fa8c4")
    s.poly([(0.44, 0.40, 0.58), (0.70, 0.40, 0.60), (0.70, 0.40, 0.74), (0.46, 0.40, 0.72)],
           "#c9895a")
    return s


def fridge() -> Sprite:
    s = Sprite(1, 1, 1.30, "fridge")
    s.shadow()
    body = "#ccd2d8"
    s.box(0.10, 0.12, 0.0, 0.80, 0.76, 1.30, body)
    s.poly([(0.14, 0.12, 0.02), (0.86, 0.12, 0.02), (0.86, 0.12, 0.80), (0.14, 0.12, 0.80)],
           lighten(body, 0.10))
    s.poly([(0.14, 0.12, 0.84), (0.86, 0.12, 0.84), (0.86, 0.12, 1.28), (0.14, 0.12, 1.28)],
           lighten(body, 0.10))
    s.poly([(0.72, 0.12, 0.34), (0.78, 0.12, 0.34), (0.78, 0.12, 0.72), (0.72, 0.12, 0.72)],
           "#7d848c")
    s.poly([(0.72, 0.12, 0.90), (0.78, 0.12, 0.90), (0.78, 0.12, 1.16), (0.72, 0.12, 1.16)],
           "#7d848c")
    return s


def guitar() -> Sprite:
    s = Sprite(1, 1, 0.95, "guitar")
    s.shadow(inset=0.30, opacity=0.12)
    body = "#c78d59"
    y = 0.62
    # Standing on end against the wall, seen face on. The silhouette is half a
    # guitar sampled at a dozen heights and mirrored — a waist between two
    # lobes is what makes it read as a guitar and not a spoon.
    profile = [
        (0.00, 0.12), (0.03, 0.20), (0.08, 0.24), (0.14, 0.25), (0.20, 0.23),
        (0.25, 0.19), (0.29, 0.17), (0.34, 0.19), (0.40, 0.22), (0.45, 0.21),
        (0.50, 0.17), (0.53, 0.11), (0.55, 0.05),
    ]
    outline = [(0.5 + half, y, z) for z, half in profile]
    outline += [(0.5 - half, y, z) for z, half in reversed(profile)]
    s.poly(outline, body)
    inner = [(0.5 + half * 0.82, y - 0.01, z + 0.02) for z, half in profile]
    inner += [(0.5 - half * 0.82, y - 0.01, z + 0.02) for z, half in reversed(profile)]
    s.poly(inner, lighten(body, 0.10))
    # Sound hole, bridge and neck.
    hole = []
    for i in range(16):
        angle = 6.283185 * i / 16
        hole.append((0.5 + math.cos(angle) * 0.065, y - 0.02, 0.34 + math.sin(angle) * 0.065))
    s.poly(hole, "#4a3018")
    s.poly([(0.44, y - 0.02, 0.16), (0.56, y - 0.02, 0.16),
            (0.56, y - 0.02, 0.19), (0.44, y - 0.02, 0.19)], darken(body, 0.45))
    s.poly([(0.455, y - 0.02, 0.52), (0.545, y - 0.02, 0.52),
            (0.545, y - 0.02, 0.86), (0.455, y - 0.02, 0.86)], darken(body, 0.42))
    s.poly([(0.44, y - 0.03, 0.86), (0.56, y - 0.03, 0.86),
            (0.56, y - 0.03, 0.95), (0.44, y - 0.03, 0.95)], "#33210f")
    return s


def kitchen_counter() -> Sprite:
    s = Sprite(2, 1, 0.58, "kitchen_counter")
    s.shadow()
    body = "#a89b86"
    s.box(0.04, 0.10, 0.0, 1.92, 0.80, 0.52, body)
    s.box(0.02, 0.08, 0.52, 1.96, 0.84, 0.06, "#c6c0b4")
    for i in range(4):
        x = 0.12 + i * 0.46
        s.poly([(x, 0.10, 0.06), (x + 0.40, 0.10, 0.06), (x + 0.40, 0.10, 0.46), (x, 0.10, 0.46)],
               lighten(body, 0.07))
        s.poly([(x + 0.16, 0.10, 0.40), (x + 0.24, 0.10, 0.40),
                (x + 0.24, 0.10, 0.42), (x + 0.16, 0.10, 0.42)], "#6f665a")
    s.disc(1.45, 0.50, 0.58, 0.22, "#8d949a", squash=1.0)
    s.disc(1.45, 0.50, 0.585, 0.18, "#aeb4ba", squash=1.0)
    return s


def lamp() -> Sprite:
    s = Sprite(1, 1, 1.10, "lamp")
    s.shadow(inset=0.34, opacity=0.12)
    s.cylinder(0.5, 0.5, 0.0, 0.20, 0.04, "#8f8a80")
    s.box(0.47, 0.47, 0.04, 0.06, 0.06, 0.78, "#a9a49b")
    # The shade is drawn as a lit surface rather than a shaded one: a lamp that
    # looks switched off in a dark room is worse than one that is always on.
    s.cone(0.5, 0.5, 0.82, 0.28, 0.19, 0.26, "#f2e3ab")
    return s


def shower() -> Sprite:
    s = Sprite(1, 1, 1.30, "shower")
    s.shadow()
    tray = "#d5dde2"
    s.box(0.06, 0.06, 0.0, 0.88, 0.88, 0.10, tray)
    s.disc(0.5, 0.5, 0.10, 0.12, "#9aa4ab", squash=1.0)
    # Two glass panels on the far sides, so the camera still sees inside.
    s.poly([(0.06, 0.06, 0.10), (0.94, 0.06, 0.10), (0.94, 0.06, 1.20), (0.06, 0.06, 1.20)],
           "#a8d4de", 0.42)
    s.poly([(0.06, 0.06, 0.10), (0.06, 0.94, 0.10), (0.06, 0.94, 1.20), (0.06, 0.06, 1.20)],
           "#a8d4de", 0.30)
    s.box(0.06, 0.04, 1.16, 0.88, 0.05, 0.05, METAL)
    s.box(0.40, 0.10, 1.02, 0.20, 0.14, 0.05, METAL)
    return s


def sofa() -> Sprite:
    s = Sprite(2, 1, 0.60, "sofa")
    s.shadow()
    body = "#738e6b"
    s.box(0.04, 0.10, 0.0, 1.92, 0.80, 0.26, darken(body, 0.12))
    s.box(0.04, 0.10, 0.0, 0.22, 0.80, 0.46, body)          # left arm
    s.box(1.74, 0.10, 0.0, 0.22, 0.80, 0.46, body)          # right arm
    s.box(0.04, 0.10, 0.0, 1.92, 0.22, 0.60, body)          # back
    s.box(0.26, 0.32, 0.26, 0.70, 0.56, 0.10, lighten(body, 0.10))
    s.box(1.00, 0.32, 0.26, 0.70, 0.56, 0.10, lighten(body, 0.10))
    s.box(0.34, 0.36, 0.36, 0.26, 0.24, 0.10, "#d8c98d")    # cushion
    return s


def stove() -> Sprite:
    s = Sprite(1, 1, 0.62, "stove")
    s.shadow()
    body = "#6b6b74"
    s.box(0.08, 0.10, 0.0, 0.84, 0.80, 0.52, body)
    s.box(0.06, 0.08, 0.52, 0.88, 0.84, 0.05, darken(body, 0.28))
    for dx, dy in [(0.30, 0.34), (0.66, 0.34), (0.30, 0.66), (0.66, 0.66)]:
        s.disc(dx, dy, 0.575, 0.11, "#33343a", squash=1.0)
        s.disc(dx, dy, 0.578, 0.07, "#4a4b52", squash=1.0)
    s.poly([(0.14, 0.10, 0.06), (0.86, 0.10, 0.06), (0.86, 0.10, 0.40), (0.14, 0.10, 0.40)],
           "#3f4048")
    s.poly([(0.20, 0.10, 0.14), (0.80, 0.10, 0.14), (0.80, 0.10, 0.32), (0.20, 0.10, 0.32)],
           "#87a2b0")
    s.poly([(0.14, 0.10, 0.44), (0.86, 0.10, 0.44), (0.86, 0.10, 0.48), (0.14, 0.10, 0.48)],
           METAL)
    return s


def table_dining() -> Sprite:
    s = Sprite(2, 1, 0.52, "table_dining")
    s.shadow()
    body = "#a68057"
    s.legs(0.14, 0.14, 1.72, 0.72, 0.46, darken(body, 0.22))
    s.box(0.02, 0.04, 0.46, 1.96, 0.92, 0.06, body)
    s.disc(0.62, 0.50, 0.52, 0.18, WHITE, squash=1.0)
    s.disc(1.38, 0.50, 0.52, 0.18, WHITE, squash=1.0)
    s.disc(1.00, 0.50, 0.52, 0.10, "#c2764f", squash=1.0)
    return s


def treadmill() -> Sprite:
    s = Sprite(1, 2, 0.86, "treadmill")
    s.shadow()
    body = "#737a85"
    s.box(0.10, 0.30, 0.0, 0.80, 1.62, 0.20, body)
    s.box(0.14, 0.42, 0.20, 0.72, 1.44, 0.05, "#31343a")     # belt
    s.box(0.12, 0.10, 0.0, 0.16, 0.26, 0.80, darken(body, 0.14))
    s.box(0.72, 0.10, 0.0, 0.16, 0.26, 0.80, darken(body, 0.14))
    s.box(0.12, 0.12, 0.72, 0.76, 0.22, 0.14, lighten(body, 0.10))
    s.poly([(0.20, 0.12, 0.76), (0.80, 0.12, 0.76), (0.80, 0.12, 0.84), (0.20, 0.12, 0.84)],
           "#8ad0c0")
    return s


def tv() -> Sprite:
    s = Sprite(1, 1, 0.86, "tv")
    s.shadow()
    stand = "#4a4f58"
    s.box(0.14, 0.22, 0.0, 0.72, 0.56, 0.30, stand)
    s.box(0.44, 0.36, 0.30, 0.12, 0.10, 0.12, darken(stand, 0.25))
    s.box(0.06, 0.34, 0.42, 0.88, 0.08, 0.44, "#20242b")
    s.poly([(0.10, 0.34, 0.46), (0.90, 0.34, 0.46), (0.90, 0.34, 0.82), (0.10, 0.34, 0.82)],
           "#2f6a8c")
    s.poly([(0.10, 0.34, 0.70), (0.36, 0.34, 0.46), (0.50, 0.34, 0.46), (0.10, 0.34, 0.80)],
           mix("#2f6a8c", "#ffffff", 0.35))
    return s


FURNITURE = [
    bed_single, bookshelf, chair, coffee_machine, computer, desk, dining_bench,
    easel, fridge, guitar, kitchen_counter, lamp, shower, sofa, stove,
    table_dining, treadmill, tv,
]


def write(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(content)


def main() -> None:
    count = 0
    tiles = [floor_wood(), floor_tile(), floor_carpet()]
    tiles += [floor_grass(i) for i in range(len(GRASS_VARIANTS))]
    for tile in tiles:
        write(os.path.join(OUT, "floors", tile.name + ".svg"), tile.to_svg())
        count += 1

    walls = [
        (wall, "wall"),
        (door, "door"),
        (window, "window"),
    ]
    for maker, name in walls:
        # The horizontal edge faces the camera's lit side, the vertical one is
        # in shade — the same rule the boxes follow.
        lit = maker(WALL_BASE, name + "_h")
        shaded = maker(darken(WALL_BASE, 0.18), name + "_v")
        write(os.path.join(OUT, "walls", name + "_h.svg"), lit.to_svg())
        write(os.path.join(OUT, "walls", name + "_v.svg"), shaded.mirrored_svg())
        count += 2

    for maker in FURNITURE:
        sprite = maker()
        write(os.path.join(OUT, "furniture", sprite.name + ".svg"), sprite.to_svg())
        # The mirrored copy is the same object with the grid axes swapped, which
        # is what an odd rotation step means.
        write(os.path.join(OUT, "furniture", sprite.name + "_r.svg"), sprite.mirrored_svg())
        count += 2

    print("wrote %d sprites to %s" % (count, OUT))


if __name__ == "__main__":
    main()
