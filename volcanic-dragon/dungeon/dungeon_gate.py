"""Model the torn iron portcullis for the volcanic dragon's cave."""

import math
import random

import bpy
from mathutils import Vector


ARCH = (
    (0.00, 7.55),
    (2.34, 7.18),
    (3.65, 6.65),
    (4.70, 5.70),
    (5.08, 4.66),
)
BAR_DEPTH = -0.32
VIEW = Vector((0, -1, 0))
PROFILE = (
    (-0.72, -1), (0.72, -1), (1, -0.69), (1, 0.69),
    (0.72, 1), (-0.72, 1), (-1, 0.69), (-1, -0.69),
)


def _arch_top(x):
    x = abs(x)
    for (inner_x, inner_z), (outer_x, outer_z) in zip(ARCH, ARCH[1:]):
        if x <= outer_x:
            t = (x - inner_x) / (outer_x - inner_x)
            return inner_z + (outer_z - inner_z) * t
    return ARCH[-1][1]


def _object(name, vertices, faces, materials, uvs, fracture_start=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for material in materials:
        mesh.materials.append(material)
    uv_layer = mesh.uv_layers.new(name="Gate UV")
    for face in mesh.polygons:
        if fracture_start is not None and face.index >= fracture_start:
            face.material_index = 1
        for loop, uv in zip(face.loop_indices, uvs[face.index]):
            uv_layer.data[loop].uv = uv
    result = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(result)
    return result


def _iron_bar(name, sections, iron, exposed=None, seed=0):
    """Sweep chamfered forged stock along a path of varying thickness.

    Each section is (x, y, z, width, depth, twist). A fracture, if present,
    goes at the final section and slopes irregularly across the torn metal.
    """
    rng = random.Random(seed)
    vertices, faces, uvs = [], [], []
    positions = [Vector(section[:3]) for section in sections]
    perimeter = len(PROFILE)
    distance = 0.0
    stations = []
    for i, (center, (_, _, _, width, depth, twist)) in enumerate(zip(positions, sections)):
        axis = (positions[min(i + 1, len(positions) - 1)] - positions[max(i - 1, 0)]).normalized()
        across = axis.cross(VIEW).normalized()
        thickness = axis.cross(across)
        cs, sn = math.cos(twist), math.sin(twist)
        across, thickness = cs * across + sn * thickness, cs * thickness - sn * across
        torn = exposed is not None and i == len(positions) - 1
        for sx, sy in PROFILE:
            edge = center + across * (sx * width / 2) + thickness * (sy * depth / 2)
            if torn:
                edge += axis * rng.uniform(-0.053, 0.076)
            vertices.append(edge)
        if i:
            distance += (center - positions[i - 1]).length
        stations.append(distance)

    for i in range(len(positions) - 1):
        for a in range(perimeter):
            b = (a + 1) % perimeter
            faces.append((i * perimeter + a, i * perimeter + b,
                          (i + 1) * perimeter + b, (i + 1) * perimeter + a))
            u0, u1 = a / perimeter, (a + 1) / perimeter
            v0, v1 = stations[i], stations[i + 1]
            uvs.append(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))

    cap_uv = tuple((0.5 + x * 0.5, 0.5 + y * 0.5) for x, y in PROFILE)
    faces.append(tuple(reversed(range(perimeter))))
    uvs.append(tuple(reversed(cap_uv)))
    end = len(vertices) - perimeter
    if exposed is None:
        faces.append(tuple(range(end, end + perimeter)))
        uvs.append(cap_uv)
        return _object(name, vertices, faces, (iron,), uvs)

    fracture_start = len(faces)
    tooth = len(vertices)
    vertices.append(positions[-1] + axis * rng.uniform(-0.034, 0.081) + across * sections[-1][3] * 0.13)
    for a in range(perimeter):
        b = (a + 1) % perimeter
        faces.append((end + a, end + b, tooth))
        uvs.append((cap_uv[a], cap_uv[b], (0.63, 0.5)))
    return _object(name, vertices, faces, (iron, exposed), uvs, fracture_start)


def _rivet(name, x, y, z, radius, metal):
    """A low hammered head, projected out of the face of the wrought stock."""
    sides = 9
    vertices, faces, uvs = [], [], []
    for depth, size in ((0.018, 0.90), (0, 1), (-0.032, 0.70)):
        for i in range(sides):
            phase = i * math.tau / sides + 0.15
            spread = radius * size * (1 + 0.035 * math.sin(i * 5.1 + x))
            vertices.append((x + spread * math.cos(phase), y + depth, z + spread * math.sin(phase)))
    faces.append(tuple(reversed(range(sides))))
    for ring in range(2):
        for a in range(sides):
            b = (a + 1) % sides
            faces.append((ring * sides + a, ring * sides + b,
                          (ring + 1) * sides + b, (ring + 1) * sides + a))
    faces.append(tuple(range(2 * sides, 3 * sides)))
    for face in faces:
        uvs.append(tuple((0.5 + (vertices[i][0] - x) / (2 * radius),
                          0.5 + (vertices[i][2] - z) / (2 * radius)) for i in face))
    return _object(name, vertices, faces, (metal,), uvs)


def _frame(iron, rivet):
    # Embed the rear of the iron jamb into the stone face, while the bars
    # sit just ahead of it so the foreclaw tips pass behind the outer feet.
    profile = [(5.10, -0.06), (5.10, 2.10), (5.10, 4.66), *reversed(ARCH[:-1])]
    outline = [(-x, z) for x, z in profile] + list(reversed(profile[:-1]))
    pieces = [_iron_bar("Gate | recessed arch frame", [
        (x, -0.21, z, 0.27 if z <= 4.66 else 0.25, 0.27, 0) for x, z in outline
    ], iron)]
    for sign, side in ((-1, "left"), (1, "right")):
        for i, z in enumerate((0.58, 2.01, 3.46, 4.47), 1):
            x = sign * 5.045
            pieces.append(_iron_bar(f"Gate | {side} frame anchor {i}", [
                (x, -0.365, z - 0.16, 0.37, 0.085, 0),
                (x, -0.365, z + 0.16, 0.37, 0.085, 0),
            ], iron))
            pieces.append(_rivet(f"Gate | {side} stone pin {i}", x, -0.412, z, 0.077, rivet))
    return pieces


def _outer_lattice(iron, exposed, rivet):
    pieces = []
    for sign, side in ((-1, "left"), (1, "right")):
        for i, x in enumerate((3.49, 4.41), 1):
            width = 0.225 if i == 1 else 0.248
            top = _arch_top(x)
            pieces.append(_iron_bar(f"Gate | intact {side} bar {i}", [
                (sign * x, BAR_DEPTH, -0.065, 0.105, 0.127, 0),
                (sign * x, BAR_DEPTH, 0.115, width * 0.88, 0.20, 0.025 * sign),
                (sign * x, BAR_DEPTH, 1.66, width, 0.21, 0.02 * sign),
                (sign * (x + .014), BAR_DEPTH, 3.82, width, 0.20, -0.021 * sign),
                (sign * x, BAR_DEPTH + 0.02, top + 0.07, width * 0.96, 0.20, 0),
            ], iron))
        for i, z in enumerate((1.44, 3.93), 1):
            shift = 0.09 if i == 1 else -0.09
            edge = 3.04 + (0.13 if (sign == -1) == (i == 1) else 0)
            bend = 0.11 if i == 1 else 0.16
            pieces.append(_iron_bar(f"Gate | {side} cross rail {i}", [
                (sign * 5.12, -0.386, z, 0.235, 0.167, 0),
                (sign * 4.4, -0.386, z, 0.239, 0.167, 0.018 * sign),
                (sign * 3.49, -0.394, z + 0.015, 0.223, 0.17, -0.024 * sign),
                (sign * edge, -0.394 - bend, z + shift, 0.188, 0.159, -0.17 * sign),
            ], iron, exposed, seed=46 + i + 17 * sign))
            for j, x in enumerate((3.49, 4.4), 1):
                pieces.append(_rivet(
                    f"Gate | {side} lattice rivet {i}.{j}", sign * x,
                    -0.488, z + (0.013 if j == 1 else 0), 0.060, rivet,
                ))
    return pieces


def _torn_centers(iron, exposed, rivet):
    # Uneven terminal lengths and bends open a head-sized hole. The longest
    # two bars flare beyond the head instead of hanging in the sweep.
    breaks = (
        (-2.61, -3.13, 5.49, -0.66, 0.225),
        (-1.76, -2.05, 6.44, -0.67, 0.216),
        (-0.87, -1.02, 6.83, -0.46, 0.207),
        (0.00, 0.18, 6.58, -0.74, 0.231),
        (0.88, 1.17, 6.41, -0.57, 0.214),
        (1.75, 2.10, 6.61, -0.82, 0.223),
        (2.58, 3.03, 5.79, -0.53, 0.226),
    )
    pieces = []
    for i, (x, end_x, end_z, end_y, width) in enumerate(breaks, 1):
        span = _arch_top(x) - end_z
        top = _arch_top(x) + 0.055
        sign = -1 if x < 0 else 1
        shoulder_x = x + (end_x - x) * 0.74
        if abs(x) > 2.5:
            shoulder_x = sign * 3.06
        pieces.append(_iron_bar(f"Gate | bent upper fracture {i}", [
            (x, BAR_DEPTH, top, width, 0.21, 0),
            (x, BAR_DEPTH, top - span * .16, width * 1.016, 0.205, 0.018 * sign),
            (shoulder_x, (end_y + BAR_DEPTH) / 2, end_z + span * 0.47, width * 0.99, 0.198, 0.11 * sign),
            ((shoulder_x + end_x) / 2, end_y + 0.065, end_z + span * 0.19, width * 0.91, 0.166, 0.18 * sign),
            (end_x, end_y, end_z, width * 0.87, 0.155, 0.24 * sign),
        ], iron, exposed, seed=130 + i * 13))
        pieces.append(_rivet(f"Gate | hanger pin {i}", x, -0.38, top - 0.095, 0.066, rivet))

    remnants = (
        (-2.61, -2.67, 0.113, -0.41),
        (-1.76, -1.71, 0.032, -0.46),
        (-0.87, -0.91, 0.088, -0.43),
        (0.00, 0.066, 0.068, -0.51),
        (0.88, 0.91, 0.041, -0.42),
        (1.75, 1.80, 0.094, -0.45),
        (2.58, 2.65, 0.104, -0.42),
    )
    for i, (x, end_x, end_z, end_y) in enumerate(remnants, 1):
        pieces.append(_iron_bar(f"Gate | broken floor socket {i}", [
            (x, BAR_DEPTH, -0.135, 0.205, 0.197, 0),
            (x, BAR_DEPTH, -0.052, 0.211, 0.19, 0.03),
            (end_x, end_y, end_z, 0.144, 0.131, 0.14),
        ], iron, exposed, seed=380 + i * 19))
    return pieces


def _assemble(name, parts):
    """Combine the pieces without merging their surfaces or UV seams."""
    materials = tuple(dict.fromkeys(material for part in parts for material in part.data.materials))
    vertices, faces, uvs, slots = [], [], [], []
    for part in parts:
        mesh = part.data
        offset = len(vertices)
        vertices.extend(v.co.copy() for v in mesh.vertices)
        uv_layer = mesh.uv_layers.active.data
        for face in mesh.polygons:
            faces.append(tuple(offset + i for i in face.vertices))
            uvs.append(tuple(uv_layer[loop].uv.copy() for loop in face.loop_indices))
            slots.append(materials.index(mesh.materials[face.material_index]))
        bpy.data.objects.remove(part, do_unlink=True)
        bpy.data.meshes.remove(mesh)
    result = _object(name, vertices, faces, materials, uvs)
    result.data.polygons.foreach_set("material_index", slots)
    result.data.update()
    return result


def build_gate(iron, exposed, rivet):
    """Return textured-ready static meshes for the front of the cave."""
    return [
        _assemble("Gate | Arch frame", _frame(iron, rivet)),
        _assemble("Gate | Side lattice", _outer_lattice(iron, exposed, rivet)),
        _assemble("Gate | Torn bars", _torn_centers(iron, exposed, rivet)),
    ]
