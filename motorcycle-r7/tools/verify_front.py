"""Check that the modeled front closes its gaps and leaves room for steering."""

from dataclasses import dataclass
from math import radians

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from build_r7 import STEERING_PIVOT, mechanical_group
from wheels import FORK_SLOPE


FRONT_LINERS = (
    "Front intake • curved upper liner",
    "Front intake • curved radiator guide L",
    "Front intake • curved radiator guide R",
    "Radiator • arched upper closeout",
)
METER_PANELS = (
    "Inner meter deck • molded wraparound cowling",
    "Instrument nacelle • molded deck mount",
)
CLOSED_PANELS = ("Front nose • unified molded fairing", *FRONT_LINERS, *METER_PANELS)
STEERING_GROUPS = {"FrontForks", "FrontWheel", "Handlebars"}
TRANSPARENT_MATERIALS = {"smoke", "glass", "clear"}


@dataclass
class Surface:
    name: str
    group: str
    opaque: bool
    points: list
    triangles: list


def verify_closed_panel(name, mesh):
    panel = bmesh.new()
    try:
        panel.from_mesh(mesh)
        assert all(edge.is_manifold and edge.is_contiguous for edge in panel.edges), (
            f"{name} has an open seam or inconsistent normals"
        )
        assert panel.calc_volume(signed=True) > 0, f"{name} normals point inward"
    finally:
        panel.free()


def evaluated_surfaces(authored):
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    for group, source in authored:
        obj = source.evaluated_get(graph)
        mesh = obj.to_mesh()
        try:
            if source.name in CLOSED_PANELS:
                verify_closed_panel(source.name, mesh)
            mesh.calc_loop_triangles()
            yield Surface(
                source.name,
                mechanical_group(group, source),
                not any(material.name in TRANSPARENT_MATERIALS for material in mesh.materials),
                [obj.matrix_world @ vertex.co for vertex in mesh.vertices],
                [tuple(triangle.vertices) for triangle in mesh.loop_triangles],
            )
        finally:
            obj.to_mesh_clear()


def surface_tree(surfaces, transform=None):
    points, triangles, names = [], [], []
    for surface in surfaces:
        offset = len(points)
        points.extend(surface.points if transform is None else (transform @ point for point in surface.points))
        triangles.extend(tuple(offset + index for index in triangle) for triangle in surface.triangles)
        names.extend([surface.name] * len(surface.triangles))
    return BVHTree.FromPolygons(points, triangles, all_triangles=True), names


def verify_sightlines(stationary):
    tree, names = surface_tree(surface for surface in stationary if surface.opaque)

    def check(origin, direction, prefix, view, limit):
        hit, normal, index, distance = tree.ray_cast(origin, direction)
        name = "no hit" if index is None else names[index]
        assert hit is not None and distance <= limit and name.startswith(prefix), (
            f"{view} sightline from {tuple(round(axis, 3) for axis in origin)} hit {name} at {hit}"
        )
        assert normal.dot(direction) < 0, f"{view} sightline hit back of {name}"

    front = Vector((0, 1, 0))
    low_front = Vector((0, 1, .20)).normalized()
    cockpit = Vector((0, -.20, -1)).normalized()
    front_panels = (*FRONT_LINERS, "Front nose", "Left main fairing", "Right main fairing")
    radiator_core = ("Radiator fin pack", "Radiator cooling row", "Radiator vertical grille rib")
    for z in (.60, .64, .68):
        for x in (-.16, .16):
            check(Vector((x, -1.5, z)), front, front_panels, "Front", 1.15)
        for x in (-.08, 0, .08):
            check(Vector((x, -1.5, z)), front, radiator_core, "Radiator inlet", 1.15)

    for x, z in ((-.16, .63), (.16, .63), (-.14, .75), (.14, .75)):
        origin = Vector((x, -.65, z)) - low_front * .70
        check(origin, low_front, front_panels, "Low front", 1.05)

    under_cowl = Vector((0, 1, .247)).normalized()
    # These camera sightlines previously showed daylight just above the forks.
    for side in (-1, 1):
        for x, z in ((.145, .774), (.145, .779), (.138, .7673), (.138, .779)):
            origin = Vector((side*x, -.50, z)) - under_cowl * .75
            check(origin, under_cowl, FRONT_LINERS, "Under cowl", .90)
    for x in (-.08, 0, .08):
        origin = Vector((x, -.65, .63)) - low_front * .70
        check(origin, low_front, radiator_core, "Low radiator inlet", 1.05)

    cockpit_surfaces = (
        *METER_PANELS, "Digital instrument cluster housing",
        "Instrument surrounding glass bezel", "Instrument polarized display glass", "LCD ",
    )
    for y in (-.72, -.68, -.64, -.60, -.56):
        for x in (-.08, -.04, 0, .04, .08):
            origin = Vector((x, y, .98)) - cockpit * .30
            check(origin, cockpit, cockpit_surfaces, "Cockpit", .43)


def verify_steering(surfaces):
    stationary_names = {
        *CLOSED_PANELS,
        "Digital instrument cluster housing",
        "Fuel tank • formed steel shell",
        "Left lower cowl • single formed belly shield",
        "Right lower cowl • single formed belly shield",
    }
    stationary_tree, stationary_face = surface_tree(
        surface for surface in surfaces if surface.name in stationary_names
    )
    moving = [surface for surface in surfaces if surface.group in STEERING_GROUPS]
    axis = Vector((0, FORK_SLOPE, 1)).normalized()
    to_pivot = Matrix.Translation(STEERING_PIVOT)
    from_pivot = Matrix.Translation(-STEERING_PIVOT)
    first_contact = None
    clear_angle = 0
    for angle in (0, 2.5, 5, 7.5, 10, 12.5, 15, 20, 25, 30):
        contacts = set()
        for signed in (-angle, angle) if angle else (0,):
            transform = to_pivot @ Matrix.Rotation(radians(signed), 4, axis) @ from_pivot
            moving_tree, moving_face = surface_tree(moving, transform)
            contacts.update((stationary_face[a], moving_face[b])
                            for a, b in stationary_tree.overlap(moving_tree))
        if contacts:
            name, part = min(contacts)
            first_contact = f"{angle}° between {name} and {part}"
            assert angle > 15, f"Insufficient steering clearance. Contact at {first_contact}"
            break
        clear_angle = angle
    return {"clear_through_degrees_each_side": clear_angle, "first_sampled_contact": first_contact}


def verify_front(authored):
    surfaces = list(evaluated_surfaces(authored))
    missing = set(CLOSED_PANELS) - {surface.name for surface in surfaces}
    assert not missing, f"Missing front panels: {sorted(missing)}"
    verify_sightlines(surface for surface in surfaces if surface.group not in STEERING_GROUPS)
    return verify_steering(surfaces)
