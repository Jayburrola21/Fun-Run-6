"""Export a single repeat of the track's double-sided brick wall."""
import argparse
from itertools import combinations
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_track_bend import MeshBatch, read_obj
from build_standalone_straight import (
    BASE_BOTTOM,
    CAP_PROFILE,
    HALF_WIDTH,
    OUTER_BRICK_SPACING,
    WALL_BODY_UV,
    WALL_COLOR,
    WALL_DEPTH,
    WALL_FACE_INSET,
    add_bricks,
    finish_wall,
    world_to_blender,
)


WALL_CENTER = HALF_WIDTH + (min(p[0] for p in CAP_PROFILE) + max(p[0] for p in CAP_PROFILE)) / 2


def wall_point(x, lateral, height):
    return x, height, lateral - WALL_CENTER


def finish_brick_cuts(wall, half_length):
    bottom, top = BASE_BOTTOM, CAP_PROFILE[0][1]
    front = HALF_WIDTH + WALL_FACE_INSET - WALL_CENTER
    rear = HALF_WIDTH + WALL_DEPTH - WALL_CENTER
    profiles = {(bottom, top, 0, front), (bottom, top, 0, rear)}
    for triangle in wall.triangles:
        edge = sorted((y, z) for x, y, z, _, _ in triangle if x == -half_length)
        if len(edge) != 2:
            continue
        (y0, z0), (y1, z1) = edge
        low, high = max(y0, bottom), min(y1, top)
        if high - low > 1e-8:
            slope = (z1 - z0) / (y1 - y0)
            profiles.add((low, high, slope, z0 - slope * y0))

    levels = {y for low, high, _, _ in profiles for y in (low, high)}
    for (lo_a, hi_a, slope_a, offset_a), (lo_b, hi_b, slope_b, offset_b) in combinations(sorted(profiles), 2):
        if abs(slope_a - slope_b) > 1e-10:
            y = (offset_b - offset_a) / (slope_a - slope_b)
            if max(lo_a, lo_b) < y < min(hi_a, hi_b):
                levels.add(y)

    def depth(line, y):
        return line[2] * y + line[3]

    # Seal to the visible brick outline on the shared cut plane. The end
    # faces stay inside the relief when another repeat touches this one.
    levels = sorted(levels)
    for y0, y1 in zip(levels, levels[1:]):
        if y1 - y0 < 1e-7:
            continue
        middle = (y0 + y1) / 2
        active = [line for line in profiles if line[0] <= middle <= line[1]]
        near = min(active, key=lambda line: depth(line, middle))
        far = max(active, key=lambda line: depth(line, middle))
        strips = (
            [(y0, depth(near, y0)), (y0, front), (y1, front), (y1, depth(near, y1))],
            [(y0, rear), (y0, depth(far, y0)), (y1, depth(far, y1)), (y1, rear)],
        )
        for strip in strips:
            wall.add([(-half_length, y, z, *WALL_BODY_UV) for y, z in strip])
            wall.add([(half_length, y, z, *WALL_BODY_UV) for y, z in reversed(strip)])


def build(source):
    vertices, uvs, groups = read_obj(source)
    samples = [g for g in groups if g.name.startswith("Mesheswalls2smenvwallquarter")]
    if len(samples) != 1:
        raise ValueError("Use the supplied Trackmain.obj export with one sample wall")

    half_length = OUTER_BRICK_SPACING / 2
    wall = MeshBatch("StandaloneTrackWall", WALL_COLOR, to_blender=world_to_blender)
    add_bricks(wall, samples[0], vertices, uvs, -half_length, half_length, sides=(1,), point=wall_point)
    finish_brick_cuts(wall, half_length)
    finish_wall(wall, 1, -half_length, half_length, point=wall_point, finish_cuts=False)
    wall.flush()
    if len(wall.objects) != 1:
        raise RuntimeError("The wall must export as a single mesh")


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
        raise RuntimeError("Blender did not export the wall segment")


if __name__ == "__main__":
    main()
