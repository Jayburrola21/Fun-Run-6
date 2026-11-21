"""Create the editable motorcycle, a compact FBX, and six orthographic previews."""

import argparse
from collections import defaultdict
from pathlib import Path
import sys

import bpy
from mathutils import Vector

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
sys.dont_write_bytecode = True

from common import COLLECTIONS, build_materials, collection, project_uv
from studio import VIEWS, aim, render_views, studio

MAX_PART_TRIANGLES = 9_500
MIN_TRIANGLE_AREA = 1e-11  # Square metres. Exclude collapsed bevel slivers.
PIVOTS = {
    "FrontWheel": Vector((0, -.6975, .300)),
    "RearWheel": Vector((0, .6975, .310)),
    "FrontForks": Vector((0, -.455, .85)),
    "Handlebars": Vector((0, -.455, .85)),
    "Swingarm": Vector((0, .237, .489)),
}


def build_model():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.length_unit = 'METERS'
    scene.unit_settings.scale_length = 1
    build_materials()
    for name in COLLECTIONS:
        collection(name)

    from body import build_body
    from wheels import build_wheels
    from mechanical import build_mechanical
    from cockpit import build_cockpit
    for stage in (build_body, build_wheels, build_mechanical, build_cockpit):
        print(f"Building {stage.__name__}", flush=True)
        stage()


def asset_objects():
    for name in COLLECTIONS:
        group = bpy.data.collections[name]
        for obj in group.objects:
            if obj.type in {'MESH', 'CURVE', 'FONT', 'SURFACE'}:
                yield name.removeprefix("R7_"), obj


def asset_points():
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    points = []
    for _, source in asset_objects():
        obj = source.evaluated_get(graph)
        data = obj.data if obj.type == 'MESH' else obj.to_mesh()
        points.extend(obj.matrix_world @ vertex.co for vertex in data.vertices)
        if obj.type != 'MESH':
            obj.to_mesh_clear()
    return points


def mechanical_group(group, obj):
    """Keep wheel-mounted brake hardware with its wheel on export."""
    name = obj.name.lower()
    if group == "Brakes":
        if any(token in name for token in ("rotor", "carrier", "disc", "bobbin", "sweep", "drill", "drive flange", "spider ring")):
            return "RearWheel" if "rear" in name else "FrontWheel"
        return "Swingarm" if "rear" in name else "FrontForks"
    if group == "Chain" and "rear" in name and "sprocket" in name:
        return "RearWheel"
    if group == "Cockpit" and any(token in name for token in (
        "triple clamp", "tripletree", "fork preload", "preload adjuster", "rebound", "steering stem",
    )):
        return "FrontForks"
    if "rear" not in name and ("fender" in name or "mudguard" in name):
        return "FrontForks"
    return group


def export_model(path):
    """Bake a temporary evaluated copy and group meshes by assembly and material."""
    graph = bpy.context.evaluated_depsgraph_get()
    matrices = []
    for group, source in asset_objects():
        evaluated = source.evaluated_get(graph)
        data = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=graph)
        matrices.append((mechanical_group(group, source), data, evaluated.matrix_world.copy()))
    temp = bpy.data.collections.new("FBX export staging")
    bpy.context.scene.collection.children.link(temp)
    staged = []
    batches = defaultdict(list)
    try:
        for group, data, matrix in matrices:
            data.transform(matrix)
            if not data.uv_layers:
                project_uv(data)
            data.calc_loop_triangles()
            loop_uv = data.uv_layers.active.uv
            per_material = defaultdict(list)
            for triangle in data.loop_triangles:
                if triangle.area >= MIN_TRIANGLE_AREA:
                    shader = data.materials[triangle.material_index]
                    per_material[shader].append(triangle)
            for shader, faces in per_material.items():
                records = batches[(group, shader)]
                for triangle in faces:
                    records.append(tuple((data.vertices[index].co.copy(), loop_uv[loop].vector.copy(),
                                          data.corner_normals[loop].vector.copy(), (data, index))
                                         for index, loop in zip(triangle.vertices, triangle.loops)))
        for (group, shader), records in sorted(batches.items(), key=lambda item: (item[0][0], item[0][1].name)):
            for n, start in enumerate(range(0, len(records), MAX_PART_TRIANGLES), 1):
                label = f"R7_{group}__{shader.name}" + (f"__{n:02}" if n > 1 else "")
                points, faces, uvs, normals = [], [], [], []
                lookup = {}
                tris = records[start:start + MAX_PART_TRIANGLES]
                if group in PIVOTS:
                    pivot = PIVOTS[group]
                else:
                    low = [min(point[axis] for tri in tris for point, *_ in tri) for axis in range(3)]
                    high = [max(point[axis] for tri in tris for point, *_ in tri) for axis in range(3)]
                    pivot = (Vector(low) + Vector(high)) * .5
                for triangle in tris:
                    face = []
                    for point, uv, normal, key in triangle:
                        if key not in lookup:
                            lookup[key] = len(points)
                            points.append(point - pivot)
                        face.append(lookup[key])
                        uvs.append(uv)
                        normals.append(normal)
                    faces.append(tuple(face))
                out = bpy.data.meshes.new(label)
                out.from_pydata(points, [], faces)
                out.update()
                out.materials.append(shader)
                for face in out.polygons:
                    face.use_smooth = True
                layer = out.uv_layers.new(name="UVMap")
                for slot, value in zip(layer.uv, uvs):
                    slot.vector = value
                out.normals_split_custom_set(normals)
                obj = bpy.data.objects.new(label, out)
                temp.objects.link(obj)
                obj.location = pivot
                staged.append(obj)
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        for obj in staged:
            obj.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=str(path), use_selection=True, object_types={'MESH'},
            axis_forward='Z', axis_up='Y', apply_unit_scale=True,
            apply_scale_options='FBX_SCALE_UNITS', bake_anim=False,
            path_mode='AUTO', mesh_smooth_type='OFF', use_custom_props=False,
        )
        print(f"Exported {len(staged)} meshes and {sum(map(len, batches.values())):,} triangles", flush=True)
    finally:
        del batches
        for obj in staged:
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.meshes.remove(data)
        bpy.data.collections.remove(temp)
        for _, data, _ in matrices:
            bpy.data.meshes.remove(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=TOOLS.parent / "dist")
    parser.add_argument("--views", nargs="*", choices=VIEWS, default=tuple(VIEWS))
    parser.add_argument("--draft", action="store_true")
    parser.add_argument("--render-existing", action="store_true")
    parser.add_argument("--denoiser", type=Path, help="optional path to the oidnDenoise executable")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    if args.render_existing:
        bpy.ops.wm.open_mainfile(filepath=str(args.out / "Yamaha_R7_Detailed.blend"))
        camera = bpy.context.scene.camera
    else:
        build_model()
        if not args.draft:
            export_model(args.out / "Yamaha_R7_Roblox.fbx")
        camera = studio()

    points = asset_points()
    aim(camera, "three-quarter", points)
    if not args.draft and not args.render_existing:
        for area in bpy.context.screen.areas if bpy.context.screen else ():
            if area.type == 'VIEW_3D':
                viewport = area.spaces.active.region_3d
                viewport.view_perspective = 'CAMERA'
                viewport.view_camera_zoom = 0
                area.spaces.active.overlay.show_overlays = False
                area.spaces.active.shading.color_type = 'MATERIAL'
                area.spaces.active.clip_end = 100
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(args.out / "Yamaha_R7_Detailed.blend"), compress=True)
    render_views(camera, args.views, points, args.out / "previews", args.draft, args.denoiser)


if __name__ == "__main__":
    main()
