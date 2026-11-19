"""Build the Studio model for the modular Fun Run 6 track.

Outputs a native Roblox XML model. Rojo can turn it into the compact RBXM
distributed with the kit. The mesh and texture references are those of the
uploaded track, so Studio loads its existing art assets.
"""

import argparse
from dataclasses import dataclass
from itertools import count
import math
from pathlib import Path
import xml.etree.ElementTree as ET


WIDTH = 63.0
RADIUS = 64.0
WALL_WIDTH = .71
WALL_HEIGHT = 3.95  # Crest above the drive plane, matching the source track.
WALL_BODY_HEIGHT = 4.54335
COLLIDER_SURFACE = 0
TEXTURE = "rbxassetid://2913129928"
UP = (0., 1., 0.)
IDENTITY = ((1., 0., 0.), UP, (0., 0., 1.))
SLATE = (88, 92, 108)
DARK = (52, 54, 66)
WALL_TINT = (163, 162, 165)
GROUT = (50, 52, 61)

# Geometry IDs, authored dimensions, and placed thicknesses from track.rbxm.
TILES = {
    "01": (2915142986, (5.986844, .222219, 5.986829), .48135),
    "02": (2915144303, (5.986833, .200303, 5.986829), .43387),
    "04": (2915143223, (5.987597, .121431, 5.986828), .26303),
    "05": (2915144878, (5.986830, .125747, 5.986831), .27238),
    "06": (2915144807, (5.990461, .121440, 5.988554), .31752),
    "07": (2915143648, (5.987610, .154783, 5.987959), .33527),
    "08": (2915144183, (5.988016, .120976, 5.988151), .26205),
    "010": (2915143499, (5.987598, .121431, 5.986848), .26303),
}
WALL_ASSET = (2915568624, (2.521559, 2.50517, .390636), WALL_BODY_HEIGHT)
# The border rows alternate the two saved tints. The center mixes larger
# staggered stretches of the 07/08 pavement found between those borders.
BORDER_LEFT = (
    ("04", SLATE, 2), ("02", DARK, 1), ("010", SLATE, 2), ("02", DARK, 2),
    ("010", SLATE, 2), ("01", DARK, 1), ("04", SLATE, 2), ("02", DARK, 1),
    ("05", SLATE, 2), ("01", DARK, 3),
)
BORDER_RIGHT = (
    ("04", SLATE, 2), ("01", DARK, 1), ("04", SLATE, 2), ("01", DARK, 3),
    ("010", SLATE, 0), ("02", DARK, 0), ("04", SLATE, 2), ("01", DARK, 1),
    ("05", SLATE, 2), ("01", DARK, 1),
)
CENTER = (
    ("07", SLATE, 0), ("07", SLATE, 1), ("08", DARK, 0), ("07", SLATE, 2),
    ("07", DARK, 3), ("08", SLATE, 1), ("07", SLATE, 1), ("08", DARK, 3),
)
SECTION_SPECS = (
    ("Straight 64", (0, 0, 0), 64, 0),
    ("Straight 128", (205, 0, 0), 128, 0),
    ("Curve Left 45", (0, 0, -200), 0, -45),
    ("Curve Right 45", (205, 0, -200), 0, 45),
    ("Curve Left 90", (0, 0, -380), 0, -90),
    ("Curve Right 90", (205, 0, -380), 0, 90),
)


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(v, scale):
    return tuple(x * scale for x in v)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    return mul(v, 1 / math.hypot(*v))


def prop(parent, kind, name, value):
    item = ET.SubElement(parent, kind, {"name": name})
    item.text = str(value)
    return item


def fields(parent, keys, values):
    for key, val in zip(keys, values):
        ET.SubElement(parent, key).text = f"{val:.9f}"


def vector(parent, name, point):
    fields(ET.SubElement(parent, "Vector3", {"name": name}), "XYZ", point)


def cframe(parent, name, p, axes=IDENTITY):
    element = ET.SubElement(parent, "CoordinateFrame", {"name": name})
    fields(element, "XYZ", p)
    flattened = [axes[col][row] for row in range(3) for col in range(3)]
    fields(element, [f"R{row}{col}" for row in range(3) for col in range(3)], flattened)


def tint(parent, rgb):
    r, g, b = rgb
    prop(parent, "Color3uint8", "Color3uint8", (r << 16) | (g << 8) | b)


def content(parent, name, url):
    ET.SubElement(ET.SubElement(parent, "Content", {"name": name}), "url").text = url


@dataclass(frozen=True)
class Section:
    name: str
    origin: tuple
    length: float
    turn: int

    @property
    def sweep(self):
        return math.radians(abs(self.turn))

    @property
    def turn_sign(self):
        return 1 if self.turn > 0 else -1

    def frame(self, station, offset=0, height=0):
        if self.turn == 0:
            return (offset, height, -station), IDENTITY
        side = self.turn_sign
        c, s = math.cos(station), math.sin(station)
        right = (c, 0, side * s)
        back = (-side * s, 0, c)
        middle = (side * RADIUS * (1 - c), height, -RADIUS * s)
        return add(middle, mul(right, offset)), (right, UP, back)

    def join(self):
        return self.frame(self.length if self.turn == 0 else self.sweep)


class TrackKit:
    def __init__(self):
        self.refs = count()
        self.root = ET.Element("roblox", {"version": "4"})

    def item(self, parent, class_name, name):
        instance = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{next(self.refs)}"})
        props = ET.SubElement(instance, "Properties")
        prop(props, "string", "Name", name)
        return instance, props

    def part(self, parent, class_name, name, position, axes, size, solid, transparency, color):
        instance, props = self.item(parent, class_name, name)
        cframe(props, "CFrame", position, axes)
        vector(props, "size", size)
        tint(props, color)
        prop(props, "token", "Material", 816)  # Concrete in the source model.
        prop(props, "float", "Transparency", transparency)
        for key, val in {
            "Anchored": True,
            "CanCollide": solid,
            "CanQuery": solid,
            "CanTouch": False,
            "CastShadow": transparency == 0,
        }.items():
            prop(props, "bool", key, "true" if val else "false")
        return instance, props

    def mesh(self, parent, name, asset, position, axes, size, color, cast_shadow=True):
        instance, props = self.part(parent, "MeshPart", name, position, axes, size, False, 0, color)
        props.find("bool[@name='CastShadow']").text = "true" if cast_shadow else "false"
        content(props, "MeshId", f"rbxassetid://{asset[0]}")
        content(props, "TextureID", TEXTURE)
        vector(props, "InitialSize", asset[1])
        return instance

    def tile(self, parent, section, pattern, width, length, station, offset):
        name, color, quarter = pattern
        asset = TILES[name]
        height = asset[2]
        p, (right, up, back) = section.frame(station, offset, -height / 2)
        if quarter == 1:
            axes = (mul(back, -1), up, right)
        elif quarter == 2:
            axes = (mul(right, -1), up, mul(back, -1))
        elif quarter == 3:
            axes = (back, up, mul(right, -1))
        else:
            axes = (right, up, back)
        size = (length, height, width) if quarter % 2 else (width, height, length)
        self.mesh(parent, f"Tiles_{name}", asset, add(section.origin, p), axes, size, color, cast_shadow=False)

    def box(self, parent, section, name, station, offset, height, size, solid, transparency, color):
        p, axes = section.frame(station, offset, height)
        return self.part(parent, "Part", name, add(section.origin, p), axes, size, solid, transparency, color)

    def triangle(self, parent, name, section, points, thickness, solid, transparency, color):
        # A flat wedge prism is a native physics part. Its local X axis
        # is vertical here and its triangular face stays in the road plane.
        a, b, c = points
        if math.dist(a, c) > math.dist(b, c):
            a, b = b, a
        if math.dist(a, b) > math.dist(b, c):
            a, c = c, a
        along = unit(sub(c, b))
        endpoint = add(b, mul(along, dot(sub(a, b), along)))
        height = math.dist(a, endpoint)
        if height < 1e-6:
            return
        up = unit(sub(a, endpoint))
        for tip in (b, c):
            run = math.dist(tip, endpoint)
            if run < 1e-6:
                continue
            back = unit(sub(endpoint, tip))
            right = unit(cross(up, back))
            center = add(section.origin, mul(add(a, tip), .5))
            self.part(parent, "WedgePart", name, center, (right, up, back),
                      (thickness, height, run), solid, transparency, color)

    def curved_strip(self, parent, section, name, offsets, top, thickness, solid, transparency, color):
        subdivisions = math.ceil(math.degrees(section.sweep) / 5)
        for i in range(subdivisions):
            a, b = (section.sweep * k / subdivisions for k in (i, i + 1))
            current_left = section.frame(a, offsets[0], top - thickness * .5)[0]
            current_right = section.frame(a, offsets[1], top - thickness * .5)[0]
            next_left = section.frame(b, offsets[0], top - thickness * .5)[0]
            next_right = section.frame(b, offsets[1], top - thickness * .5)[0]
            self.triangle(parent, name, section, (current_left, current_right, next_right),
                          thickness, solid, transparency, color)
            self.triangle(parent, name, section, (current_left, next_right, next_left),
                          thickness, solid, transparency, color)

    def deck(self, model, section):
        folder, _ = self.item(model, "Folder", "Level driving deck")
        wall_collision, _ = self.item(model, "Folder", "Wall collision")
        if section.turn == 0:
            length = section.length
            self.box(folder, section, "Driving surface", length / 2, 0, COLLIDER_SURFACE - .35,
                     (WIDTH, .70, length), True, 1, GROUT)
            self.box(folder, section, "Grout under paving", length / 2, 0, -.565,
                     (WIDTH, .35, length), False, 0, GROUT)
            for side in (-1, 1):
                self.box(wall_collision, section, "Barrier", length / 2, side * (WIDTH + WALL_WIDTH) / 2,
                         WALL_HEIGHT / 2, (WALL_WIDTH, WALL_HEIGHT, length), True, 1, GROUT)
        else:
            self.curved_strip(folder, section, "Driving surface", (-WIDTH / 2, WIDTH / 2),
                              COLLIDER_SURFACE, .70, True, 1, GROUT)
            self.curved_strip(folder, section, "Grout under paving", (-WIDTH / 2, WIDTH / 2),
                              -.39, .35, False, 0, GROUT)
            for side in (-1, 1):
                radii = sorted([side * (WIDTH / 2), side * (WIDTH / 2 + WALL_WIDTH)])
                self.curved_strip(wall_collision, section, "Barrier", radii,
                                  WALL_HEIGHT, WALL_HEIGHT, True, 1, GROUT)

    def pavement(self, model, section):
        floor, _ = self.item(model, "Folder", "Stone paving")
        band_width = WIDTH / 5
        for row in range(5):
            pattern = BORDER_LEFT if row == 0 else BORDER_RIGHT if row == 4 else CENTER
            band, _ = self.item(floor, "Folder", ("Left border", "Center left", "Center", "Center right", "Right border")[row])
            offset = (row - 2) * band_width
            if section.turn == 0:
                # Small border repeats and offset center seams give the
                # center the original broad, staggered slab layout.
                shift = (0, -3.2, 3.2, 0, 0)[row]
                count_tiles = round(section.length / 12.8)
                boundaries = [0] + [i * section.length / count_tiles + shift for i in range(1, count_tiles)] + [section.length]
                i = 0
                tile_count = 0
                while i < len(boundaries) - 1:
                    skip = 2 if 0 < row < 4 and (tile_count + row) % 3 == 0 and i + 2 < len(boundaries) else 1
                    a, b = boundaries[i], boundaries[i + skip]
                    choice = pattern[(tile_count + (row * 3 if 0 < row < 4 else 0)) % len(pattern)]
                    self.tile(band, section, choice, band_width - .014, b - a - .014, (a + b) / 2, offset)
                    i += skip
                    tile_count += 1
                continue
            radius = RADIUS - section.turn_sign * offset
            count_tiles = max(math.ceil(math.degrees(section.sweep) / 10), round(radius * section.sweep / 13))
            # Offset internal tile seams in the center bands without
            # shifting the two shared section connection planes.
            step = section.sweep / count_tiles
            phase = (0, -.19, .17, -.09, 0)[row]
            bounds = [0] + [(i + phase) * step for i in range(1, count_tiles)] + [section.sweep]
            inner = radius - band_width / 2
            for i, (a, b) in enumerate(zip(bounds, bounds[1:])):
                half = (b - a) / 2
                # Fit a rigid original tile within its ring sector.
                # This leaves tapered grout joints without overlap or
                # textures that spill across a section's end.
                outer = (radius + band_width / 2) * math.cos(half)
                fitted_radius = (inner + outer) / 2
                fitted_width = outer - inner - .016
                fitted_length = 2 * inner * math.tan(half) - .016
                fitted_offset = section.turn_sign * (RADIUS - fitted_radius)
                choice = pattern[(i + (row * 3 if 0 < row < 4 else 0)) % len(pattern)]
                if row == 2 + section.turn_sign and i == count_tiles // 2:
                    choice = ("06", SLATE, section.turn_sign % 4)
                self.tile(band, section, choice, fitted_width, fitted_length, (a + b) / 2, fitted_offset)

    def walls(self, model, section):
        folder, _ = self.item(model, "Folder", "Original brick walls")
        for side in (-1, 1):
            band, _ = self.item(folder, "Folder", "Left wall" if side == -1 else "Right wall")
            offset = side * (WIDTH + WALL_WIDTH) / 2
            if section.turn == 0:
                pieces = math.ceil(section.length / 11)
                spans = [section.length / pieces] * pieces
                stations = [(i + .5) * section.length / pieces for i in range(pieces)]
                offsets = [offset] * pieces
            else:
                radius = RADIUS - section.turn_sign * offset
                pieces = max(math.ceil(radius * section.sweep / 11), math.ceil(math.degrees(section.sweep) / 9))
                delta = section.sweep / pieces
                chord = radius * math.cos(delta / 2)
                spans = [2 * (chord - WALL_WIDTH / 2) * math.tan(delta / 2)] * pieces
                stations = [(i + .5) * delta for i in range(pieces)]
                offsets = [section.turn_sign * (RADIUS - chord)] * pieces

            for station, lane_offset, span in zip(stations, offsets, spans):
                p, (right, up, back) = section.frame(station, lane_offset, WALL_HEIGHT - WALL_BODY_HEIGHT / 2)
                axes = (mul(back, -side), up, mul(right, side))
                self.mesh(band, "Wall_Quarter_01", WALL_ASSET, add(p, section.origin), axes,
                          (span, WALL_BODY_HEIGHT, WALL_WIDTH), WALL_TINT)

    def section(self, parent, section):
        model, props = self.item(parent, "Model", section.name)
        marker, _ = self.part(model, "Part", "Connectors", section.origin, IDENTITY,
                              (.25, .25, .25), False, 1, GROUT)
        prop(props, "Ref", "PrimaryPart", marker.attrib["referent"])
        _, in_props = self.item(marker, "Attachment", "TrackIn")
        cframe(in_props, "CFrame", (0, 0, 0))
        _, out_props = self.item(marker, "Attachment", "TrackOut")
        cframe(out_props, "CFrame", *section.join())
        self.deck(model, section)
        self.pavement(model, section)
        self.walls(model, section)

    def write(self, output):
        model, _ = self.item(self.root, "Model", "Fun Run 6 Track Kit")
        for spec in SECTION_SPECS:
            self.section(model, Section(*spec))
        output.parent.mkdir(parents=True, exist_ok=True)
        ET.indent(self.root)
        ET.ElementTree(self.root).write(output, encoding="utf-8", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("FunRun6-TrackKit.rbxmx"))
    args = parser.parse_args()
    TrackKit().write(args.output)
    print(f"Built {len(SECTION_SPECS)} modular sections in {args.output}")


if __name__ == "__main__":
    main()
