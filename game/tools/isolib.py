"""Isometric SVG toolkit — the drawing primitives every sprite is built from.

Why a generator instead of hand-drawn files: every sprite in this game has to
sit on the *same* 2:1 grid as the world (64x32 px per cell, +x down-right,
+y down-left). Hand-drawn art drifts off that grid by a pixel or two and the
seams show immediately. Here the projection is written once, so a sofa and the
floor it stands on can never disagree.

Coordinates are in cell units, not pixels:

    X  -> down-right      Y  -> down-left      Z  -> up

    screen_x = (X - Y) * 32
    screen_y = (X + Y) * 16 - Z * UNIT_Z

A sprite declares its footprint in cells and how tall it gets; the canvas is
then exactly the bounding box of that volume, which is what lets the game place
it with no per-item offsets (see Art.furniture_rect).

Light comes from the upper right of the screen: top faces are lightest, the +Y
face keeps the base colour, the +X face is darkened.
"""

from __future__ import annotations

import math

# Half-width and half-height of one cell, matching GameConstants.TILE_W/TILE_H.
UNIT_X = 32.0
UNIT_Y = 16.0
## Pixels per cell-unit of height. 1.5 units == the 48 px WALL_HEIGHT.
UNIT_Z = 32.0
## Sprites are authored at twice their in-game size so they stay sharp when the
## player zooms in to watch someone cook. Godot rasterises the SVG at its
## declared width/height and the game draws it into a half-size rectangle.
SUPERSAMPLE = 2

TOP_LIGHTEN = 0.12
X_FACE_DARKEN = 0.24
Y_FACE_DARKEN = 0.02


def hex_to_rgb(color: str) -> tuple[float, float, float]:
    color = color.lstrip("#")
    return tuple(int(color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb_to_hex(rgb: tuple[float, float, float]) -> str:
    return "#" + "".join("%02x" % max(0, min(255, round(c * 255))) for c in rgb)


def darken(color: str, amount: float) -> str:
    return rgb_to_hex(tuple(c * (1.0 - amount) for c in hex_to_rgb(color)))


def lighten(color: str, amount: float) -> str:
    return rgb_to_hex(tuple(c + (1.0 - c) * amount for c in hex_to_rgb(color)))


def mix(a: str, b: str, t: float) -> str:
    ca, cb = hex_to_rgb(a), hex_to_rgb(b)
    return rgb_to_hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


class Tile:
    """A ground material, drawn in texture space rather than screen space.

    Floors are not sprites. A tile sprite with transparent corners meets its
    neighbour at two antialiased half-pixels, and the map picks up a lattice of
    seams that no amount of nudging removes. So a floor is a plain square image
    that the game maps onto the cell's diamond with UV coordinates: the polygon
    defines the shape, adjacent cells share their edges exactly, and every pixel
    is drawn once.

    The square's u axis becomes the world's +x (down-right on screen) and v
    becomes +y (down-left), so a band of constant v is a plank running
    down-right. Both axes are the same length on screen, so nothing is
    stretched.
    """

    def __init__(self, name: str, size: int = 64):
        self.name = name
        self.size = size
        self._parts: list[str] = []

    def rect(self, u, v, w, h, color: str, opacity: float = 1.0) -> None:
        extra = "" if opacity >= 1.0 else ' fill-opacity="%.3f"' % opacity
        self._parts.append('<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="%s"%s/>'
                           % (u * self.size, v * self.size, w * self.size, h * self.size,
                              color, extra))

    def dot(self, u, v, radius, color: str, opacity: float = 1.0) -> None:
        extra = "" if opacity >= 1.0 else ' fill-opacity="%.3f"' % opacity
        self._parts.append('<circle cx="%.3f" cy="%.3f" r="%.3f" fill="%s"%s/>'
                           % (u * self.size, v * self.size, radius * self.size, color, extra))

    def to_svg(self) -> str:
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
                'viewBox="0 0 %d %d">%s</svg>\n'
                % (self.size * SUPERSAMPLE, self.size * SUPERSAMPLE,
                   self.size, self.size, "".join(self._parts)))


class Sprite:
    """One SVG file: a footprint of `cells_x` by `cells_y` and a height in units."""

    def __init__(self, cells_x: int, cells_y: int, height: float, name: str = ""):
        self.cells_x = cells_x
        self.cells_y = cells_y
        self.height = height
        self.name = name
        self.width_px = (cells_x + cells_y) * UNIT_X
        # Rounded up to a whole pixel: the game positions a sprite by its
        # bottom edge, so a fractional canvas height would offset every object
        # by a fraction of a pixel. The slack goes above the object, where
        # nothing is drawn.
        self.height_px = float(math.ceil((cells_x + cells_y) * UNIT_Y + height * UNIT_Z))
        # Origin of the sprite canvas: the footprint's left corner is at x = 0,
        # and the footprint's bottom corner is on the bottom edge.
        self._ox = cells_y * UNIT_X
        self._oy = self.height_px - (cells_x + cells_y) * UNIT_Y
        self._parts: list[str] = []

    # --- projection ---------------------------------------------------------

    def project(self, x: float, y: float, z: float) -> tuple[float, float]:
        return (
            (x - y) * UNIT_X + self._ox,
            (x + y) * UNIT_Y - z * UNIT_Z + self._oy,
        )

    # --- primitives ---------------------------------------------------------

    def poly(self, points, color: str, opacity: float = 1.0) -> None:
        path = " ".join("%.2f,%.2f" % self.project(*p) for p in points)
        extra = "" if opacity >= 1.0 else ' fill-opacity="%.3f"' % opacity
        self._parts.append('<polygon points="%s" fill="%s"%s/>' % (path, color, extra))

    def box(self, x, y, z, w, d, h, color, top_color=None, x_color=None, y_color=None):
        """An axis-aligned box. Only the three faces a 2:1 camera can see."""
        x2, y2, z2 = x + w, y + d, z + h
        self.poly(
            [(x2, y, z), (x2, y2, z), (x2, y2, z2), (x2, y, z2)],
            x_color or darken(color, X_FACE_DARKEN),
        )
        self.poly(
            [(x, y2, z), (x2, y2, z), (x2, y2, z2), (x, y2, z2)],
            y_color or darken(color, Y_FACE_DARKEN),
        )
        self.poly(
            [(x, y, z2), (x2, y, z2), (x2, y2, z2), (x, y2, z2)],
            top_color or lighten(color, TOP_LIGHTEN),
        )

    def plate(self, x, y, z, w, d, color, opacity: float = 1.0) -> None:
        """A flat rectangle lying on a horizontal plane — rug, screen glow, hob."""
        self.poly([(x, y, z), (x + w, y, z), (x + w, y + d, z), (x, y + d, z)], color, opacity)

    def wall_panel(self, x, y, z, w, d, h, color, axis: str = "x") -> None:
        """A single upright face, for things too thin to be a box (a canvas, a
        pane of glass)."""
        if axis == "x":
            self.poly([(x, y, z), (x + w, y, z), (x + w, y + d, z + h), (x, y + d, z + h)], color)
        else:
            self.poly([(x, y, z), (x, y + d, z), (x + w, y + d, z + h), (x + w, y, z + h)], color)

    def disc(self, cx, cy, z, radius, color, opacity: float = 1.0, segments: int = 24,
             squash: float = 1.0) -> None:
        points = []
        for i in range(segments):
            angle = math.tau * i / segments
            points.append((cx + math.cos(angle) * radius,
                           cy + math.sin(angle) * radius * squash, z))
        self.poly(points, color, opacity)

    def cylinder(self, cx, cy, z, radius, height, color, segments: int = 20) -> None:
        # The visible half of the side wall, then the lid.
        side = []
        for i in range(segments + 1):
            angle = math.pi * i / segments
            side.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, z))
        top = [(p[0], p[1], z + height) for p in reversed(side)]
        self.poly(side + top, darken(color, X_FACE_DARKEN * 0.7))
        self.disc(cx, cy, z + height, radius, lighten(color, TOP_LIGHTEN), segments=segments * 2)

    def cone(self, cx, cy, z, radius_bottom, radius_top, height, color, segments: int = 20) -> None:
        """A truncated cone standing on its base — a lampshade, a bin, a pot."""
        lower, upper = [], []
        for i in range(segments + 1):
            angle = math.pi * i / segments
            lower.append((cx + math.cos(angle) * radius_bottom,
                          cy + math.sin(angle) * radius_bottom, z))
            upper.append((cx + math.cos(angle) * radius_top,
                          cy + math.sin(angle) * radius_top, z + height))
        self.poly(lower + list(reversed(upper)), darken(color, X_FACE_DARKEN * 0.6))
        self.disc(cx, cy, z + height, radius_top, lighten(color, TOP_LIGHTEN),
                  segments=segments * 2)

    def shadow(self, inset: float = 0.06, opacity: float = 0.16) -> None:
        """Contact shadow over the whole footprint. Drawn first, so everything
        else stands on it."""
        a, b = inset, 1.0 - inset
        self.poly([
            (a, a, 0.0),
            (self.cells_x - a, a, 0.0),
            (self.cells_x - a, self.cells_y - a, 0.0),
            (a, self.cells_y - a, 0.0),
        ], "#101018", opacity)

    def legs(self, x, y, w, d, height, color, thickness: float = 0.09) -> None:
        """Four legs under a tabletop, in the corners of the given rectangle."""
        t = thickness
        for lx, ly in [(x, y), (x + w - t, y), (x, y + d - t), (x + w - t, y + d - t)]:
            self.box(lx, ly, 0.0, t, t, height, color)

    # --- output -------------------------------------------------------------

    def to_svg(self) -> str:
        header = (
            '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
            'viewBox="0 0 %.2f %.2f">' % (
                round(self.width_px * SUPERSAMPLE),
                round(self.height_px * SUPERSAMPLE),
                self.width_px,
                self.height_px,
            )
        )
        return header + "".join(self._parts) + "</svg>\n"

    def mirrored_svg(self) -> str:
        """The same sprite seen with the two grid axes swapped.

        Mirroring the screen x axis is exactly what swapping x and y does in this
        projection, so one authored sprite covers both orientations of a rotated
        object — including a 2x1 bed becoming 1x2.
        """
        body = "".join(self._parts)
        header = (
            '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
            'viewBox="0 0 %.2f %.2f">' % (
                round(self.width_px * SUPERSAMPLE),
                round(self.height_px * SUPERSAMPLE),
                self.width_px,
                self.height_px,
            )
        )
        return (header + '<g transform="translate(%.2f,0) scale(-1,1)">' % self.width_px
                + body + "</g></svg>\n")
