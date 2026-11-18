"""Bind the existing dragon to a Roblox neck, chest, and eyelid rig.

Open the optimized VolcanicDragon_Game.blend, or supply its static GLB:
    blender -b VolcanicDragon_Game.blend --python-exit-code 1 --python build_dragon_rig.py -- --output ./out
    blender -b --python-exit-code 1 --python build_dragon_rig.py -- --source ../VolcanicDragon.glb --output ./out
"""

import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.geometry import convex_hull_2d


RIG_NAME = "VolcanicDragonRig"
ROOT = "Dragon_Root"
NECK_STATIONS = (
    (.12, ROOT),
    (-.94, "NeckBase"),
    (-2.18, "NeckMid"),
    (-3.52, "NeckUpper"),
    (-4.51, "Head"),
)


def smoothstep(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def core_weights(point):
    """Feather longitudinal bends into the central neck; leave the limbs fixed."""
    active = 1.0 - smoothstep((abs(point.x) - 1.76) / .54)
    weights = {ROOT: 1.0 - active}
    for (start, nearer_back), (end, nearer_front) in zip(NECK_STATIONS, NECK_STATIONS[1:]):
        if point.y >= end:
            t = smoothstep((start - point.y) / (start - end))
            weights[nearer_back] = weights.get(nearer_back, 0.0) + active * (1.0 - t)
            weights[nearer_front] = active * t
            break
    else:
        weights["Head"] = active

    kept = {bone: strength for bone, strength in weights.items() if strength >= 0.0001}
    total = sum(kept.values())
    return {bone: strength / total for bone, strength in kept.items()}


def breathing_weights(point):
    weights = core_weights(point)
    # The chest gets only a share of rooted weights. Existing neck influences
    # and the feet's rigid root attachment stay the same.
    height = smoothstep((point.z - .38) / .95)
    width = 1.0 - smoothstep((abs(point.x) - 1.7) / 1.5)
    front = smoothstep((1.1 - point.y) / 1.8)
    rooted = weights.get(ROOT, 0.0)
    chest = rooted * height * width * front
    if chest > .0001:
        # Blender's GLB exporter drops weights at or below .0001. Keep the
        # full original share by shifting an otherwise pruned remnant.
        if rooted - chest <= .0001:
            del weights[ROOT]
            chest = rooted
        else:
            weights[ROOT] = rooted - chest
        weights["Chest"] = chest
    return weights


def outline_at(edges, x):
    heights = []
    for (x1, y1), (x2, y2) in edges:
        if min(x1, x2) <= x <= max(x1, x2):
            if x1 == x2:
                heights.extend((y1, y2))
            else:
                heights.append(y1 + (y2 - y1) * (x - x1) / (x2 - x1))
    return min(heights), max(heights)


def eye_columns(eye_vertices, horizontal, outward, depth):
    # Project the luminous eye opening onto the lid from a range of viewing
    # angles, since the curved iris can also show around a lid from the side.
    points = []
    for point in eye_vertices:
        horizontal_margin = (depth - point.dot(outward)) * .55
        vertical_margin = (depth - point.dot(outward)) * .33
        for dx in (-horizontal_margin, horizontal_margin):
            for dz in (-vertical_margin, vertical_margin):
                points.append(Vector((point.dot(horizontal) + dx, point.z + dz)))

    hull = [points[i] for i in convex_hull_2d(points)]
    edges = list(zip(hull, hull[1:] + hull[:1]))

    start = min(x for x, _ in points)
    end = max(x for x, _ in points)
    middle = (start + end) * .5
    columns = []
    for index in range(7):
        t = (1 - math.cos(math.pi * index / 6)) * .5
        x = start + (end - start) * t
        low, high = outline_at(edges, x if index < 6 else end)
        x += (x - middle) * .14
        if 0 < index < 6:
            low -= .023
            high += .023
        else:
            low = high = (low + high) * .5
        columns.append((x, low, high))

    outline = [
        ((a[0], a[height]), (b[0], b[height]))
        for a, b in zip(columns, columns[1:]) for height in (1, 2)
    ]
    for x, y in points:
        low, high = outline_at(outline, x)
        if not low <= y <= high:
            raise ValueError("Eye projection falls outside the closed eyelid outline")
    return columns


def create_eyelid(side, upper, columns, horizontal, outward, depth):
    kind = "U" if upper else "L"
    material = bpy.data.materials["MAT_Dragon_DarkScales"]
    points, weights, bones = [], [], []
    rows = []
    for index, (x, low, high) in enumerate(columns):
        rim_y = high if upper else low
        rim = horizontal * x + outward * depth + Vector((0, 0, rim_y))
        rim_index = len(points)
        points.append(rim)
        if index in (0, len(columns) - 1):
            rows.append((rim_index, rim_index))
            weights.append("Head")
            continue

        seam_y = low + (high - low) * .42
        # Overlap the eyelids at the seam so no highlight leaks through.
        seam_y += -.007 if upper else .007
        seam = rim + Vector((0, 0, seam_y - rim_y))
        edge_index = len(points)
        points.append(seam)
        rows.append((rim_index, edge_index))
        column = "ABCDE"[index - 1]
        rim_name = f"Lid{kind}{side}Rim{column}"
        edge_name = f"Lid{kind}{side}Edge{column}"
        bones.extend(((rim_name, rim, .05, "Head"), (edge_name, seam, .05, "Head")))
        weights.extend((rim_name, edge_name))

    faces = []
    for (rim_a, edge_a), (rim_b, edge_b) in zip(rows, rows[1:]):
        face = list(dict.fromkeys((rim_a, rim_b, edge_b, edge_a)))
        normal = (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]])
        if normal.dot(outward) < 0:
            face.reverse()
        faces.append(face)

    name = f"DragonLid{kind}{side}"
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name="UVMap")
    center = sum(points, Vector()) / len(points)
    for loop in mesh.loops:
        offset = points[loop.vertex_index] - center
        uv.data[loop.index].uv = (.5 + offset.dot(horizontal) * .7, .5 + offset.z * .7)
    mesh.update()
    part = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(part)
    return part, weights, bones


def create_eyelids():
    lids = []
    bones = []
    for side, sign in (("L", -1), ("R", 1)):
        iris, pupil = (bpy.data.objects[f"{name} {side}"] for name in ("Crimson iris", "Volcanic pupil"))
        outward = Vector((sign * .735, -.678, 0)).normalized()
        horizontal = Vector((sign * .678, .735, 0)).normalized()
        eye_vertices = [
            part.matrix_world @ vertex.co for part in (iris, pupil) for vertex in part.data.vertices
        ]
        front = max(point.dot(outward) for point in eye_vertices)
        columns = eye_columns(eye_vertices, horizontal, outward, front + .018)
        for upper, clearance in ((True, .018), (False, .014)):
            part, weights, drivers = create_eyelid(side, upper, columns, horizontal, outward, front + clearance)
            lids.append((part, weights))
            bones.extend(drivers)
    return lids, bones


def pose_owner(part, head, jaw):
    # Keep the attachment joint in importers that prune unused bones.
    # This inner glow stays rigid to the head through MouthOrigin.
    if part.name == "Mouth__ThroatGlow":
        return "MouthOrigin"
    ancestor = part.parent
    while ancestor is not None:
        if ancestor == jaw:
            return "Jaw"
        if ancestor == head:
            return "Head"
        ancestor = ancestor.parent
    if part.name.startswith(("Left_Forelimb", "Right_Forelimb")):
        return ROOT
    return None


def create_armature(head_origin, jaw_origin, lid_bones):
    # All bind bones use +Y forward, +Z up, +X dragon-right in local space.
    # They are parented and offset, never auto-connected or reoriented.
    bones = (
        (ROOT, (0, .54, .70), .65, None),
        ("Chest", (0, -.3, 1.25), .55, ROOT),
        ("NeckBase", (0, -.79, 1.48), .86, ROOT),
        ("NeckMid", (0, -2.13, 1.68), .96, "NeckBase"),
        ("NeckUpper", (0, -3.50, 1.78), .89, "NeckMid"),
        ("Head", head_origin, .80, "NeckUpper"),
        ("Jaw", jaw_origin, .70, "Head"),
        ("MouthOrigin", (0, -7.34, 1.125), .25, "Head"),
    )
    data = bpy.data.armatures.new(RIG_NAME)
    rig = bpy.data.objects.new(RIG_NAME, data)
    bpy.context.scene.collection.objects.link(rig)
    rig.show_in_front = True
    data.display_type = "STICK"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, origin, length, parent in (*bones, *lid_bones):
        bone = data.edit_bones.new(name)
        bone.head = origin
        bone.tail = Vector(origin) + Vector((0, -length, 0))
        bone.align_roll(Vector((0, 0, 1)))
        if parent is not None:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["MouthForwardLocal"] = (0.0, 1.0, 0.0)
    return rig


def bind_part(part, rig, owner, lid_weights=None):
    # Use identical mesh-to-armature transforms across all parts, allowing one
    # skin in GLB and leaving bind-pose PBR/UV attributes untouched.
    transform = part.matrix_world.copy()
    if part.data.users > 1:
        part.data = part.data.copy()
    part.data.transform(transform)
    part.parent = rig
    part.matrix_parent_inverse = Matrix.Identity(4)
    part.matrix_world = Matrix.Identity(4)

    if lid_weights is not None:
        groups = {}
        for vertex, name in zip(part.data.vertices, lid_weights):
            if name not in groups:
                groups[name] = part.vertex_groups.new(name=name)
            groups[name].add([vertex.index], 1.0, "REPLACE")
    elif owner is not None:
        group = part.vertex_groups.new(name=owner)
        group.add(list(range(len(part.data.vertices))), 1.0, "REPLACE")
    else:
        groups = {}
        for vertex in part.data.vertices:
            for name, weight in breathing_weights(vertex.co).items():
                if name not in groups:
                    groups[name] = part.vertex_groups.new(name=name)
                groups[name].add([vertex.index], weight, "REPLACE")

    modifier = part.modifiers.new("Volcanic Dragon Skin", "ARMATURE")
    modifier.object = rig
    part.data.update()


def bind_dragon():
    scene = bpy.context.scene
    head, jaw = (bpy.data.objects[name] for name in ("Head_Pivot", "Jaw_Pivot"))
    if jaw.parent != head:
        raise ValueError("Expected the source Jaw_Pivot to be parented to Head_Pivot")
    if bpy.data.objects.get(RIG_NAME):
        raise ValueError("Open the original static dragon before binding")
    parts = [part for part in scene.objects if part.type == "MESH"]
    if not parts or not any(part.name.startswith("Torso__") for part in parts):
        raise ValueError("Open the optimized Game.blend or import the static game GLB")
    bpy.context.view_layer.update()
    owners = {part: pose_owner(part, head, jaw) for part in parts}
    lids, lid_bones = create_eyelids()
    rig = create_armature(head.matrix_world.translation.copy(), jaw.matrix_world.translation.copy(), lid_bones)
    for part in parts:
        bind_part(part, rig, owners[part])
    for part, lid_weights in lids:
        bind_part(part, rig, None, lid_weights)
        parts.append(part)
    bpy.data.objects.remove(jaw, do_unlink=True)
    bpy.data.objects.remove(head, do_unlink=True)
    bpy.context.view_layer.update()
    return rig, parts


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--source", type=Path, help="Optional optimized .blend or static .glb")
    args.add_argument("--output", type=Path, default=Path(__file__).resolve().parent)
    options = args.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    if options.source:
        if options.source.suffix.lower() == ".blend":
            bpy.ops.wm.open_mainfile(filepath=str(options.source.resolve()))
        elif options.source.suffix.lower() == ".glb":
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(options.source.resolve()))
        else:
            raise ValueError("Source must be a .blend or .glb")

    output = options.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    rig, parts = bind_dragon()
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "VolcanicDragon_Rigged.blend"))
    for part in parts:
        part.select_set(True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(output / "VolcanicDragon_Rigged.glb"),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_extras=True,
    )
    if result != {"FINISHED"}:
        raise RuntimeError(f"glTF export failed: {result}")
    print(f"Exported {len(parts)} skinned meshes and {len(rig.data.bones)} bones.")


if __name__ == "__main__":
    main()
