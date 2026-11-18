"""Build the plain gray dragon cave and export a self-contained GLB.

Run from this directory with Blender:
    blender -b --python-exit-code 1 --python build_dungeon_cave.py
"""

import argparse
import math
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from dungeon_gate import ARCH, build_gate


# Blender space. The entrance faces -Y and the track floor is at Z=0.
# The reference has tall, nearly vertical jambs with angled upper shoulders.
FACADE_HALF = [
    (7.30, -.37), (7.37, 2.16), (7.29, 4.55),
    (7.09, 6.94), (5.90, 8.92), (3.46, 10.08), (0, 10.18),
]
INNER_RINGS = [
    (-.12, 1, 1, 0), (.82, 1.013, .965, 0), (2.22, .996, .875, .03),
    (3.66, .922, .778, -.02), (4.96, .826, .678, .05),
    (6.24, .711, .579, .02), (7.24, .590, .489, -.015),
    (7.93, .453, .432, -.02), (8.34, .306, .354, .01),
    (8.62, .149, .224, 0), (8.76, .066, .089, 0),
]
OUTER_RINGS = [
    (-.49, 1, 1, 0), (.63, .988, .992, -.08), (2.08, .976, .931, .08),
    (3.63, .920, .858, .12), (5.04, .839, .772, .13),
    (6.40, .735, .675, .06), (7.49, .607, .574, -.015),
    (8.21, .456, .472, -.08), (8.69, .314, .378, -.09),
    (8.98, .181, .255, -.045), (9.13, .062, .122, 0),
]


def material(name, gray, roughness, metallic=0):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = (gray, gray, gray, 1)
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = result.diffuse_color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return result


def outline(half):
    return [(-x, z) for x, z in half[:-1]] + half[-1:] + list(reversed(half[:-1]))


def build_cave(stone):
    inner_outline = outline(list(reversed(ARCH)))
    outer_outline = outline(FACADE_HALF)
    assert len(inner_outline) == len(outer_outline), "The facade must match the arch's profile stations"
    points, faces = [], []
    smooth_faces = set()
    last = len(inner_outline) - 1

    def vertex(point):
        points.append(point)
        return len(points) - 1

    def face(indices, smooth=False):
        if smooth:
            smooth_faces.add(len(faces))
        faces.append(indices)

    def profile(y, width, rise, center, exterior, row):
        contour = outer_outline if exterior else inner_outline
        bottom = -.37 if exterior else -.075
        ring = []
        for i, (x, z) in enumerate(contour):
            if exterior and row:
                # Leave the reference-style facade planar. The low ridges
                # behind it soften into the rounded back of the cave.
                wave = math.sin(row * 1.86 + i * 1.34)
                arch = math.sin(math.pi * i / last)
                drift = (.055 * wave, .092 * wave * width, .137 * wave * arch * rise)
            else:
                drift = (0, 0, 0)
            height = bottom + (z - contour[0][1]) * rise + drift[2]
            ring.append(vertex((x * width + center + drift[1], y + drift[0], height)))
        return ring

    outer = [profile(*spec, True, i) for i, spec in enumerate(OUTER_RINGS)]
    inner = [profile(*spec, False, i) for i, spec in enumerate(INNER_RINGS)]

    # A flat front with broad, sharply angled bevel faces around the opening.
    # The bevel reaches in toward the iron frame and inner throat.
    bevel = []
    for outside, inside in zip(outer[0], inner[0]):
        wall_x, wall_y, wall_z = points[outside]
        lip_x, _, lip_z = points[inside]
        bevel.append(vertex((lip_x + (wall_x - lip_x) * .295, wall_y, lip_z + (wall_z - lip_z) * .295)))
    for outside, inside in ((outer[0], bevel), (bevel, inner[0])):
        for i in range(last):
            face((outside[i], inside[i], inside[i + 1], outside[i + 1]))

    def skin(rings, exterior):
        for row, (a, b) in enumerate(zip(rings, rings[1:])):
            for i in range(last):
                indices = (a[i], a[i + 1], b[i + 1], b[i])
                # Keep the opening faceted while smoothing the outside roof
                # and rear across their gently curved, non-planar spans.
                halves = ((0, 1, 2), (0, 2, 3)) if (row + i) % 2 else ((0, 1, 3), (1, 2, 3))
                for keys in halves:
                    order = keys if exterior else keys[::-1]
                    face(tuple(indices[k] for k in order), smooth=exterior)
            floor_edge = (a[0], a[-1], b[-1], b[0])
            face(floor_edge[::-1] if exterior else floor_edge)

        end = rings[-1]
        xmid = (points[end[0]][0] + points[end[-1]][0]) * .5
        base = points[end[0]][2]
        rear = vertex((xmid, 9.28 if exterior else 8.84, base + .025))
        for i in range(last):
            indices = (end[i], end[i + 1], rear)
            face(indices if exterior else indices[::-1], smooth=exterior)
        floor_face = (end[0], end[-1], rear)
        face(floor_face[::-1] if exterior else floor_face)

    skin(outer, True)
    skin(inner, False)
    for outside, inside in ((outer[0], bevel), (bevel, inner[0])):
        face((outside[0], outside[-1], inside[-1], inside[0]))

    mesh = bpy.data.meshes.new("Plain gray cavern shell")
    mesh.from_pydata(points, [], faces)
    if mesh.validate(verbose=True):
        raise RuntimeError("The cave shell required a topology repair")
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = polygon.index in smooth_faces
    mesh.materials.append(stone)
    cave = bpy.data.objects.new("Dungeon Cave - Gray Shell", mesh)
    bpy.context.collection.objects.link(cave)
    return cave


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--output", type=Path, default=HERE / "DragonDungeonCave.glb")
    options = args.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    options.output.parent.mkdir(parents=True, exist_ok=True)

    cave = build_cave(material("Plain matte gray cave", .19, .86))
    gate = build_gate(material("Plain dark gray iron", .047, .68, .21))
    assert gate, "Expected gate meshes"
    print(f"Exporting plain-gray cave and {len(gate)} gate meshes ({len(cave.data.polygons)} shell faces).")
    result = bpy.ops.export_scene.gltf(filepath=str(options.output), export_format="GLB", export_yup=True,
                                      export_animations=False, export_materials="EXPORT",
                                      export_texcoords=False)
    if result != {"FINISHED"}:
        raise RuntimeError("Dungeon cave GLB export failed")


if __name__ == "__main__":
    main()
