"""Round-trip the delivery in Blender and compare it with the editable geometry."""

from itertools import chain
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils.kdtree import KDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True

from build_r7 import MAX_PART_TRIANGLES, MIN_TRIANGLE_AREA, PIVOTS, asset_objects, mechanical_group
from common import COLLECTIONS
from verify_front import verify_front


def inspect(objects):
    points = []
    triangle_count = 0
    slivers = 0
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        data = evaluated.to_mesh()
        data.transform(evaluated.matrix_world)
        data.calc_loop_triangles()
        triangles = [triangle for triangle in data.loop_triangles if triangle.area >= MIN_TRIANGLE_AREA]
        used = {index for triangle in triangles for index in triangle.vertices}
        points.extend(data.vertices[index].co.copy() for index in sorted(used))
        triangle_count += len(triangles)
        slivers += len(data.loop_triangles) - len(triangles)
        evaluated.to_mesh_clear()
    return points, triangle_count, slivers


def compare_clouds(source, imported):
    tree = KDTree(len(imported))
    for i, point in enumerate(imported):
        tree.insert(point, i)
    tree.balance()
    max_error = max(tree.find(point)[2] for point in source)
    assert max_error < .000025, f"FBX position error {max_error:.6f}m"
    return max_error


def bounds(points):
    return [(min(axis), max(axis)) for axis in zip(*points)]


def verify(folder):
    bpy.ops.wm.open_mainfile(filepath=str(folder / "Yamaha_R7_Detailed.blend"))
    assert bpy.context.scene.unit_settings.scale_length == 1
    for name in COLLECTIONS:
        assert bpy.data.collections[name].objects, name
    authored = list(asset_objects())
    authored_parts = {obj.name: obj for _, obj in authored}
    nose = authored_parts["Front nose • unified molded fairing"]
    nose_points = {tuple(round(value, 6) for value in vertex.co) for vertex in nose.data.vertices}
    assert all((-x, y, z) in nose_points for x, y, z in nose_points), "Asymmetric front cowl"
    assert not any("plate holder" in name.lower() or "eliminator" in name.lower() for name in authored_parts)
    assert "Pillion pad • tapered grained vinyl" in authored_parts
    assert "Tail tidy • recessed indicator carrier" in authored_parts
    tank = authored_parts["Fuel tank • formed steel shell"]
    assert tank.data.materials[0].name == "paint"
    tank_bounds = bounds(tank.matrix_world @ vertex.co for vertex in tank.data.vertices)
    assert .980 <= tank_bounds[2][1] <= .987, "Unexpected tank crown height"
    assert .295 <= tank_bounds[0][1] - tank_bounds[0][0] <= .315, "Unexpected tank shoulder width"
    front_verification = verify_front(authored)
    source, triangles, slivers = inspect(obj for _, obj in authored)
    source_groups = {mechanical_group(group, obj) for group, obj in authored}

    bpy.ops.wm.read_factory_settings(use_empty=True)
    result = bpy.ops.import_scene.fbx(filepath=str(folder / "Yamaha_R7_Roblox.fbx"))
    assert result == {'FINISHED'}
    parts = list(bpy.context.scene.objects)
    assert parts and all(part.type == 'MESH' for part in parts)

    dimensions = [round((hi - lo) * 1000, 1) for lo, hi in bounds(source)]
    assert all(abs(actual - target) < 45 for actual, target in zip(dimensions, (705, 2005, 1160)))
    assert abs(bounds(source)[2][0]) < .012, "Tires do not sit near ground"
    wheel_pivot_error = 0
    max_triangles = 0
    material_names = set()
    import_groups = set()
    for part in parts:
        mesh = part.data
        assert part.name.startswith("R7_") and len(mesh.materials) == 1, part.name
        sign = part.name[3:].split("__")[0]
        import_groups.add(sign)
        material_names.add(mesh.materials[0].name)
        assert all(len(face.vertices) == 3 for face in mesh.polygons), part.name
        tri_count = len(mesh.polygons)
        assert 0 < tri_count <= MAX_PART_TRIANGLES, (part.name, tri_count)
        max_triangles = max(max_triangles, tri_count)
        uv = mesh.uv_layers.active
        assert uv and len(uv.uv) == len(mesh.loops), part.name
        assert all(math.isfinite(value) for value in chain.from_iterable(slot.vector for slot in uv.uv)), part.name
        assert not mesh.validate(), f"Invalid mesh: {part.name}"
        if sign in PIVOTS:
            wheel_pivot_error = max(wheel_pivot_error, (part.matrix_world.translation - PIVOTS[sign]).length)
        assert any(face.area > 1e-9 for face in mesh.polygons), part.name
    assert import_groups == source_groups
    assert {"paint", "rubber", "seat", "smoke", "white", "red", "rotor"} <= material_names
    assert wheel_pivot_error < .000025, wheel_pivot_error
    smoked = bpy.data.materials["smoke"].node_tree.nodes.get("Principled BSDF")
    assert abs(smoked.inputs["Alpha"].default_value - .4) < 1e-5
    front = next(obj for obj in parts if obj.name == "R7_FrontWheel__rubber")
    rear = next(obj for obj in parts if obj.name == "R7_RearWheel__rubber")
    wheelbase = abs(front.location.y - rear.location.y)
    assert abs(wheelbase - 1.395) < .000025

    imported, imported_triangles, imported_small_faces = inspect(parts)
    assert imported_triangles == triangles, (imported_triangles, triangles)
    assert imported_small_faces == 0, imported_small_faces
    max_error = max(compare_clouds(source, imported), compare_clouds(imported, source))
    verification = {
        "editable_objects": len(authored),
        "editable_assembly_collections": len(COLLECTIONS),
        "fbx_mesh_parts": len(parts),
        "fbx_materials": len(material_names),
        "triangles": triangles,
        "largest_fbx_mesh_triangles": max_triangles,
        "width_mm": dimensions[0],
        "length_mm": dimensions[1],
        "height_mm": dimensions[2],
        "wheelbase_mm": round(wheelbase * 1000, 1),
        "surface_position_error_mm": round(max_error * 1000, 5),
        "collapsed_bevel_triangles_omitted": slivers,
        "all_imported_meshes_have_uvs": True,
        "front_geometry": front_verification,
        "roblox_studio_import": "unverified",
    }
    print(json.dumps(verification, indent=2))


default_folder = Path(__file__).resolve().parents[1] / "dist"
verify(Path(sys.argv[-1]).resolve() if "--" in sys.argv else default_folder)
