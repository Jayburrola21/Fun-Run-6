"""Build a separate Y-up GLB from surveyed Roblox track-edge polylines."""

import argparse
from itertools import pairwise
import json
from math import ceil, dist, hypot, inf, isfinite, sin, tau
from pathlib import Path
from random import Random
import sys

import bpy
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt


SEGMENTS_PER_MESH = 256
MIN_HORIZONTAL_DISTANCE = 1e-5
# Each rock band sets its nominal descent, outward flare and relief amplitude.
# The narrow shoulder is handled separately so its slope is independent of height.
ROCK_BANDS = (
    (.14, .020, .024),
    (.29, .026, .045),
    (.45, .037, .052),
    (.61, .047, .059),
    (.77, .070, .052),
    (1., .112, .039),
)


def number(value, name):
    if type(value) not in (int, float) or not isfinite(value):
        raise ValueError(f"{name} must be a finite number")
    return float(value)


def read_spec(path, setback):
    spec = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(spec, dict):
        raise ValueError("The edge survey must be a JSON object")
    platform = number(spec.get("platform_y"), "platform_y")
    edges = spec.get("edges")
    if not isinstance(edges, list) or not edges:
        raise ValueError("edges must be a nonempty list")
    paths = []
    for index, edge in enumerate(edges, 1):
        if not isinstance(edge, dict):
            raise ValueError(f"Edge {index} must be an object")
        side, closed, coordinates = edge.get("outward"), edge.get("closed"), edge.get("points")
        if side not in ("left", "right") or type(closed) is not bool or not isinstance(coordinates, list):
            raise ValueError(f"Edge {index} needs outward, closed and points")
        points = []
        for coords in coordinates:
            if not isinstance(coords, list) or len(coords) != 3:
                raise ValueError(f"Edge {index} point must have [x, y, z] coordinates")
            point = tuple(number(value, f"Edge {index} coordinate") for value in coords)
            if point[1] - setback <= platform + .01:
                raise ValueError(f"Edge {index} must stay above platform_y after applying the setback")
            if not points or dist(points[-1], point) > MIN_HORIZONTAL_DISTANCE:
                points.append(point)
        if closed and len(points) > 1 and dist(points[0], points[-1]) <= MIN_HORIZONTAL_DISTANCE:
            points.pop()
        if len(points) < 2 + closed:
            raise ValueError(f"Edge {index} has too few distinct stations")
        chain = points + points[:1] if closed else points
        if any(hypot(b[0]-a[0], b[2]-a[2]) <= MIN_HORIZONTAL_DISTANCE for a, b in pairwise(chain)):
            raise ValueError(f"Edge {index} contains a vertical segment with no outside direction")
        paths.append((points, 1 if side == "left" else -1, closed))

    texture = spec.get("texture")
    if texture is not None:
        if not isinstance(texture, str) or not texture.strip():
            raise ValueError("texture must be a path to an image")
        texture = (path.parent / texture).resolve(strict=True)
        if not texture.is_file():
            raise ValueError("texture must be a file")
    return platform, paths, texture


def resample(points, closed, spacing):
    chain = points + points[:1] if closed else points
    stations = []
    for a, b in pairwise(chain):
        count = max(1, ceil(dist(a, b) / spacing))
        for index in range(count):
            t = index / count
            stations.append(tuple(x + (y-x)*t for x, y in zip(a, b)))
    if not closed:
        stations.append(points[-1])
    return stations


def outward_frames(points, side, closed):
    chain = points + points[:1] if closed else points
    directions = []
    lengths = []
    for a, b in pairwise(chain):
        dx, dz = b[0]-a[0], b[2]-a[2]
        span = hypot(dx, dz)
        directions.append((dx/span, dz/span))
        lengths.append(span)

    frames = []
    limits = []
    for i in range(len(points)):
        j = (i-1) % len(directions) if closed else max(i-1, 0)
        k = i % len(directions) if closed else min(i, len(directions)-1)
        ax, az = directions[j]
        bx, bz = directions[k]
        dot = ax*bx + az*bz
        if dot <= -.97:
            raise ValueError("A track edge reverses too sharply to form a continuous cliff")
        nx, nz = side*(az+bz), -side*(ax+bx)
        length = hypot(nx, nz)
        # Use a joint miter, with a cap at sharp convex turns.
        miter = min(1.9, 2/length)
        frames.append((nx/length*miter, nz/length*miter))
        turn = ax*bz - az*bx
        if turn*side < -1e-6:
            # Nearby mitered faces must leave room to turn through an inside corner.
            limits.append(.46 * min(lengths[j], lengths[k]) * (1+dot)/abs(turn))
        else:
            limits.append(inf)

    # Taper an inside-corner limit into its neighbors. A second pass around
    # a closed path propagates a limit that happens to fall at its seam.
    for indices in (range(1, len(points)), range(len(points)-2, -1, -1)):
        for i in indices:
            j = i-1 if indices.step > 0 else i+1
            limits[i] = min(limits[i], limits[j] + .45*lengths[min(i, j)])
    if closed and limits[-1] + .45*lengths[-1] < limits[0]:
        limits[0] = limits[-1] + .45*lengths[-1]
        for i in range(1, len(points)):
            limits[i] = min(limits[i], limits[i-1] + .45*lengths[i-1])
    if closed and limits[0] + .45*lengths[-1] < limits[-1]:
        limits[-1] = limits[0] + .45*lengths[-1]
        for i in range(len(points)-2, -1, -1):
            limits[i] = min(limits[i], limits[i+1] + .45*lengths[i])
    return frames, limits


def cross_sections(points, frames, limits, platform, args):
    rng = Random(args.seed)
    phases = [rng.uniform(0, tau) for _ in range(3)]
    sections = []
    for (x, y, z), (nx, nz), limit in zip(points, frames, limits):
        y -= args.setback
        height = y - platform
        long = .58*sin(x*.069 + z*.051 + phases[0]) + .29*sin(x*.131 - z*.173 + phases[1])
        short = .13*sin(x*.371 + z*.299 + phases[2])
        width = args.shoulder_width * (1 + .15*(long + short))
        rim = min(width, .42*limit)
        frame_length = hypot(nx, nz)
        x += args.edge_clearance * nx / frame_length
        z += args.edge_clearance * nz / frame_length
        section = [(x, y, z), (x + nx*rim, y-min(.34, .06*height), z + nz*rim)]
        for index, (depth, flare, relief) in enumerate(ROCK_BANDS):
            ledge = .65*sin(x*.107 - z*.131 + phases[2] + index*1.81)
            ledge += .35*sin(x*.222 + z*.239 + phases[0] - index*.73)
            swell = max(0., ledge + .31*sin(x*.061 + z*.077 + index*.91))**2
            # Outcrops rise from the wall itself and span neighboring depth bands.
            offset = width + height*args.flare_scale*max(.005, flare*(1 + .64*long) + relief*ledge + .054*swell)
            offset = min(offset, limit)
            dip = sin(x*.126 + z*.089 + phases[1] - index*1.67)
            drop = height * (depth + .045*dip + .011*ledge)
            level = platform - args.toe_penetration if depth == 1 else y-drop
            section.append((x + nx*offset, level, z + nz*offset))
        section.append((x, platform-args.toe_penetration, z))
        if args.foundation_y is not None:
            section.append((x, args.foundation_y, z))
        sections.append(section)
    return sections


def triangulate_perimeter(coords):
    """Triangulate a simple polygon, preserving even straight boundary stations."""
    perimeter = list(range(len(coords)))
    area = sum(x0*y1 - x1*y0 for (x0,y0), (x1,y1) in pairwise(coords + coords[:1]))
    if area < 0:
        perimeter.reverse()
    _, _, faces, sources, _, _ = delaunay_2d_cdt(
        [Vector(point) for point in coords], [], [perimeter], 1, 1e-6,
    )
    if any(len(source) != 1 for source in sources) or len(faces) != len(coords)-2:
        raise ValueError("The foundation boundary crosses itself or has coincident stations")
    triangles = [tuple(sources[index][0] for index in face) for face in faces]
    return [triangle[::-1] for triangle in triangles] if area < 0 else triangles


def texture_material(texture):
    shader = bpy.data.materials.new("Volcanic cliff rock")
    shader.diffuse_color = (.066, .033, .020, 1)
    shader.use_nodes = True
    surface = shader.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = shader.diffuse_color
    surface.inputs["Roughness"].default_value = .93
    if texture:
        node = shader.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(texture), check_existing=True)
        shader.node_tree.links.new(node.outputs["Color"], surface.inputs["Base Color"])
    return shader


def make_mesh(name, sections, u_coords, side, start_cap, end_cap, shader, tile_size, foundation):
    count = len(sections[0])
    looped = sections[0] is sections[-1]
    positions = sections[:-1] if looped else sections
    points = [(x, -z, y) for section in positions for x, y, z in section]
    faces, texture_coords = [], []
    dimensions = []
    for section in sections:
        v = [0.]
        for a, b in pairwise(section):
            v.append(v[-1] + dist(a, b)/tile_size)
        dimensions.append(v)

    def add_face(indices, uv):
        faces.append(indices if side == 1 else tuple(reversed(indices)))
        texture_coords.append(uv if side == 1 else tuple(reversed(uv)))

    for i in range(len(sections)-1):
        next_i = (i+1) % len(positions)
        for j in range(count):
            if foundation and j == count-2:
                # The foundation occupies the space behind this buried inner wall.
                continue
            next_j = (j+1) % count
            # Alternating diagonal grain breaks up identical rows on long grades.
            corners = (i*count+j, next_i*count+j, next_i*count+next_j, i*count+next_j)
            u0, u1 = u_coords[i:i+2]
            v00, v01 = dimensions[i][j], dimensions[i][next_j]
            v10, v11 = dimensions[i+1][j], dimensions[i+1][next_j]
            if not next_j:
                v01 = v00 + dist(sections[i][-1], sections[i][0])/tile_size
                v11 = v10 + dist(sections[i+1][-1], sections[i+1][0])/tile_size
            uv = ((u0, v00), (u1, v10), (u1, v11), (u0, v01))
            for face in (((0, 1, 3), (1, 2, 3)) if (i+j) % 2 else ((0, 1, 2), (0, 2, 3))):
                add_face(tuple(corners[k] for k in face), tuple(uv[k] for k in face))

    for end, enabled in ((False, start_cap), (True, end_cap)):
        if enabled:
            index = len(sections)-1 if end else 0
            section = sections[index]
            inner = section[0]
            order = reversed(range(count)) if end else range(count)
            indices = tuple(order)
            cap = [(hypot(section[j][0]-inner[0], section[j][2]-inner[2]), section[j][1])
                   for j in indices]
            for face in triangulate_perimeter(cap):
                add_face(tuple(index*count+indices[k] for k in face),
                         tuple((cap[k][0]/tile_size, cap[k][1]/tile_size) for k in face))
    return link_mesh(name, points, faces, texture_coords, shader)


def link_mesh(name, points, faces, texture_coords, shader):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    if mesh.validate():
        raise ValueError(f"{name}: invalid generated polygon")
    if any(face.area <= 1e-10 for face in mesh.polygons):
        raise ValueError(f"{name}: a rock band or cap collapsed")
    uvmap = mesh.uv_layers.new(name="Cliff tiled UV")
    for face, uv in zip(mesh.polygons, texture_coords):
        for loop, coord in zip(face.loop_indices, uv):
            uvmap.uv[loop].vector = coord
    mesh.materials.append(shader)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def make_foundation(rails, platform, args, shader):
    """Close the matching side strips with a single capped under-road mass."""
    left, right = rails
    boundary = left + right[::-1]
    outline = [(x, z) for x, _, z in boundary]
    triangles = triangulate_perimeter(outline)
    # +Y is up in the survey, so a roof triangle winds clockwise in X/Z.
    first = triangles[0]
    a, b, c = (outline[i] for i in first)
    if (b[0]-a[0])*(c[1]-a[1]) > (b[1]-a[1])*(c[0]-a[0]):
        triangles = [face[::-1] for face in triangles]
    toe = platform - args.toe_penetration
    count = len(boundary)
    points = [(x, -z, y) for y in (args.foundation_y, toe) for x, z in outline]
    uv = [(x/args.tile_size, z/args.tile_size) for x, z in outline] * 2
    faces = triangles + [tuple(i+count for i in reversed(face)) for face in triangles]
    texture_coords = [tuple(uv[i] for i in face) for face in faces]
    for ia, ib, invert in ((0, count-1, False), (len(left)-1, len(left), True)):
        wall = (ia+count, ib+count, ib, ia)
        width = dist(outline[ia], outline[ib])/args.tile_size
        cap_uv = ((0, toe/args.tile_size), (width, toe/args.tile_size),
                  (width, args.foundation_y/args.tile_size), (0, args.foundation_y/args.tile_size))
        faces.append(wall[::-1] if invert else wall)
        texture_coords.append(cap_uv[::-1] if invert else cap_uv)

    mesh_count = triangles = 0
    for index, begin in enumerate(range(0, len(faces), 4096), 1):
        end = min(begin+4096, len(faces))
        batch = faces[begin:end]
        used = sorted({i for face in batch for i in face})
        remap = {pos: i for i, pos in enumerate(used)}
        batch = [tuple(remap[i] for i in face) for face in batch]
        triangles += link_mesh(f"VolcanicCliff_Foundation_{index:03}", [points[i] for i in used],
                               batch, texture_coords[begin:end], shader)
        mesh_count += 1
    return mesh_count, triangles


def build(args):
    platform, paths, texture = read_spec(args.survey, args.setback)
    foundation = args.foundation_y is not None
    if foundation and (len(paths) != 2 or [side for _, side, _ in paths] != [1, -1]
                       or any(closed for _, _, closed in paths)):
        raise ValueError("--foundation-y requires two open left/right paths, in order and in the same direction")
    if foundation and not platform < args.foundation_y < min(y-args.setback for path, _, _ in paths for _, y, _ in path):
        raise ValueError("--foundation-y must be above the platform and below every cliff rim")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shader = texture_material(texture)
    mesh_count = triangles = 0
    rails = []
    for path_index, (points, side, closed) in enumerate(paths, 1):
        stations = resample(points, closed, args.spacing)
        frames, limits = outward_frames(stations, side, closed)
        sections = cross_sections(stations, frames, limits, platform, args)
        if foundation:
            rails.append([section[-1] for section in sections])
        chain = stations + stations[:1] if closed else stations
        if closed:
            sections.append(sections[0])
        u_coords = [0.]
        for a, b in pairwise(chain):
            u_coords.append(u_coords[-1] + dist(a, b)/args.tile_size)
        if closed:
            tiles = max(1, round(u_coords[-1]))
            u_coords = [u*tiles/u_coords[-1] for u in u_coords]
        segments = len(sections)-1
        for chunk, begin in enumerate(range(0, segments, SEGMENTS_PER_MESH), 1):
            end = min(begin + SEGMENTS_PER_MESH, segments)
            name = f"VolcanicCliff_{path_index:02}_{chunk:03}"
            triangles += make_mesh(name, sections[begin:end+1], u_coords[begin:end+1], side,
                                   not closed and begin == 0, not closed and end == segments,
                                   shader, args.tile_size, foundation)
            mesh_count += 1
    if foundation:
        n_meshes, n_triangles = make_foundation(rails, platform, args, shader)
        mesh_count += n_meshes
        triangles += n_triangles
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result = bpy.ops.export_scene.gltf(filepath=str(args.output.resolve()), export_format="GLB",
                                       export_yup=True, export_texcoords=True, export_normals=True)
    if result != {"FINISHED"}:
        raise RuntimeError(f"GLB export failed: {result}")
    print(f"Generated {mesh_count} cliff meshes with {triangles} triangles.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("survey", type=Path, help="JSON survey in Roblox X/Y-up/Z")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Destination GLB")
    parser.add_argument("--spacing", type=float, default=8., help="Maximum station spacing in studs")
    parser.add_argument("--shoulder-width", type=float, default=2.5, help="Nominal shoulder width in studs")
    parser.add_argument("--flare-scale", type=float, default=1., help="Scale of outward rock relief below the shoulder")
    parser.add_argument("--setback", type=float, default=.12, help="Top distance below the surveyed edge")
    parser.add_argument("--edge-clearance", type=float, default=0., help="World-horizontal gap outside the surveyed wall")
    parser.add_argument("--tile-size", type=float, default=12., help="Approximate texture repeat distance in studs")
    parser.add_argument("--toe-penetration", type=float, default=.10, help="Cliff overlap below the platform")
    parser.add_argument("--foundation-y", type=float, help="Solid under-road roof height for paired open left/right rails")
    parser.add_argument("--seed", type=int, default=7, help="Deterministic rock variation")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    for key in ("spacing", "shoulder_width", "flare_scale", "setback", "tile_size", "toe_penetration"):
        value = getattr(args, key)
        if not isfinite(value) or value <= 0:
            parser.error(f"--{key.replace('_', '-')} must be finite and positive")
    if args.output.suffix.lower() != ".glb":
        parser.error("output must have a .glb extension")
    if args.foundation_y is not None and not isfinite(args.foundation_y):
        parser.error("--foundation-y must be finite")
    if not isfinite(args.edge_clearance) or args.edge_clearance < 0:
        parser.error("--edge-clearance must be finite and nonnegative")
    build(args)


if __name__ == "__main__":
    main()
