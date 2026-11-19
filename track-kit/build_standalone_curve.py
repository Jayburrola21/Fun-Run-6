"""Build one manually placeable 90-degree curve from the original Track.obj."""
import argparse
from bisect import bisect_left, bisect_right
from dataclasses import dataclass
import math
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_track_bend import (
    ARC,
    CAP_PROFILE,
    CENTER_Z,
    FLOOR_Y,
    GROUT_UV,
    PALETTE,
    RADIUS,
    SLICES,
    SOURCE_X,
    START_HALF,
    WALL_TOP,
    WALL_WINDOWS,
    X_JOIN,
    Z_JOIN,
    MeshBatch,
    clip,
    read_obj,
    source_corners,
)


# The width of the original long straight, shared by both connections.
HALF_WIDTH = START_HALF
TANGENT = 4.0
BORDER = 12.5
INNER_JOINT_WIDTH = .22
INNER_JOINT_BEVEL = .13
BASE_BOTTOM = -.54
GROUT_TOP = -.285
WALL_DEPTH = .70845
WALL_FACE_INSET = .16
REAR_BRICK_LAP = .015
OUTER_ENTRY_BRICK_PANEL = "Mesheswalls2smenvwallquarter0126"
OUTER_BRICK_SPACING = 10.168
SECTIONS = [-TANGENT, *(ARC * n / SLICES for n in range(SLICES + 1)), ARC + TANGENT]
OUTER_EDGE = CENTER_Z - HALF_WIDTH
INNER_EDGE = CENTER_Z + HALF_WIDTH


def arc_distance(station, ratio):
    curved = max(0.0, min(station, ARC))
    return (station - curved) + curved * ratio


def track_point(station, lateral, height):
    angle = max(0.0, min(station, ARC)) / RADIUS
    radial = RADIUS - lateral
    x = X_JOIN + radial * math.sin(angle) + min(0.0, station)
    z = Z_JOIN - radial * math.cos(angle) + max(0.0, station - ARC)
    return x, FLOOR_Y + height, z


@dataclass
class Strip:
    source_x: float
    low_z: float
    high_z: float
    slope: float = 1.0
    offset: float = 0.0
    radius_ratio: float = 1.0
    stretch: float = 1.0
    edge_bevel: float = 0.0

    def __post_init__(self):
        self.cuts = [self.source_x + arc_distance(s, self.radius_ratio) / self.stretch for s in SECTIONS]

    def intersects(self, lo, hi):
        return (hi[0] > self.cuts[0] and lo[0] < self.cuts[-1]
                and hi[2] > self.low_z and lo[2] < self.high_z)

    def add(self, batch, corners):
        corners = clip(clip(corners, 2, self.low_z, True), 2, self.high_z, False)
        if self.edge_bevel:
            # Sink the clipped stone edge into the original grout bed.
            # The independently warped rows meet along a narrow gray joint.
            shoulder = self.high_z - self.edge_bevel
            self.add_warped(batch, clip(corners, 2, shoulder, False))
            bevel = clip(corners, 2, shoulder, True)
            self.add_warped(batch, [
                (x, y + min(0, GROUT_TOP - .015 - y) * (z - shoulder) / self.edge_bevel, z, u, v)
                for x, y, z, u, v in bevel
            ])
        else:
            self.add_warped(batch, corners)

    def add_warped(self, batch, corners):
        if not corners:
            return
        first = max(0, bisect_right(self.cuts, min(p[0] for p in corners)) - 1)
        stop = min(len(SECTIONS) - 1, bisect_left(self.cuts, max(p[0] for p in corners)))
        for index in range(first, stop):
            x0, x1 = self.cuts[index:index + 2]
            s0, s1 = SECTIONS[index:index + 2]
            window = clip(clip(corners, 0, x0, True), 0, x1, False)
            mapped = [(*track_point(s0 + (x - x0) * (s1 - s0) / (x1 - x0), self.offset + self.slope * z, y), u, v)
                      for x, y, z, u, v in window]
            batch.add(mapped if self.slope > 0 else mapped[::-1])


def sweep(batch, profile, stations, uv, side=0):
    def section(station):
        return [(*track_point(station, side * (HALF_WIDTH + offset) if side else offset, y), *uv)
                for offset, y in profile]

    def face(vertices):
        batch.add(vertices[::-1] if side < 0 else vertices)

    previous = section(stations[0])
    face(previous)
    for station in stations[1:]:
        current = section(station)
        for index in range(len(profile)):
            next_index = (index + 1) % len(profile)
            face([previous[index], current[index], current[next_index], previous[next_index]])
        previous = current
    face(previous[::-1])


def rectangle(left, right, bottom, top):
    return [(left, bottom), (right, bottom), (right, top), (left, top)]


def paving_strips():
    # Keep the original outside row at its previous scale, and map the
    # same chipped stones over much less source distance on the inside.
    outside_ratio = (RADIUS + HALF_WIDTH - BORDER / 2) / RADIUS
    inside_ratio = (RADIUS - HALF_WIDTH + BORDER / 2) / RADIUS
    inset = INNER_JOINT_WIDTH / 2
    return (
        Strip(SOURCE_X, OUTER_EDGE, OUTER_EDGE + BORDER, offset=-CENTER_Z),
        Strip(SOURCE_X, OUTER_EDGE + BORDER, INNER_EDGE - BORDER - inset,
              offset=-CENTER_Z, edge_bevel=INNER_JOINT_BEVEL),
        Strip(-1029.5, OUTER_EDGE, OUTER_EDGE + BORDER - inset, slope=-1.0, offset=CENTER_Z,
              radius_ratio=inside_ratio, stretch=outside_ratio, edge_bevel=INNER_JOINT_BEVEL),
    )


def wall_strip(side, rear=False):
    x, length, edge = WALL_WINDOWS[side]
    ratio = (RADIUS - HALF_WIDTH * side) / RADIUS
    # Reflect the exposed brick relief onto the back, with its base just
    # inside the wall body and its peaks under the existing cap overhang.
    depth = WALL_FACE_INSET + 2 * REAR_BRICK_LAP if rear else 1
    face = HALF_WIDTH + WALL_DEPTH + WALL_FACE_INSET + REAR_BRICK_LAP if rear else HALF_WIDTH
    slope = -1 if rear else 1
    return Strip(x, edge + min(0, side) * depth, edge + max(0, side) * depth,
                 slope=slope, offset=side * face - slope * edge,
                 radius_ratio=ratio, stretch=ratio * ARC / length)


def build(source):
    points, uvs, groups = read_obj(source)
    batches = {label: MeshBatch(label, rgb) for label, rgb in PALETTE.values()}
    wall = batches["BendWallNeutral"]
    rear_wall = MeshBatch("BendWallNeutralRear", PALETTE["Meshesfloorssmenvsewercanalcorner011Mtl"][1])
    grout = MeshBatch("BendPavingBase", PALETTE["Meshesfloorssmenvtiles021Mtl"][1])
    strips = paving_strips()
    wall_strips = {side: wall_strip(side) for side in (-1, 1)}
    rear_strips = {side: wall_strip(side, rear=True) for side in (-1, 1)}
    source_families = set()
    for group_index, group in enumerate(groups):
        is_floor = "tiles" in group.name
        if not is_floor and "wallquarter" not in group.name:
            continue
        cloud = [points[index] for index in {p[0] for f in group.faces for p in f}]
        lo, hi = tuple(map(min, zip(*cloud))), tuple(map(max, zip(*cloud)))
        if is_floor and (lo[2] + hi[2]) / 2 > INNER_EDGE - BORDER:
            # The mirrored strip supplies this row. The old row's overhang
            # would otherwise leave disconnected stone tips in the center.
            continue
        if not is_floor and hi[2] - lo[2] > 2:
            continue
        side = 1 if lo[2] > 0 else -1
        mappings = strips if is_floor else (wall_strips[side],)
        mappings = [strip for strip in mappings if strip.intersects(lo, hi)]
        if not mappings:
            continue
        batch = batches[PALETTE[group.material][0]]
        source_families.add(batch.label)
        height_offset = (0 if is_floor else WALL_TOP - FLOOR_Y) - hi[1]
        if is_floor:
            height_offset -= (.014 if batch.label == "BendPavingDark" else 0) + (group_index % 13) * .001
        fill_outer_entry = group.name == OUTER_ENTRY_BRICK_PANEL
        for face in group.faces:
            corners = list(source_corners(face, points, uvs, height_offset))
            for strip in mappings:
                strip.add(batch, corners)
            if not is_floor:
                rear_strips[side].add(rear_wall, corners)
            if fill_outer_entry:
                # Continue the source wall's brick spacing into the short
                # entry landing. The strip clips the relief at the flat end.
                previous_panel = [(x - OUTER_BRICK_SPACING, y, z, u, v) for x, y, z, u, v in corners]
                wall_strips[-1].add(wall, previous_panel)
                rear_strips[-1].add(rear_wall, previous_panel)
    if source_families != set(batches):
        raise ValueError("Load the original Track.obj export containing both kinds of paving and the stone walls")

    half_base = HALF_WIDTH + .36
    sweep(grout, rectangle(-half_base, half_base, BASE_BOTTOM, GROUT_TOP), SECTIONS, GROUT_UV)
    # One continuous backing and cap on each side, cut square on the
    # same planes as the deck. Brick relief wraps both faces of the wall.
    for side in (-1, 1):
        sweep(wall, rectangle(WALL_FACE_INSET, WALL_DEPTH, BASE_BOTTOM, 3.95), SECTIONS, (.199469, .275827), side)
        sweep(wall, CAP_PROFILE, SECTIONS, (.199705, .301077), side)
    for batch in (*batches.values(), rear_wall, grout):
        batch.flush()

    # Closed collision meshes keep the ride level and follow the visible
    # walls. Short spans limit the error of Roblox's convex collision hulls.
    floor_collision = rectangle(-HALF_WIDTH, HALF_WIDTH, -.7, 0)
    wall_collision = rectangle(0, WALL_DEPTH, -.02, 3.95)
    for name, profile, side in (("Deck", floor_collision, 0),
                                ("LeftWall", wall_collision, -1), ("RightWall", wall_collision, 1)):
        batch = MeshBatch(f"BendCollider{name}", (100, 104, 110))
        material = batch.material
        material.diffuse_color = (*material.diffuse_color[:3], 0)
        material.surface_render_method = "BLENDED"
        material.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0
        cuts = [-TANGENT, *(ARC * n / 9 for n in range(1, 9)), ARC + TANGENT]
        for start, end in zip(cuts, cuts[1:]):
            stations = [start, *(s for s in SECTIONS if start < s < end), end]
            sweep(batch, profile, stations, GROUT_UV, side)
            batch.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build(args.source)
    result = bpy.ops.export_scene.gltf(filepath=str(args.output), export_format="GLB",
                                      export_materials="EXPORT", export_yup=True, export_animations=False)
    if result != {"FINISHED"}:
        raise RuntimeError("Blender did not export the standalone curve")


if __name__ == "__main__":
    main()
