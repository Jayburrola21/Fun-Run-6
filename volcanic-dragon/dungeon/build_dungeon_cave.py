"""Build the textured dragon cave and export it with embedded textures.

Run with Blender: blender -b --python-exit-code 1 --python build_dungeon_cave.py
"""

import argparse
import math
from pathlib import Path
import struct
import sys
import tempfile
import zlib

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from dungeon_gate import build_gate


# Blender space. The entrance faces -Y and the floor is at Z=0.
APERTURE = [
    (5.08, 0), (5.08, 4.66), (4.70, 5.70),
    (3.65, 6.65), (2.34, 7.18), (0, 7.55),
]
# More vertices run along the vertical jambs so they can follow the uneven rock.
INNER_HALF = [(5.08, 0), (5.08, 1.42), (5.08, 3.09), *APERTURE[1:]]
OUTER_HALF = [
    (6.66, -.40), (6.95, 1.04), (6.76, 2.83), (6.53, 4.79),
    (5.95, 6.21), (4.58, 7.58), (2.89, 8.38), (0, 8.77),
]
# Six lobes over the body, then an oval taper wrapping down into the rear floor.
INNER_RINGS = [
    (-.40, 1, 1, 0), (.57, 1.018, .993, 0), (2.08, 1.01, .932, .035),
    (3.67, .979, .859, -.025), (5.14, .906, .763, .06),
    (6.63, .799, .659, .02), (7.80, .690, .560, -.025),
    (8.56, .539, .502, -.015), (8.99, .379, .452, .015),
    (9.28, .187, .267, 0), (9.43, .075, .107, 0),
]
OUTER_RINGS = [
    (-.16, 1, 1, 0), (.79, .994, 1.024, -.12), (2.18, .981, .982, .12),
    (3.87, .931, .914, .19), (5.38, .844, .811, .21),
    (6.91, .747, .709, .12), (8.07, .620, .626, .02),
    (8.91, .467, .531, -.09), (9.43, .327, .424, -.11),
    (9.72, .195, .288, -.04), (9.88, .068, .134, 0),
]
TILE_WIDTH = 7.4
TILE_HEIGHT = 4.8


def noise(rng, coords, cells):
    """Periodic value noise with smooth interpolation between grid samples."""
    x, y = (coords * cells).astype(np.float32)
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    table = rng.random((cells, cells), dtype=np.float32) - .5
    lo = table[iy % cells, ix % cells] * (1 - fx) + table[iy % cells, (ix + 1) % cells] * fx
    hi = table[(iy + 1) % cells, ix % cells] * (1 - fx) + table[(iy + 1) % cells, (ix + 1) % cells] * fx
    return lo * (1 - fy) + hi * fy


def smooth(value):
    t = np.clip(value, 0, 1)
    return t * t * (3 - 2 * t)


def masonry_pixels(size=1536):
    rng = np.random.default_rng(26319)
    coords = np.stack(np.meshgrid((np.arange(size) + .5) / size, (np.arange(size) + .5) / size))
    u, v = coords
    broad, chisel, grit, grain = [noise(rng, coords, rate) for rate in (8, 28, 89, 242)]
    joint_x = (u + broad * .017 + chisel * .011 + grit * .004) % 1
    joint_y = (v + broad * .023 + chisel * .012 + grit * .004) % 1
    row_edges = np.array([0, .151, .323, .473, .675, .828, 1])
    distance_x = np.zeros_like(u)
    distance_y = np.zeros_like(v)
    shade = np.zeros_like(u)
    row_wear = np.zeros_like(u)
    for row, (lo, hi) in enumerate(zip(row_edges[:-1], row_edges[1:])):
        in_row = (joint_y >= lo) & (joint_y < hi)
        widths = rng.uniform(.71, 1.37, 5 if row % 3 != 2 else 6)
        edges = np.insert(np.cumsum(widths), 0, 0) / widths.sum()
        position = (joint_x[in_row] + row * .341 + .093 * (row % 2)) % 1
        brick = np.searchsorted(edges[1:], position, side="right")
        distance_x[in_row] = TILE_WIDTH * np.minimum(position - edges[brick], edges[brick + 1] - position)
        distance_y[in_row] = TILE_HEIGHT * np.minimum(joint_y[in_row] - lo, hi - joint_y[in_row])
        shade[in_row] = rng.uniform(-.055, .061, len(widths))[brick]
        row_wear[in_row] = rng.uniform(.8, 1.16, len(widths))[brick]

    rounding = .092 * row_wear
    corner = np.hypot(np.maximum(rounding - distance_x, 0), np.maximum(rounding - distance_y, 0))
    side = np.minimum(distance_x, distance_y) - .22 * corner
    chips = np.maximum(0, -grit - .15) * .028
    bevel = smooth((side - .019 - chips) / (.105 * row_wear))
    face = smooth((side - .018) / .024)
    fracture = np.maximum(0, -chisel - .13) * np.maximum(0, .33 - grit) * 2.6
    height = bevel * (.050 + broad * .021 + chisel * .014 + grit * .008 - fracture * .022)
    height += grain * .007 + grit * .004
    sx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * size / (2 * TILE_WIDTH)
    sy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * size / (2 * TILE_HEIGHT)
    normals = np.stack((-sx, sy, np.ones_like(sx)), axis=-1)
    normals /= np.linalg.norm(normals, axis=-1, keepdims=True)

    # Subtle chipped highlights are baked into the color so the mortar
    # remains readable in importers that only show the diffuse map.
    edge_light = np.clip(-.16 * sy - .08 * sx, -.065, .08)
    mottling = .153 * broad + .095 * chisel + .060 * grit + .038 * grain
    variation = shade + mottling - .066 * fracture + edge_light
    grit_color = .048 * grit + .055 * grain + broad * .034
    stone = np.array([.409, .417, .428]) + variation[..., None]
    mortar = np.array([.165, .164, .167]) + grit_color[..., None]
    color = mortar * (1 - face[..., None]) + stone * face[..., None]
    return color, .5 + .5 * normals


def iron_pixels(size=512):
    rng = np.random.default_rng(833)
    coords = np.stack(np.meshgrid((np.arange(size) + .5) / size, (np.arange(size) + .5) / size))
    broad, corrosion, grain = [noise(rng, coords, rate) for rate in (9, 37, 142)]
    patina = smooth((broad + .54 * corrosion - .075) / .27)[..., None]
    noise_color = (.093 * corrosion + .067 * grain)[..., None]
    charcoal = np.array([.249, .257, .265]) + noise_color
    rust = np.array([.335, .241, .189]) + noise_color * 1.4
    return charcoal + (rust - charcoal) * patina * .64


def png_texture(pixels, name, directory, normal=False):
    # Load a real PNG so glTF can carry the image directly without a
    # procedural Blender material or an external dependency.
    rgb = np.ascontiguousarray(np.rint(np.clip(pixels, 0, 1) * 255), dtype=np.uint8)
    height, width, _ = rgb.shape

    def chunk(name, data):
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))

    scanlines = b"".join(b"\0" + row.tobytes() for row in rgb)
    path = directory / (name + ".png")
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress(scanlines, level=6)) +
                     chunk(b"IEND", b""))
    image = bpy.data.images.load(str(path))
    image.name = name
    if normal:
        image.colorspace_settings.name = "Non-Color"
    image.pack()
    return image


def material(name, color, roughness, metallic=0, texture=None, normal=None):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = (*color, 1)
    nodes = result.node_tree.nodes
    link = result.node_tree.links.new
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if texture:
        color_map = nodes.new("ShaderNodeTexImage")
        color_map.image = texture
        link(color_map.outputs["Color"], shader.inputs["Base Color"])
    if normal:
        normal_map = nodes.new("ShaderNodeTexImage")
        normal_map.image = normal
        tangent = nodes.new("ShaderNodeNormalMap")
        link(normal_map.outputs["Color"], tangent.inputs["Color"])
        link(tangent.outputs["Normal"], shader.inputs["Normal"])
    return result


def outline(half):
    return [(-x, z) for x, z in half[:-1]] + half[-1:] + list(reversed(half[:-1]))


def atlas_coordinates(points):
    across = [0]
    for index in range(1, len(points)):
        across.append(across[-1] + math.dist(points[index], points[index - 1]))
    return across


def build_cave(stone):
    inner_outline = outline(INNER_HALF)
    outer_outline = outline(OUTER_HALF)
    points, faces, coords = [], [], []
    smooth_faces = set()
    last = len(inner_outline) - 1

    def vertex(point):
        points.append(point)
        return len(points) - 1

    def face(indices, uv, smooth_surface=False):
        if smooth_surface:
            smooth_faces.add(len(faces))
        faces.append(indices)
        coords.append(uv)

    def profile(y, width, rise, center, is_outer, ring_number):
        contour = outer_outline if is_outer else inner_outline
        ring = []
        for i, (x, z) in enumerate(contour):
            # Cap and doorway sections stay continuous. Broad, low facets
            # on the outer body make the ridge irregular as it rounds off.
            hump = math.sin(math.pi * i / last)
            wave = math.sin(ring_number * 2.17 + i * 1.39)
            flank = math.cos(ring_number * 1.91 + i * 2.13)
            if is_outer:
                y_offset = .117 * wave if ring_number > 0 else -.135 - .125 * hump + .076 * wave
                x_offset = .17 * flank * width
                z_offset = .18 * wave * hump * rise
                floor_z = -.40
            else:
                y_offset, x_offset, z_offset = 0, 0, 0
                floor_z = -.075
            floor_delta = floor_z - contour[0][1]
            if i == 0 or i == last:
                height = floor_z
            else:
                height = floor_z + (z + floor_delta - floor_z) * rise + z_offset
            ring.append(vertex((x * width + center + x_offset, y + y_offset, height)))
        return ring

    outer = [profile(*spec, True, i) for i, spec in enumerate(OUTER_RINGS)]
    inner = [profile(*spec, False, i) for i, spec in enumerate(INNER_RINGS)]
    # The lip turns inward from the heavier facade into the threshold.
    bevel = []
    for i in range(last + 1):
        wall = points[outer[0][i]]
        lip = points[inner[0][i]]
        fraction = .28 + .044 * math.cos(i * 1.71)
        bevel.append(vertex((lip[0] + (wall[0] - lip[0]) * fraction,
                             lip[1] - .06 - .16 * math.sin(math.pi * i / last),
                             lip[2] + (wall[2] - lip[2]) * fraction)))

    def wall_uv(indices):
        return [(points[i][0] / TILE_WIDTH, points[i][2] / TILE_HEIGHT) for i in indices]

    def floor_uv(indices):
        return [(points[i][0] / TILE_WIDTH, points[i][1] / TILE_HEIGHT) for i in indices]

    for outside, inside in ((outer[0], bevel), (bevel, inner[0])):
        for i in range(last):
            indices = (outside[i], inside[i], inside[i + 1], outside[i + 1])
            face(indices, wall_uv(indices))

    # Use longitudinal distance and cross-section arc length to tile stone
    # continuously over the sides, ceiling, and rounded rear.
    def skins(rings, exterior):
        # Measure along the actual 3D contours. Depth alone would squeeze
        # the mortar joints into stretched streaks where the cap drops.
        longitudinal = [0] * (last + 1)
        ring_uvs = []
        for row, ring in enumerate(rings):
            arc = atlas_coordinates([points[index] for index in ring])
            middle = arc[last // 2]
            if row:
                for i, (a, b) in enumerate(zip(rings[row - 1], ring)):
                    longitudinal[i] += math.dist(points[a], points[b])
            ring_uvs.append([(distance / TILE_WIDTH, (v - middle) / TILE_HEIGHT)
                             for distance, v in zip(longitudinal, arc)])

        for row, (a, b) in enumerate(zip(rings, rings[1:])):
            current, following = ring_uvs[row], ring_uvs[row + 1]
            for i in range(last):
                indices = (a[i], a[i + 1], b[i + 1], b[i])
                uv = (current[i], current[i + 1], following[i + 1], following[i])
                # Split non-planar spans explicitly so the export's
                # faceted outline matches the Blender preview.
                sets = ((0, 1, 2), (0, 2, 3)) if (row + i) % 2 else ((0, 1, 3), (1, 2, 3))
                for keys in sets:
                    order = keys if exterior else keys[::-1]
                    face(tuple(indices[k] for k in order), [uv[k] for k in order], exterior)
            floor_edge = (a[0], a[-1], b[-1], b[0])
            if exterior:
                floor_edge = floor_edge[::-1]
            face(floor_edge, floor_uv(floor_edge))

        end = rings[-1]
        xmid = (points[end[0]][0] + points[end[-1]][0]) * .5
        floor = points[end[0]][2]
        rear = vertex((xmid, 10.04 if exterior else 9.49, floor + .025))
        end_uv = ring_uvs[-1]
        apex_u = sum(uv[0] + math.dist(points[index], points[rear]) / TILE_WIDTH
                     for uv, index in zip(end_uv, end)) / len(end)
        for i in range(last):
            indices = (end[i], end[i + 1], rear)
            mapping = (end_uv[i], end_uv[i + 1], (apex_u, 0))
            if not exterior:
                indices = indices[::-1]
                mapping = mapping[::-1]
            face(indices, mapping, exterior)
        floor_face = (end[0], end[-1], rear)
        if exterior:
            floor_face = floor_face[::-1]
        face(floor_face, floor_uv(floor_face))

    skins(outer, True)
    skins(inner, False)
    for left, right in ((outer[0], bevel), (bevel, inner[0])):
        sill = (left[0], left[-1], right[-1], right[0])
        face(sill, floor_uv(sill))

    mesh = bpy.data.meshes.new("Textured hollow stone shell")
    mesh.from_pydata(points, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    uv = mesh.uv_layers.new(name="Stone UV")
    for polygon, mapping in zip(mesh.polygons, coords, strict=True):
        polygon.use_smooth = polygon.index in smooth_faces
        for loop, value in zip(polygon.loop_indices, mapping, strict=True):
            uv.data[loop].uv = value
    mesh.materials.append(stone)
    cave = bpy.data.objects.new("Dungeon Cave - Masonry", mesh)
    bpy.context.collection.objects.link(cave)
    return cave


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--output", type=Path, default=HERE / "DragonDungeonCave.glb")
    options = args.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    options.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="dungeon-textures-") as directory:
        work = Path(directory)
        masonry, normal = masonry_pixels()
        stone = material("Weathered gray dungeon stone", (.16, .17, .18), .88,
                         texture=png_texture(masonry, "Dungeon Slate Albedo", work),
                         normal=png_texture(normal, "Dungeon Slate Normal", work, normal=True))
        iron = material("Forged iron with oxide", (.07, .073, .078), .68, .68,
                        texture=png_texture(iron_pixels(), "Gate Iron Albedo", work))
        exposed = material("Freshly fractured iron", (.27, .28, .28), .44, .71)
        hardware = material("Oxidized rivets and gate sockets", (.10, .075, .063), .75, .56)
        cave = build_cave(stone)
        gate = build_gate(iron, exposed, hardware)
        assert gate, "Expected gate meshes"
        print(f"Exporting textured cave and {len(gate)} gate objects ({len(cave.data.polygons)} shell faces).")
        result = bpy.ops.export_scene.gltf(filepath=str(options.output), export_format="GLB", export_yup=True,
                                          export_animations=False, export_materials="EXPORT")
    if result != {"FINISHED"}:
        raise RuntimeError("Dungeon cave GLB export failed")


if __name__ == "__main__":
    main()
