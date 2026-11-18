"""Bind the existing optimized dragon to a Roblox-compatible neck rig.

Open the optimized VolcanicDragon_Game.blend, or supply its static GLB:
    blender -b VolcanicDragon_Game.blend --python-exit-code 1 --python build_dragon_rig.py -- --output ./out
    blender -b --python-exit-code 1 --python build_dragon_rig.py -- --source ../VolcanicDragon.glb --output ./out
"""

import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


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


def create_armature(head_origin, jaw_origin):
    # All bind bones use +Y forward, +Z up, +X dragon-right in local space.
    # They are parented and offset, never auto-connected or reoriented.
    bones = (
        (ROOT, (0, .54, .70), .65, None),
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
    for name, origin, length, parent in bones:
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


def bind_part(part, rig, owner):
    # Use identical mesh-to-armature transforms across all parts, allowing one
    # skin in GLB and leaving bind-pose PBR/UV attributes untouched.
    transform = part.matrix_world.copy()
    if part.data.users > 1:
        part.data = part.data.copy()
    part.data.transform(transform)
    part.parent = rig
    part.matrix_parent_inverse = Matrix.Identity(4)
    part.matrix_world = Matrix.Identity(4)

    if owner is not None:
        group = part.vertex_groups.new(name=owner)
        group.add(list(range(len(part.data.vertices))), 1.0, "REPLACE")
    else:
        groups = {}
        for vertex in part.data.vertices:
            for name, weight in core_weights(vertex.co).items():
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
    rig = create_armature(head.matrix_world.translation.copy(), jaw.matrix_world.translation.copy())
    for part in parts:
        bind_part(part, rig, owners[part])
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
