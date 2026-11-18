"""Model the torn iron portcullis for the volcanic dragon's cave."""

import math
import random

import bpy
from mathutils import Vector


ARCH = (
    (0.00, 8.40),
    (1.85, 8.22),
    (3.02, 7.49),
    (4.32, 5.82),
    (4.93, 4.32),
    (5.11, 2.25),
    (5.14, 0.00),
)
ARCH_WIDTHS = tuple((z, x) for x, z in reversed(ARCH))
FRAME_DEPTH = -0.33
BAR_DEPTH = -0.47
VIEW = Vector((0, -1, 0))
PROFILE = (
    (-0.72, -1), (0.72, -1), (1, -0.69), (1, 0.69),
    (0.72, 1), (-0.72, 1), (-1, 0.69), (-1, -0.69),
)


def _interpolate(value, profile):
    for (a, start), (b, finish) in zip(profile, profile[1:]):
        if value <= b:
            return start + (finish - start) * ((value - a) / (b - a))
    return profile[-1][1]


def _iron_bar(sections, fracture_seed=None):
    """Sweep chamfered stock. A fractured final section gets a jagged tear.

    Sections specify (x, y, z, width, depth, twist).
    """
    rng = random.Random(fracture_seed)
    vertices, faces = [], []
    positions = [Vector(section[:3]) for section in sections]
    perimeter = len(PROFILE)
    for i, (center, (_, _, _, width, depth, twist)) in enumerate(zip(positions, sections)):
        axis = (positions[min(i + 1, len(positions) - 1)] - positions[max(i - 1, 0)]).normalized()
        across = axis.cross(VIEW).normalized()
        thickness = axis.cross(across)
        cs, sn = math.cos(twist), math.sin(twist)
        across, thickness = cs * across + sn * thickness, cs * thickness - sn * across
        torn = fracture_seed is not None and i == len(positions) - 1
        for sx, sy in PROFILE:
            edge = center + across * (sx * width / 2) + thickness * (sy * depth / 2)
            if torn:
                edge += axis * rng.uniform(-0.053, 0.076)
            vertices.append(edge)

    for i in range(len(positions) - 1):
        for a in range(perimeter):
            b = (a + 1) % perimeter
            faces.append((i * perimeter + a, i * perimeter + b,
                          (i + 1) * perimeter + b, (i + 1) * perimeter + a))

    faces.append(tuple(reversed(range(perimeter))))
    end = len(vertices) - perimeter
    if fracture_seed is None:
        faces.append(tuple(range(end, end + perimeter)))
        return vertices, faces

    tooth = len(vertices)
    vertices.append(positions[-1] + axis * rng.uniform(-0.034, 0.081) + across * sections[-1][3] * 0.13)
    for a in range(perimeter):
        b = (a + 1) % perimeter
        faces.append((end + a, end + b, tooth))
    return vertices, faces


def _rivet(x, y, z, radius):
    """A low hammered head, projected out of the face of the wrought stock."""
    sides = 9
    vertices, faces = [], []
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
    return vertices, faces


def _frame():
    left = [(-x, z) for x, z in reversed(ARCH)]
    outline = left + list(ARCH[1:])
    pieces = [_iron_bar([
        (x, FRAME_DEPTH, z, 0.27 if z <= 4.32 else 0.25, 0.27, 0)
        for x, z in outline
    ])]
    for sign in (-1, 1):
        for z in (0.58, 2.01, 3.46, 4.37):
            x = sign * (_interpolate(z, ARCH_WIDTHS) - 0.02)
            pieces.append(_iron_bar([
                (x, FRAME_DEPTH - 0.138, z - 0.16, 0.37, 0.085, 0),
                (x, FRAME_DEPTH - 0.138, z + 0.16, 0.37, 0.085, 0),
            ]))
            pieces.append(_rivet(x, FRAME_DEPTH - 0.185, z, 0.077))
    return pieces


def _outer_lattice():
    pieces = []
    # Each side bar keeps its upper support. Its snapped lower end twists
    # outward and toward the front, above the claw's swept envelope.
    lower_breaks = {
        -1: ((1.07, 0.35, 0.31), (1.31, 0.26, 0.22)),
        1: ((1.46, 0.34, 0.25), (1.13, 0.38, 0.37)),
    }
    for sign, cuts in lower_breaks.items():
        for i, (x, (end_z, bend, pull)) in enumerate(zip((3.49, 4.41), cuts), 1):
            width = 0.225 if i == 1 else 0.248
            top = _interpolate(x, ARCH) + 0.07
            pieces.append(_iron_bar([
                (sign * x, FRAME_DEPTH - 0.02, top, width * 0.96, 0.20, 0),
                (sign * (x + 0.014), BAR_DEPTH, 3.82, width, 0.20, -0.021 * sign),
                (sign * x, BAR_DEPTH, 2.02, width, 0.21, 0.02 * sign),
                (sign * (x + bend * 0.38), BAR_DEPTH - pull * 0.47, end_z + 0.31,
                 width * 0.94, 0.198, 0.16 * sign),
                (sign * (x + bend), BAR_DEPTH - pull, end_z,
                 width * 0.85, 0.165, 0.31 * sign),
            ], fracture_seed=218 + i + 17 * sign))

        # Both horizontal ties sit above the paws. Their inner ends retain
        # the torn edge of the larger opening.
        for i, z in enumerate((2.17, 3.93), 1):
            shift = 0.09 if i == 1 else -0.09
            edge = 3.04 + (0.13 if (sign == -1) == (i == 1) else 0)
            bend = 0.11 if i == 1 else 0.16
            y = BAR_DEPTH - 0.075
            outer = _interpolate(z, ARCH_WIDTHS) + 0.04
            pieces.append(_iron_bar([
                (sign * outer, FRAME_DEPTH - 0.11, z, 0.235, 0.167, 0),
                (sign * 4.4, y, z, 0.239, 0.167, 0.018 * sign),
                (sign * 3.49, y, z + 0.015, 0.223, 0.17, -0.024 * sign),
                (sign * edge, y - bend, z + shift, 0.188, 0.159, -0.17 * sign),
            ], fracture_seed=46 + i + 17 * sign))
            for j, x in enumerate((3.49, 4.4), 1):
                pieces.append(_rivet(sign * x, y - 0.094, z + (0.013 if j == 1 else 0), 0.060))
    return pieces


def _torn_centers():
    # Long, uneven hangers frame the central breach. Two hangers flare away
    # from the head and dip below the others beyond the sweep.
    breaks = (
        (-2.61, -3.15, 5.49, -0.79, 0.225),
        (-1.76, -2.04, 6.33, -0.74, 0.216),
        (-0.87, -1.02, 6.42, -0.62, 0.207),
        (0.00, 0.18, 6.28, -0.87, 0.231),
        (0.88, 1.14, 6.39, -0.69, 0.214),
        (1.75, 2.08, 6.34, -0.92, 0.223),
        (2.58, 3.13, 5.76, -0.68, 0.226),
    )
    pieces = []
    for i, (x, end_x, end_z, end_y, width) in enumerate(breaks, 1):
        top = _interpolate(abs(x), ARCH) + 0.055
        span = top - end_z
        sign = -1 if x < 0 else 1
        shoulder_x = x + (end_x - x) * 0.74
        if abs(x) > 2.5:
            shoulder_x = sign * 3.09
        pieces.append(_iron_bar([
            (x, FRAME_DEPTH - 0.02, top, width, 0.21, 0),
            (x, BAR_DEPTH, top - span * 0.16, width * 1.016, 0.205, 0.018 * sign),
            (shoulder_x, (end_y + BAR_DEPTH) / 2, end_z + span * 0.47, width * 0.99, 0.198, 0.11 * sign),
            ((shoulder_x + end_x) / 2, end_y + 0.065, end_z + span * 0.19, width * 0.91, 0.166, 0.18 * sign),
            (end_x, end_y, end_z, width * 0.87, 0.155, 0.24 * sign),
        ], fracture_seed=130 + i * 13))
        pieces.append(_rivet(x, BAR_DEPTH - 0.024, top - 0.095, 0.066))

    remnants = (
        (-1.76, -1.71, 0.032, -0.61),
        (-0.87, -0.91, 0.088, -0.58),
        (0.00, 0.066, 0.068, -0.66),
        (0.88, 0.91, 0.041, -0.57),
        (1.75, 1.80, 0.094, -0.60),
    )
    for i, (x, end_x, end_z, end_y) in enumerate(remnants, 1):
        pieces.append(_iron_bar([
            (x, BAR_DEPTH, -0.135, 0.205, 0.197, 0),
            (x, BAR_DEPTH, -0.052, 0.211, 0.19, 0.03),
            (end_x, end_y, end_z, 0.144, 0.131, 0.14),
        ], fracture_seed=399 + i * 19))
    return pieces


def _assemble(name, parts, iron):
    vertices, faces = [], []
    for points, polygons in parts:
        offset = len(vertices)
        vertices.extend(points)
        faces.extend(tuple(offset + index for index in face) for face in polygons)

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(iron)
    mesh.update()
    result = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(result)
    return result


def build_gate(iron):
    """Return the three solid mesh groups of the damaged gate."""
    return [
        _assemble("Gate | Arch frame", _frame(), iron),
        _assemble("Gate | Side lattice", _outer_lattice(), iron),
        _assemble("Gate | Torn bars", _torn_centers(), iron),
    ]
