"""Add the curve's double-sided wall style to the original Trackmain.obj."""
import argparse
from collections import Counter
import math
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_track_bend import CENTER_Z, FLOOR_Y, MeshBatch, clip, palette_material, read_obj, source_corners
from build_standalone_curve import (
    BASE_BOTTOM,
    CAP_PROFILE,
    HALF_WIDTH,
    OUTER_BRICK_SPACING,
    REAR_BRICK_LAP,
    WALL_DEPTH,
    WALL_FACE_INSET,
    rectangle,
    sweep,
)


PAVING = {
    "Meshesfloorssmenvtiles051Mtl": ("StraightPavingSlate", (88, 92, 108)),
    "Meshesfloorssmenvtiles081Mtl": ("StraightPavingDark", (52, 54, 66)),
}
WALL_COLOR = (163, 162, 165)
WALL_HEIGHT = 3.95
WALL_REAR_EDGE = WALL_DEPTH + WALL_FACE_INSET + REAR_BRICK_LAP
WALL_BODY_UV = (.199469, .275827)


def world_to_blender(x, y, z):
    return x, -z, y


def straight_point(x, lateral, height):
    return x, FLOOR_Y + height, CENTER_Z + lateral


def source_bounds(group, vertices):
    cloud = [vertices[i] for i in {i for face in group.faces for i, _ in face}]
    return tuple(map(min, zip(*cloud))), tuple(map(max, zip(*cloud)))


def import_paving(source, sample_wall):
    result = bpy.ops.wm.obj_import(filepath=str(source), forward_axis="NEGATIVE_Z", up_axis="Y",
                                   use_split_groups=True, validate_meshes=False)
    if result != {"FINISHED"}:
        raise RuntimeError("Blender did not import Trackmain.obj")
    materials = {key: (prefix, palette_material(prefix, rgb)) for key, (prefix, rgb) in PAVING.items()}
    for obj in list(bpy.context.scene.objects):
        if obj.name == sample_wall:
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        prefix, material = materials[obj.data.materials[0].name]
        obj.name = f"{prefix}_{obj.name}"
        obj.data.name = obj.name
        # The OBJ references an external MTL. Assign the matched source
        # tints while keeping each imported group, UV and corner normal.
        obj.data.materials[0] = material


def add_bricks(batch, wall_group, vertices, uvs, start, end, *, sides=(-1, 1), point=straight_point):
    lo, hi = source_bounds(wall_group, vertices)
    panel_count = math.ceil((end - start) / OUTER_BRICK_SPACING)
    pitch = (end - start) / panel_count
    scale = pitch / OUTER_BRICK_SPACING
    depth_scale = WALL_DEPTH / (hi[2] - lo[2])
    relief_depth = WALL_FACE_INSET + 2 * REAR_BRICK_LAP
    front = []
    back = []
    for face in wall_group.faces:
        tile = [(scale * (x - lo[0]), y - hi[1] + WALL_HEIGHT, (hi[2] - z) * depth_scale, u, v)
                for x, y, z, u, v in source_corners(face, vertices, uvs)]
        front.append(tile)
        back.append(clip(tile, 2, relief_depth, False))
    for index in range(panel_count + 1):
        # Start and finish halfway through a panel, so its staggered
        # bricks already cover the wall right up to the two open ends.
        panel_start = start + (index - .5) * pitch
        for rear, tiles in ((False, front), (True, back)):
            for tile in tiles:
                corners = [(x + panel_start, y, depth, u, v) for x, y, depth, u, v in tile]
                corners = clip(clip(corners, 0, start, True), 0, end, False)
                for side in sides:
                    placed = [
                        (*point(x, side * (HALF_WIDTH + (WALL_REAR_EDGE - depth if rear else depth)), y), u, v)
                        for x, y, depth, u, v in corners
                    ]
                    batch.add(placed[::-1] if (side > 0) != rear else placed)


def finish_wall(batch, side, start, end, *, point=straight_point, finish_cuts=True):
    cap_bottom = CAP_PROFILE[0][1]
    sweep(batch, rectangle(WALL_FACE_INSET, WALL_DEPTH, BASE_BOTTOM, cap_bottom),
          [start, end], WALL_BODY_UV, side, point=point)
    sweep(batch, CAP_PROFILE, [start, end], (.199705, .301077), side, point=point)
    if not finish_cuts:
        return
    # Finish only the exposed thickness of the wall at each cut.
    for x, outgoing in ((start, False), (end, True)):
        for a, b in ((0, WALL_FACE_INSET), (WALL_DEPTH, WALL_REAR_EDGE)):
            cut = [(*point(x, side * (HALF_WIDTH + depth), height), *WALL_BODY_UV)
                   for depth, height in rectangle(a, b, BASE_BOTTOM, cap_bottom)]
            batch.add(cut[::-1] if (side < 0) != outgoing else cut)


def add_walls(wall_group, vertices, uvs, start, end):
    wall = MeshBatch("StraightWallNeutral", WALL_COLOR, to_blender=world_to_blender)
    add_bricks(wall, wall_group, vertices, uvs, start, end)
    for side in (-1, 1):
        finish_wall(wall, side, start, end)
    wall.flush()

    collider = MeshBatch("StraightWallCollider", WALL_COLOR, to_blender=world_to_blender)
    material = collider.material
    material.diffuse_color = (*material.diffuse_color[:3], 0)
    material.surface_render_method = "BLENDED"
    material.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0
    for side in (-1, 1):
        sweep(collider, rectangle(0, WALL_DEPTH, BASE_BOTTOM, WALL_HEIGHT),
              [start, end], WALL_BODY_UV, side, point=straight_point)
        collider.flush()


def build(source):
    vertices, uvs, groups = read_obj(source)
    paving = [group for group in groups if group.material in PAVING]
    walls = [group for group in groups if group.name.startswith("Mesheswalls2smenvwallquarter")]
    if (Counter(group.material for group in paving) != dict(zip(PAVING, (79, 55)))
            or len(walls) != 1 or len(groups) != len(paving) + 1):
        raise ValueError("Use the supplied Trackmain.obj export with 134 paving groups and one sample wall")
    bounds = [source_bounds(group, vertices) for group in paving]
    start = min(lo[0] for lo, _ in bounds)
    end = max(hi[0] for _, hi in bounds)
    import_paving(source, walls[0].name)
    add_walls(walls[0], vertices, uvs, start, end)


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
        raise RuntimeError("Blender did not export the straight track")


if __name__ == "__main__":
    main()
