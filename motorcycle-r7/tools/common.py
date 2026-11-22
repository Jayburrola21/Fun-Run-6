"""Mesh and material helpers for the R7 model. Dimensions are in metres."""

import math

import bpy
from mathutils import Euler, Vector


COLLECTIONS = (
    "R7_Body", "R7_FrontFairing", "R7_FuelTank", "R7_Seats", "R7_FrontWheel",
    "R7_RearWheel", "R7_FrontForks", "R7_Brakes", "R7_Engine", "R7_Frame",
    "R7_Swingarm", "R7_Chain", "R7_Exhaust", "R7_Handlebars", "R7_Cockpit",
    "R7_Lights", "R7_Details",
)


def collection(name):
    existing = bpy.data.collections.get(name)
    if existing is None:
        existing = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(existing)
    return existing


def material(name, color, metallic=0, roughness=.4, *, coat=0, coat_roughness=.19,
             specular=.5, alpha=1, emission=0):
    result = bpy.data.materials.get(name)
    if result is not None:
        return result
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color[:3], alpha)
    result.metallic = metallic
    result.roughness = roughness
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color[:3], 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = specular
    shader.inputs["Coat Weight"].default_value = coat
    shader.inputs["Coat Roughness"].default_value = coat_roughness
    shader.inputs["Alpha"].default_value = alpha
    if emission:
        shader.inputs["Emission Color"].default_value = (*color[:3], 1)
        shader.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        result.surface_render_method = 'DITHERED'
    return result


def add_grain(result, scale, strength, distance):
    tree = result.node_tree
    coordinates = tree.nodes.new("ShaderNodeTexCoord")
    noise = tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 2
    bump = tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = distance
    tree.links.new(coordinates.outputs["Object"], noise.inputs["Vector"])
    tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"], tree.nodes.get("Principled BSDF").inputs["Normal"])


def build_materials():
    material("paint", (.0040, .0040, .0055), .29, .25, coat=.27, coat_roughness=.22, specular=.32)
    material("paint_alt", (.0042, .0042, .0057), .29, .26, coat=.26, coat_roughness=.23, specular=.32)
    material("satin", (.020, .023, .028), .14, .42)
    material("matte", (.019, .022, .027), .10, .54)
    material("frame", (.052, .059, .067), .60, .43)
    material("engine", (.073, .078, .081), .73, .36)
    material("alloy", (.025, .029, .034), .66, .32, coat=.20)
    material("steel", (.36, .39, .43), .81, .33)
    rotor = material("rotor", (.52, .55, .58), .81, .41)
    rotor.node_tree.nodes.get("Principled BSDF").inputs["Anisotropic"].default_value = .5
    material("exhaust", (.27, .25, .22), .80, .34)
    add_grain(material("rubber", (.015, .016, .017), 0, .62), 750, .19, .0002)
    add_grain(material("seat", (.019, .021, .024), 0, .69), 1250, .32, .00045)
    material("smoke", (.027, .033, .043), .03, .23, alpha=.40, coat=.06, coat_roughness=.27, specular=.16)
    material("glass", (.068, .10, .14), .20, .16, alpha=.55, coat=.48)
    material("white", (.53, .79, 1), .08, .19, emission=2.1)
    material("red", (.92, .009, .012), .1, .22, emission=1.4)
    material("amber", (.91, .235, .020), .25, .26, emission=.18)
    material("red_lens", (.35, .012, .015), .24, .24, coat=.42)
    material("clear", (.52, .62, .70), .15, .20, alpha=.66, coat=.45)
    material("decal", (.224, .248, .284), .43, .32)
    material("chrome", (.66, .72, .79), .94, .15)
    material("gold", (.50, .33, .13), .71, .31)
    material("green", (.045, .47, .12), .04, .23, emission=.75)
    material("black", (.007, .008, .010), .10, .46)


def _link(name, data, material_key, destination):
    obj = bpy.data.objects.new(name, data)
    group = collection(destination) if isinstance(destination, str) else destination
    group.objects.link(obj)
    if material_key:
        shader = bpy.data.materials[material_key] if isinstance(material_key, str) else material_key
        data.materials.append(shader)
    return obj


def project_uv(data):
    """Fill missing UVs with metric box projection for repeating materials."""
    layer = data.uv_layers.new(name="UVMap")
    for face in data.polygons:
        normal = face.normal
        major = max(range(3), key=lambda axis: abs(normal[axis]))
        first, second = ((1, 2), (0, 2), (0, 1))[major]
        direction = 1 if normal[major] >= 0 else -1
        for loop in face.loop_indices:
            point = data.vertices[data.loops[loop].vertex_index].co
            layer.uv[loop].vector = (point[first] * direction * 2, point[second] * 2)
    return layer


def mesh(name, vertices, faces, material, collection, smooth=False, bevel=0, uv=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(list(vertices), [], list(faces))
    data.update()
    obj = _link(name, data, material, collection)
    for face in data.polygons:
        face.use_smooth = smooth
    if uv is None:
        project_uv(data)
    else:
        layer = data.uv_layers.new(name="UVMap")
        if len(uv) == len(data.polygons):
            uv = [point for polygon_uv in uv for point in polygon_uv]
        if len(uv) != len(data.loops):
            raise ValueError(f"{name} UV count differs from mesh loop count")
        for slot, point in zip(layer.uv, uv):
            slot.vector = point
    if bevel:
        modifier = obj.modifiers.new("Machined edges", 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = 'ANGLE'
        modifier.harden_normals = True
    return obj


def tube(name, points, radius, material, collection, closed=False, resolution=3):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = max(3, resolution)
    data.bevel_depth = radius
    data.bevel_resolution = 2
    data.use_fill_caps = not closed
    spline = data.splines.new('BEZIER')
    spline.bezier_points.add(len(points) - 1)
    for point, xyz in zip(spline.bezier_points, points):
        point.co = xyz
        point.handle_left_type = 'AUTO'
        point.handle_right_type = 'AUTO'
    spline.use_cyclic_u = closed
    spline.use_smooth = True
    return _link(name, data, material, collection)


def rod(name, a, b, radius, material, collection, vertices=20, bevel=0.0):
    a, b = Vector(a), Vector(b)
    direction = (b - a).normalized()
    lateral = direction.cross(Vector((0, 0, 1) if abs(direction.z) < .95 else (1, 0, 0))).normalized()
    vertical = direction.cross(lateral)
    points = []
    for center in (a, b):
        for i in range(vertices):
            angle = i * math.tau / vertices
            points.append(center + radius * (math.cos(angle) * lateral + math.sin(angle) * vertical))
    faces = [tuple(reversed(range(vertices))), tuple(range(vertices, 2 * vertices))]
    for i in range(vertices):
        j = (i + 1) % vertices
        faces.append((i, j, j + vertices, i + vertices))
    obj = mesh(name, points, faces, material, collection, smooth=vertices > 8, bevel=bevel)
    obj.data.polygons[0].use_smooth = False
    obj.data.polygons[1].use_smooth = False
    return obj


def ellipsoid(name, center, radii, material, collection, segments=24, rings=12):
    x, y, z = center
    rx, ry, rz = radii
    points = [(x, y, z + rz)]
    for j in range(1, rings):
        polar = math.pi * j / rings
        for i in range(segments):
            angle = math.tau * i / segments
            points.append((x + rx * math.sin(polar) * math.cos(angle),
                           y + ry * math.sin(polar) * math.sin(angle),
                           z + rz * math.cos(polar)))
    points.append((x, y, z - rz))
    faces = []
    for i in range(segments):
        nxt = (i + 1) % segments
        faces.append((0, 1 + i, 1 + nxt))
        for j in range(rings - 2):
            start = 1 + j * segments
            faces.append((start + i, start + i + segments, start + nxt + segments, start + nxt))
        last = 1 + (rings - 2) * segments
        faces.append((last + i, len(points) - 1, last + nxt))
    return mesh(name, points, faces, material, collection, smooth=True)


def box(name, center, size, material, collection, bevel=.003, rotation=None):
    corners = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
               (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
    orientation = Euler(rotation).to_matrix() if rotation is not None else None
    points = []
    for signs in corners:
        point = Vector(tuple(value * sign / 2 for value, sign in zip(size, signs)))
        points.append(Vector(center) + (orientation @ point if orientation is not None else point))
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(name, points, faces, material, collection, bevel=bevel)


def bolt(name, center, axis, radius, material, collection, depth=.005):
    origin = Vector(center)
    tip = origin + Vector(axis).normalized() * depth
    return rod(name, origin, tip, radius, material, collection, vertices=6, bevel=min(depth * .2, .001))
