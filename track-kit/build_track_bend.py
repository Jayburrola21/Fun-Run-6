"""Warp the original Studio Track.obj into the fitted Fun Run 6 bend.

Usage: blender -b --python-exit-code 1 --python build_track_bend.py -- Track.obj TrackBend.glb
The script reads geometry and UVs only. The Studio placement command restores
the original Roblox texture URI and material tints.
"""
import argparse
from collections import Counter
from dataclasses import dataclass, field
import math
from pathlib import Path
import sys

import bpy


X_JOIN = -849.23868
Z_JOIN = 24.72034
CENTER_X = -802.23868
CENTER_Z = -22.27966
FLOOR_Y = 27.10
RADIUS = 47.0
START_HALF = 31.47665
END_HALF = 31.57025
ARC = math.pi * RADIUS / 2
SLICES = 48
SOURCE_X = -925.0
WALL_TOP = 31.05
MAX_TRIANGLES = 7800
PALETTE = {
    "Meshesfloorssmenvtiles021Mtl": ("BendPavingSlate", (88, 92, 108)),
    "Meshesfloorssmenvtiles041Mtl": ("BendPavingDark", (52, 54, 66)),
    "Meshesfloorssmenvsewercanalcorner011Mtl": ("BendWallNeutral", (163, 162, 165)),
}
# The inner and outer walls get their own straight source lengths so
# their original brick proportions are carried around separate radii.
WALL_WINDOWS = {
    -1: (-998.0, 123.90, -53.75631),
    1: (-924.0, 23.75, 9.19699),
}


@dataclass
class Group:
    name: str
    material: str = ""
    faces: list = field(default_factory=list)


def read_obj(path):
    """Read the Studio export's world-coordinate positions and UVs."""
    points, uvs, groups = [None], [None], []
    current = None
    with path.open(encoding="utf-8-sig") as source:
        for raw in source:
            command, _, values = raw.strip().partition(" ")
            if command == "v":
                points.append(tuple(map(float, values.split()[:3])))
            elif command == "vt":
                uvs.append(tuple(map(float, values.split()[:2])))
            elif command == "g":
                current = Group(values)
                groups.append(current)
            elif command == "usemtl":
                current.material = values
            elif command == "f":
                face = [tuple(map(int, item.split("/")[:2])) for item in values.split()]
                if len(face) != 3 or any(v <= 0 or uv <= 0 for v, uv in face):
                    raise ValueError("Expected triangulated Studio faces with positive UV indices")
                current.faces.append(face)
    return points, uvs, groups


def clip(corners, axis, plane, greater):
    if not corners:
        return []
    sign = 1 if greater else -1
    result = []
    previous = corners[-1]
    old_distance = sign * (previous[axis] - plane)
    for current in corners:
        distance = sign * (current[axis] - plane)
        if (distance < 0) != (old_distance < 0):
            t = old_distance / (old_distance - distance)
            cut = [a + (b - a) * t for a, b in zip(previous, current)]
            cut[axis] = plane
            result.append(tuple(cut))
        if distance >= 0:
            result.append(current)
        previous, old_distance = current, distance
    return result


def bend_point(station, lane, height, wall_offset=0):
    progress = station / ARC
    blend = progress * progress * (3 - 2 * progress)
    width = START_HALF + (END_HALF - START_HALF) * blend
    radial = RADIUS - (lane * width + wall_offset)
    angle = station / RADIUS
    return X_JOIN + radial * math.sin(angle), FLOOR_Y + height, Z_JOIN - radial * math.cos(angle)


def warped(corners, transform):
    # The nonlinear bend needs intermediate stations on existing faces.
    # Split before applying it and interpolate the original UVs on cuts.
    step = ARC / SLICES
    first = max(0, min(SLICES - 1, math.floor(min(p[0] for p in corners) / step)))
    last = max(first, min(SLICES - 1, math.ceil(max(p[0] for p in corners) / step) - 1))
    for index in range(first, last + 1):
        poly = clip(corners, 0, step * index, True)
        poly = clip(poly, 0, step * (index + 1), False)
        yield [(*transform(p[0], p[1], p[2]), *p[3:]) for p in poly]


def palette_material(label, rgb):
    def linear(channel):
        srgb = channel / 255
        return srgb / 12.92 if srgb <= .04045 else ((srgb + .055) / 1.055) ** 2.4

    material = bpy.data.materials.new(label)
    material.use_nodes = True
    material.diffuse_color = (*map(linear, rgb), 1)
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = material.diffuse_color
    shader.inputs["Roughness"].default_value = .86
    return material


class MeshBatch:
    def __init__(self, label, color):
        self.label = label
        self.material = palette_material(label, color)
        self.triangles = []
        self.objects = []

    def add(self, polygon):
        for i in range(1, len(polygon) - 1):
            triangle = (polygon[0], polygon[i], polygon[i + 1])
            if len({p[:3] for p in triangle}) < 3:
                continue
            a, b, c = (p[:3] for p in triangle)
            ab = [t - s for s, t in zip(a, b)]
            ac = [t - s for s, t in zip(a, c)]
            normal = [ab[j] * ac[k] - ab[k] * ac[j] for j, k in ((1, 2), (2, 0), (0, 1))]
            if math.hypot(*normal) < 1e-9:
                continue
            self.triangles.append(triangle)
            if len(self.triangles) >= MAX_TRIANGLES:
                self.flush()

    def flush(self):
        if not self.triangles:
            return
        verts, faces, lookup = [], [], {}
        for triangle in self.triangles:
            face = []
            for x, y, z, _, _ in triangle:
                # +X world travel becomes Blender +Y / Roblox local -Z.
                point = (round(z - CENTER_Z, 7), round(x - X_JOIN, 7), round(y - FLOOR_Y, 7))
                index = lookup.get(point)
                if index is None:
                    index = len(verts)
                    lookup[point] = index
                    verts.append(point)
                face.append(index)
            faces.append(face)
        name = f"{self.label}{len(self.objects) + 1:02d}"
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="Original UV")
        for face, triangle in zip(mesh.polygons, self.triangles, strict=True):
            for index, p in zip(face.loop_indices, triangle, strict=True):
                uv.data[index].uv = p[3:]
        mesh.materials.append(self.material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        self.objects.append(obj)
        self.triangles = []


def source_corners(indices, points, uvs, height_delta=0):
    for position_index, uv_index in indices:
        x, y, z = points[position_index]
        yield x, y + height_delta, z, *uvs[uv_index]


def sweep_profile(batch, side, profile, uv):
    """A continuous profile, with a source-atlas UV for each corner."""
    def section(station):
        return [(*bend_point(station, side, y, side * offset), *uv)
                if side else (*bend_point(station, offset, y), *uv) for offset, y in profile]

    mirrored = side < 0
    previous = section(0)
    batch.add(previous[::-1] if mirrored else previous)
    for index in range(1, SLICES + 1):
        current = section(ARC * index / SLICES)
        for j in range(len(profile)):
            k = (j + 1) % len(profile)
            quad = [previous[j], current[j], current[k], previous[k]]
            batch.add(quad[::-1] if mirrored else quad)
        previous = current
    batch.add(previous if mirrored else previous[::-1])


def make_markers():
    for name, pt in (
        ("TrackBendEntry", (0, 0, 0)),
        ("TrackBendForward", (0, 2, 0)),
        ("TrackBendUp", (0, 0, 2)),
    ):
        bpy.ops.mesh.primitive_cube_add(size=.10, location=pt)
        bpy.context.object.name = name
        bpy.context.object.data.name = name


def build(source):
    points, uvs, groups = read_obj(source)
    batches = {label: MeshBatch(label, rgb) for label, rgb in PALETTE.values()}
    base = MeshBatch("BendPavingBase", (50, 52, 61))
    wall = batches["BendWallNeutral"]
    if Counter(g.material for g in groups) != Counter({key: n for key, n in zip(PALETTE, (126, 87, 63))}):
        raise ValueError("Load the matching Track.obj Studio export")
    replaced_counts = Counter()
    source_counts = Counter()
    for group_index, group in enumerate(groups):
        if not ("tiles" in group.name or "wallquarter" in group.name):
            continue
        cloud = [points[index] for index in {item[0] for face in group.faces for item in face}]
        lo, hi = tuple(map(min, zip(*cloud))), tuple(map(max, zip(*cloud)))
        is_floor = "tiles" in group.name
        batch = batches[PALETTE[group.material][0]]
        baseline = FLOOR_Y if is_floor else WALL_TOP
        level = baseline - hi[1]
        if is_floor:
            # The source has overlapping carved edges. Keep their
            # visual depths distinct while Studio supplies one flat deck.
            level -= (.009 if batch.label == "BendPavingDark" else 0) + (group_index % 13) * .0002
        affected = hi[0] > X_JOIN + .0001 and lo[2] < Z_JOIN - .0001
        if affected:
            replaced_counts["floor" if is_floor else "wall"] += 1
            for face in group.faces:
                corners = list(source_corners(face, points, uvs, level))
                # Retain the exact UV/position of original meshes up to both
                # tangent cuts when their old instance crosses the join.
                batch.add(clip(corners, 0, X_JOIN, False))
                batch.add(clip(clip(corners, 0, X_JOIN, True), 2, Z_JOIN, True))
        window = (SOURCE_X, ARC) if is_floor else WALL_WINDOWS[1 if lo[2] > 0 else -1][:2]
        source_x, runoff = window
        if hi[0] <= source_x or lo[0] >= source_x + runoff:
            continue
        if is_floor and (hi[2] < CENTER_Z - START_HALF or lo[2] > CENTER_Z + START_HALF):
            continue
        if not is_floor and hi[2] - lo[2] > 2:
            continue  # The long straight is the source of this wall unfold.
        source_counts["floor" if is_floor else "wall"] += 1
        for face in group.faces:
            corners = list(source_corners(face, points, uvs, level))
            if is_floor:
                corners = clip(corners, 2, CENTER_Z - START_HALF, True)
                corners = clip(corners, 2, CENTER_Z + START_HALF, False)
                normalized = [((x - source_x) * ARC / runoff, (z - CENTER_Z) / START_HALF, y - FLOOR_Y, u, v)
                              for x, y, z, u, v in corners]
                if normalized:
                    for result in warped(normalized, bend_point):
                        batch.add(result)
            else:
                sign = 1 if lo[2] > 0 else -1
                edge = WALL_WINDOWS[sign][2]
                normalized = [((x - source_x) * ARC / runoff, z - edge, y - FLOOR_Y, u, v)
                              for x, y, z, u, v in corners]
                for result in warped(normalized, lambda s, lateral, y: bend_point(s, sign, y, lateral)):
                    wall.add(result)

    # Dark backing sits below the paving relief, at the levels of
    # original mortar gaps. The flat drive deck is placed in Studio.
    sweep_profile(base, 0, [(-1, -.59), (1, -.59), (1, -.295), (-1, -.295)], (0, 0))
    for side in (-1, 1):
        # Close tiny wall-end openings behind the original front brickwork.
        sweep_profile(wall, side, [(.22, -.45), (.68, -.45), (.68, 3.98), (.22, 3.98)], (.199469, .275827))
        # Form the continuous top with the source canal lip's bevel and
        # exact upward UV swatch, without including the outer trough.
        sweep_profile(wall, side, [(-.20, 3.89), (.804, 3.89), (.804, 4.206),
                                  (-.034, 4.206), (-.20, 3.967)], (.199705, .301077))
    for batch in (*batches.values(), base):
        batch.flush()
    print("Source groups used:", source_counts)
    assert replaced_counts == {"floor": 37, "wall": 22}, replaced_counts
    make_markers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build(options.source)
    options.output.parent.mkdir(parents=True, exist_ok=True)
    result = bpy.ops.export_scene.gltf(filepath=str(options.output), export_format="GLB",
                                      export_materials="EXPORT", export_yup=True, export_animations=False)
    if result != {"FINISHED"}:
        raise RuntimeError("Blender did not export the replacement bend")


if __name__ == "__main__":
    main()
