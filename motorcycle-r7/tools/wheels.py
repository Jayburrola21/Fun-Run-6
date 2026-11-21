"""Sportbike wheel assemblies, brake hardware and inverted fork."""
from math import atan2, cos, pi, sin, tau

from mathutils import Matrix, Vector

from common import bolt, box, collection, mesh, rod, tube


FRONT = (-0.6975, 0.300)
REAR = (0.6975, 0.310)
BRAKES = "R7_Brakes"
FORKS = "R7_FrontForks"


def axle_point(center, lateral, radius, angle):
    """Map axial, radial and angular dimensions onto a wheel."""
    return lateral, center[0] + radius * cos(angle), center[1] + radius * sin(angle)


def revolved(name, center, profile, material, collection, steps=96):
    vertices = [
        axle_point(center, lateral, radius, angular * tau / steps)
        for lateral, radius in profile
        for angular in range(steps)
    ]
    faces, uv = [], []
    for row in range(len(profile)):
        next_row = (row + 1) % len(profile)
        for step in range(steps):
            next_step = (step + 1) % steps
            faces.append((
                row * steps + step,
                row * steps + next_step,
                next_row * steps + next_step,
                next_row * steps + step,
            ))
            u0, u1 = step / steps, (step + 1) / steps
            v0, v1 = row / len(profile), (row + 1) / len(profile)
            uv.append(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))
    return mesh(name, vertices, faces, material, collection, smooth=True, uv=uv)


def tire(name, center, half_width, radius, collection):
    # Each tuple describes the relaxed casing before the tread is cut. Rounded
    # sport sections roll continuously into the sidewalls and under the bead.
    profile_half = [
        (0.00, .0000, 0.00), (.10, .0006, .25), (.20, .0019, 1.00),
        (.30, .0040, 1.00), (.41, .0070, 1.00), (.52, .0109, 1.00),
        (.63, .0159, 1.00), (.73, .0222, 1.00), (.83, .0300, .78),
        (.92, .0400, .16), (.985, .0520, 0.00), (1.00, .0640, 0.00),
        (.92, .0760 + (radius - .300) * .7, 0.00), (.77, radius - .216, 0.00),
    ]
    profile = [(-x, r, d) for x, r, d in reversed(profile_half[1:])]
    profile += profile_half
    # One swept groove and one shorter shoulder groove per pitch. Their walls,
    # floors and shoulders are part of the tire mesh.
    phases = (0.00, .115, .144, .195, .233, .475, .511, .555, .591)
    pitches = 19
    steps = pitches * len(phases)
    vertices, faces, uv = [], [], []
    for fraction, drop, strength in profile:
        across = abs(fraction)
        sweep = (0.73 * across + .36 * across * across) * (1 if fraction > 0 else -1)
        short_strength = max(0.0, 1.0 - abs(across - .65) / .36)
        for pitch in range(pitches):
            for sample, phase in enumerate(phases):
                depth = 0.0
                if sample in (2, 3):
                    depth = .0026 * strength
                if sample in (6, 7):
                    depth = .0021 * strength * short_strength
                angle = (pitch + phase + sweep) * tau / pitches
                vertices.append(axle_point(center, half_width * fraction, radius - drop - depth, angle))
    for row in range(len(profile)):
        next_row = (row + 1) % len(profile)
        for step in range(steps):
            next_step = (step + 1) % steps
            faces.append((row * steps + step, row * steps + next_step,
                          next_row * steps + next_step, next_row * steps + step))
            u0, u1 = step / steps, (step + 1) / steps
            v0, v1 = row / len(profile), (row + 1) / len(profile)
            uv.append(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))
    return mesh(name, vertices, faces, "rubber", collection, smooth=True, uv=uv)


def spoke(name, center, angle, hand, material, collection, wide):
    # Sculpted, swept web with bevels at the exposed edges of each spoke.
    stations = [
        (.040, .004, .015, wide * .34),
        (.083, .003, .012, wide * .23),
        (.152, .010, .008, wide * .24),
        (.225, .024, .007, wide * .33),
    ]
    vertices = []
    for radial, offset, half_tangent, half_axis in stations:
        for lateral, tangent in (
            (-half_axis, -half_tangent * .6), (-half_axis, half_tangent * .6),
            (0, half_tangent), (half_axis, half_tangent * .65),
            (half_axis, -half_tangent * .65), (0, -half_tangent),
        ):
            vertices.append(axle_point(center, lateral, radial, angle + hand * (offset + tangent) / radial))
    faces = [tuple(reversed(range(6))), tuple(range(18, 24))]
    for row in range(3):
        for edge in range(6):
            nxt = (edge + 1) % 6
            faces.append((row * 6 + edge, row * 6 + nxt, (row + 1) * 6 + nxt, (row + 1) * 6 + edge))
    if hand < 0:
        faces = [tuple(reversed(face)) for face in faces]
    mesh(name, vertices, faces, material, collection, bevel=.0014)


def axle_ring(name, center, lateral, outer, inner, thickness, material, collection, steps=64):
    return revolved(name, center, [
        (lateral - thickness / 2, inner),
        (lateral - thickness / 2, outer - .0007),
        (lateral - thickness / 2 + .0007, outer),
        (lateral + thickness / 2 - .0007, outer),
        (lateral + thickness / 2, outer - .0007),
        (lateral + thickness / 2, inner),
    ], material, collection, steps)


def wheel(name, center, radius, half_width, rim_width, collection):
    tire(name + " tire • cut directional tread", center, half_width, radius, collection)
    rim_radius = .226
    revolved(name + " cast rim • turned bead seats", center, [
        (-rim_width, .211), (-rim_width, .224), (-rim_width + .002, rim_radius),
        (-rim_width + .006, rim_radius), (-rim_width + .011, .223), (-.015, .218),
        (.015, .218), (rim_width - .011, .223), (rim_width - .006, rim_radius),
        (rim_width - .002, rim_radius), (rim_width, .224), (rim_width, .211),
        (rim_width - .007, .209), (.016, .209), (-.016, .209), (-rim_width + .007, .209),
    ], "paint", collection)
    for side in (-1, 1):
        axle_ring(name + " machined rim lip", center, side * (rim_width - .0001),
                  .2245, .2226, .0018, "alloy", collection)
        axle_ring(name + " tire sidewall molding line", center, side * (half_width * .937),
                  radius - .043, radius - .044, .0016, "rubber", collection)
    for spoke_index in range(10):
        spoke(f"{name} swept alloy spoke {spoke_index + 1:02}", center,
              tau * spoke_index / 10, -1, "paint", collection, rim_width)
    rod(name + " forged central hub", (-rim_width, *center), (rim_width, *center), .047, "alloy", collection, 36, .003)
    axle_half_length = .109 if center == FRONT else .150
    rod(name + " wheel axle", (-axle_half_length, *center), (axle_half_length, *center),
        .014, "steel", collection, 24, .001)
    for side in (-1, 1):
        stem_start = axle_point(center, side * rim_width * .53, .218, .96)
        stem_tip = axle_point(center, side * rim_width * .74, .203, .96)
        rod(name + " valve stem", stem_start, stem_tip, .0033, "rubber", collection, 10)
        rod(name + " valve cap", stem_tip, axle_point(center, side * rim_width * .8, .199, .96),
            .003, "alloy", collection, 10, .0006)


# Twelve matched points around each annular sector. Adjacent cells share every
# boundary vertex, which leaves only the deliberate hole and disc boundaries.
CELL = (
    (1, .5), (1, .75), (1, 1), (.5, 1),
    (0, 1), (0, .75), (0, .5), (0, .25),
    (0, 0), (.5, 0), (1, 0), (1, .25),
)


def drilled_band(name, center, lateral, inner, outer, thickness, count, hole_radius):
    radii = (inner, inner + (outer - inner) * .36, inner + (outer - inner) * .69, outer)
    vertices, faces, uv = [], [], []
    lookup = {}

    def index(x, angle, radial):
        point = axle_point(center, x, radial, angle)
        key = tuple(round(v, 7) for v in point)
        if key not in lookup:
            lookup[key] = len(vertices)
            vertices.append(point)
        return lookup[key]

    skins = []
    for side in (-1, 1):
        x = lateral + side * thickness / 2
        holes, bore, edge = [], [], []
        for row in range(len(radii) - 1):
            low, high = radii[row:row + 2]
            for cell in range(count):
                intervals = tau / count
                hole_u = .38 if row % 2 else .62
                hole_v = .49
                radial_center = low + hole_v * (high - low)
                first_angle = intervals * cell
                boundary, cut = [], []
                for u, v in CELL:
                    boundary.append(index(x, first_angle + u * intervals, low + v * (high - low)))
                    phi = atan2((v - hole_v) * (high - low), (u - hole_u) * intervals * radial_center)
                    angle = first_angle + hole_u * intervals + cos(phi) * hole_radius / radial_center
                    cut.append(index(x, angle, radial_center + sin(phi) * hole_radius))
                holes.append(cut)
                if row == 0:
                    bore.extend((boundary[8], boundary[9]))
                if row == len(radii) - 2:
                    edge.extend((boundary[4], boundary[3]))
                for j in range(len(CELL)):
                    k = (j + 1) % len(CELL)
                    face = (boundary[j], boundary[k], cut[k], cut[j])
                    face = face if side < 0 else tuple(reversed(face))
                    faces.append(face)
                    uv.append([
                        (.5 + .25 * side + .23 * (vertices[i][1] - center[0]) / outer,
                         .68 + .23 * (vertices[i][2] - center[1]) / outer)
                        for i in face
                    ])
        skins.append([bore, edge, *holes])
    count = len(skins[0])
    for contour, (negative, positive) in enumerate(zip(*skins)):
        v0, v1 = .37 * contour / count, .37 * (contour + .84) / count
        for j in range(len(negative)):
            k = (j + 1) % len(negative)
            face = (negative[k], negative[j], positive[j], positive[k])
            u0, u1 = j / len(negative), (j + 1) / len(negative)
            face_uv = ((u1, v0), (u0, v0), (u0, v1), (u1, v1))
            faces.append(face if contour == 0 else tuple(reversed(face)))
            uv.append(face_uv if contour == 0 else tuple(reversed(face_uv)))
    mesh(name, vertices, faces, "rotor", BRAKES, uv=uv)


def brake_carrier(name, center, lateral, disc_inner, count, fixed):
    direction = 1 if lateral > 0 else -1
    # Hub adapter bridges the black carrier to the wheel hub.
    rod(name + " drive flange", (lateral - direction * .058, *center),
        (lateral + direction * .001, *center), .045 if fixed else .042, "alloy", BRAKES, 32, .002)
    axle_ring(name + " floating spider ring", center, lateral - direction * .003,
              .055, .034, .006, "frame", BRAKES)
    for index in range(count):
        angle = tau * index / count
        outline = [
            (.042, angle - .122), (.065, angle - .107),
            (disc_inner + .004, angle + .012), (disc_inner + .006, angle + .107),
            (.067, angle + .090), (.043, angle + .175),
        ]
        vertices = [axle_point(center, depth, r, a) for depth in (
            lateral - direction * .007, lateral + direction * .0005
        ) for r, a in outline]
        faces = [tuple(reversed(range(6))), tuple(range(6, 12))]
        for edge in range(6):
            nxt = (edge + 1) % 6
            faces.append((edge, nxt, nxt + 6, edge + 6))
        if direction < 0:
            faces = [tuple(reversed(face)) for face in faces]
        mesh(name + " carrier web", vertices, faces, "frame", BRAKES, bevel=.001)
        bolt(name + " carrier hub bolt", axle_point(center, lateral + direction * .003, .040, angle),
             (direction, 0, 0), .0043, "steel", BRAKES, .003)
        bolt(name + " floating bobbin", axle_point(center, lateral + direction * .0035,
             disc_inner + .001, angle + .065), (direction, 0, 0), .0052, "alloy", BRAKES, .003)


def caliper(name, center, lateral, radial, angle, mount):
    direction = 1 if lateral > 0 else -1
    # A bridged caliper with a central rotor slot and radially aligned pad bodies.
    dims = (.019, .039, .022)
    for offset in (-.014, .014):
        x = lateral + offset
        loc = axle_point(center, x, radial - .006, angle)
        box(name + " cast piston housing", loc, dims, "engine", BRAKES, .007, (angle - pi / 2, 0, 0))
    for delta in (-.18, .18):
        a = angle + delta
        loc = axle_point(center, lateral, radial + .010, a)
        box(name + " bridge", loc, (.046, .016, .018), "alloy", BRAKES, .004, (angle - pi / 2, 0, 0))
        bolt(name + " split case hardware", axle_point(center, lateral + direction * .024, radial + .003, a),
             (direction, 0, 0), .0047, "steel", BRAKES, .004)
        rod(name + " radial mount lug", axle_point(center, lateral + direction * .012, radial - .011, a),
            mount, .0095, "alloy", BRAKES, 16, .0015)
    bleeder = axle_point(center, lateral + direction * .016, radial + .010, angle + .12)
    rod(name + " bleeder", bleeder, (bleeder[0], bleeder[1], bleeder[2] + .010),
        .003, "steel", BRAKES, 10, .0006)


def fork():
    for side, label in ((1, "Left"), (-1, "Right")):
        def line(z):
            amount = (z - .300) / (.987 - .300)
            return side * (.105 - .003 * amount), -.6975 + .2865 * amount, z

        rod(label + " fork hard-chromed stanchion", line(.360), line(.645), .0195, "chrome", FORKS, 32, .001)
        rod(label + " fork outer cartridge", line(.565), line(.983), .0256, "satin", FORKS, 32, .0015)
        for lo, hi, radius, material in (
            (.552, .571, .024, "alloy"), (.571, .582, .027, "rubber"),
            (.719, .825, .0276, "alloy"), (.895, .983, .028, "alloy"),
            (.982, .994, .021, "steel"), (.993, .998, .010, "alloy"),
        ):
            rod(label + " fork seal, sleeve or cap", line(lo), line(hi), radius, material, FORKS, 32, .001)
        rod(label + " fork cast axle foot", line(.302), line(.432), .024, "frame", FORKS, 24, .004)
        rod(label + " fork radial brake mount", line(.425), (side * .102, -.611, .413),
            .015, "frame", FORKS, 20, .003)
        loc = line(.302)
        rod(label + " front axle boss", (side * .086, loc[1], .300),
            (side * .132, loc[1], .300), .026, "alloy", FORKS, 24, .003)
        bolt(label + " front axle nut", (side * .132, *FRONT),
             (side, 0, 0), .018, "steel", FORKS, .007)
        for z in (.318, .344):
            bolt(label + " fork pinch bolt", (side * .125, line(z)[1] - .013, z),
                 (side, 0, 0), .0055, "steel", FORKS, .004)
        reflector = line(.480)
        rx, ry, rz = reflector
        rod(label + " reflector backing", (side * .104, ry, rz), (side * .131, ry, rz), .017,
            "alloy", FORKS, 24, .001)
        rod(label + " amber fork reflector", (side * .131, ry, rz), (side * .134, ry, rz), .0146,
            "amber", FORKS, 24, .0008)
        for delta in (-.006, 0, .006):
            rod(label + " reflector prism", (side * .1345, ry - .010, rz + delta),
                (side * .1345, ry + .010, rz + delta), .00045, "gold", FORKS, 6)
        tube(label + " front brake hose",
             [(side * .077, -.598, .444), (side * .095, -.632, .503), (side * .102, -.564, .643),
              (side * .083, -.514, .754), (side * .061, -.466, .867),
              (side * .129, -.439, .940)], .0031, "rubber", FORKS)

    clamp_outline = [(-.132, -.508), (-.118, -.536), (-.085, -.540), (-.047, -.510),
                     (.047, -.510), (.085, -.540), (.118, -.536), (.132, -.508),
                     (.114, -.476), (.068, -.459), (.032, -.434), (-.032, -.434),
                     (-.068, -.459), (-.114, -.476)]
    vertices = [(x, y, z) for z in (.753, .780) for x, y in clamp_outline]
    size = len(clamp_outline)
    faces = [tuple(reversed(range(size))), tuple(range(size, size * 2))]
    faces += [(i, (i + 1) % size, (i + 1) % size + size, i + size) for i in range(size)]
    mesh("Lower triple clamp • tapered forging", vertices, faces, "frame", FORKS, bevel=.005)
    rod("Lower steering stem bearing seat", (0, -.474, .754), (0, -.460, .791), .030,
        "alloy", FORKS, 32, .002)


def build_wheels():
    front_wheel, rear_wheel = "R7_FrontWheel", "R7_RearWheel"
    wheel("Front", FRONT, .300, .060, .041, front_wheel)
    wheel("Rear", REAR, .310, .090, .0615, rear_wheel)
    for side, label in ((1, "Left"), (-1, "Right")):
        x = side * .0645
        drilled_band(label + " front brake rotor • drilled stainless", FRONT, x, .104, .1485, .0045, 22, .0026)
        brake_carrier(label + " front", FRONT, x, .104, 6, False)
        caliper(label + " front fixed caliper", FRONT, x, .145, .70, (side * .103, -.614, .410))
    drilled_band("Rear brake rotor • drilled stainless", REAR, -.108, .078, .1225, .0043, 16, .0024)
    brake_carrier("Rear", REAR, -.108, .078, 5, True)
    caliper("Rear floating caliper", REAR, -.108, .114, 2.05, (-.119, .620, .337))
    for side in (-1, 1):
        rod("Rear axle wheel spacer", (side * .058, *REAR), (side * .144, *REAR), .025,
            "steel", rear_wheel, 24, .002)
        box("Rear axle chain alignment adjuster", (side * .155, *REAR),
            (.012, .068, .043), "alloy", rear_wheel, .004)
        bolt("Rear axle retaining nut", (side * .163, *REAR), (side, 0, 0),
             .018, "steel", rear_wheel, .009)
    rod("Rear cush drive • sprocket adapter", (.061, *REAR), (.137, *REAR), .055,
        "alloy", rear_wheel, 36, .003)
    fork()

    for name, center in ((front_wheel, FRONT), (rear_wheel, REAR)):
        pivot = Vector((0, *center))
        offset = Matrix.Translation(-pivot)
        for obj in collection(name).objects:
            obj.data.transform(offset)
            obj.location = pivot
