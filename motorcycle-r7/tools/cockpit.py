"""Editable steering controls, lamps, mirrors, instruments and badges."""
from math import atan, cos, pi, sin, tau

from mathutils import Vector, geometry

from common import bolt, box, ellipsoid, mesh, rod, tube
from wheels import BRAKE_DISTRIBUTOR, FORK_SLOPE, STEERING_OFFSET, fork_center

BARS = "R7_Handlebars"
COCKPIT = "R7_Cockpit"
LIGHTS = "R7_Lights"
DETAILS = "R7_Details"


def axis_basis(axis):
    axis = Vector(axis).normalized()
    u = axis.orthogonal().normalized()
    return axis, u, axis.cross(u)


def ring(name, center, axis, outer, inner, depth, material, collection, count=48):
    """An open-center machined ring with inner, outer and end surfaces."""
    axis, u, v = axis_basis(axis)
    center = Vector(center)
    verts = [
        center + axis * z + (u * cos(a * tau / count) + v * sin(a * tau / count)) * radius
        for z, radius in ((depth / 2, outer), (depth / 2, inner), (-depth / 2, inner), (-depth / 2, outer))
        for a in range(count)
    ]
    faces = [
        (row * count + j, row * count + (j + 1) % count,
         (row + 1) % 4 * count + (j + 1) % count, (row + 1) % 4 * count + j)
        for row in range(4) for j in range(count)
    ]
    return mesh(name, verts, faces, material, collection)


def layered(name, loops, material, collection, bevel=0):
    """Bridge matching outline loops to form a beveled solid."""
    count = len(loops[0])
    faces = [tuple(reversed(range(count)))]
    for row in range(len(loops) - 1):
        faces.extend(
            (row * count + j, row * count + (j + 1) % count,
             (row + 1) * count + (j + 1) % count, (row + 1) * count + j)
            for j in range(count)
        )
    faces.append(tuple(range((len(loops) - 1) * count, len(loops) * count)))
    return mesh(name, [point for loop in loops for point in loop], faces, material, collection, bevel=bevel)


def plaque(name, center, u, v, outline, depth, material, collection, bevel=0):
    center, u, v = Vector(center), Vector(u), Vector(v)
    n = u.cross(v).normalized()
    return layered(name, [
        [center + u * a + v * b + n * height for a, b in outline]
        for height in (-depth / 2, depth / 2)
    ], material, collection, bevel)


def strip(name, points, widths, normal, depth, material, collection=LIGHTS):
    """A conformal light blade with a tapered cross section."""
    points = [Vector(p) for p in points]
    n = Vector(normal).normalized()
    verts = []
    for i, (p, width) in enumerate(zip(points, widths)):
        tangent = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        side = n.cross(tangent).normalized() * width / 2
        verts.extend((p + side, p - side, p - side - n * depth, p + side - n * depth))
    faces = [(3, 2, 1, 0)]
    for i in range(len(points) - 1):
        faces.extend(
            (i * 4 + j, i * 4 + (j + 1) % 4, (i + 1) * 4 + (j + 1) % 4, (i + 1) * 4 + j)
            for j in range(4)
        )
    faces.append(tuple(range((len(points) - 1) * 4, len(points) * 4)))
    return mesh(name, verts, faces, material, collection, bevel=.0005)


FORK_AXIS = Vector((0, FORK_SLOPE, 1)).normalized()
FORK_U = Vector((1, 0, 0))
FORK_V = FORK_AXIS.cross(FORK_U)


def fork_position(side, z):
    return Vector(fork_center(side, z))


def perforated_clamp(name, center, outline, holes, depth):
    """Cut fork and stem bores into the caps of a continuous forging."""
    loops = [[Vector((x, y, 0)) for x, y in outline]]
    for x, y, radius in holes:
        loops.append([
            Vector((x + radius * cos(-tau*i/32), y + radius * sin(-tau*i/32), 0))
            for i in range(32)
        ])
    points = [point for loop in loops for point in loop]
    count = len(points)
    triangles = []
    for triangle in geometry.tessellate_polygon(loops):
        a, b, c = triangle
        if (points[b] - points[a]).cross(points[c] - points[a]).z < 0:
            b, c = c, b
        triangles.append((a, b, c))
    faces = [tuple(reversed(tri)) for tri in triangles]
    faces.extend(tuple(k + count for k in tri) for tri in triangles)
    offset = 0
    for loop in loops:
        for i in range(len(loop)):
            a = offset + i
            b = offset + (i + 1) % len(loop)
            faces.append((a, b, b + count, a + count))
        offset += len(loop)
    vertices = [
        center + FORK_U * point.x + FORK_V * point.y + FORK_AXIS * h
        for h in (-depth / 2, depth / 2) for point in points
    ]
    mesh(name, vertices, faces, "frame", COCKPIT, bevel=.0018)


def steering():
    clamp_center = fork_position(0, .958)
    stem_offset = STEERING_OFFSET * FORK_V.y
    outline = [
        (-.140, -.009), (-.134, -.024), (-.120, -.037), (-.101, -.041),
        (-.080, -.038), (-.061, -.027), (-.040, -.019), (.040, -.019),
        (.061, -.027), (.080, -.038), (.101, -.041), (.120, -.037),
        (.134, -.024), (.140, -.009), (.138, .015), (.128, .032),
        (.111, .039), (.093, .038), (.076, .033), (.055, .037),
        (.035, .047), (.020, .054), (-.020, .054), (-.035, .047),
        (-.055, .037), (-.076, .033), (-.093, .038), (-.111, .039),
        (-.128, .032), (-.138, .015),
    ]
    fork_width = fork_position(1, .958).x
    holes = [(-fork_width, 0, .02815), (fork_width, 0, .02815), (0, stem_offset, .0176)]
    perforated_clamp("Upper triple clamp • bored forging", clamp_center, outline, holes, .018)

    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        top = fork_position(s, .994)
        ring("Fork preload collar " + tag, top - FORK_AXIS * .003, FORK_AXIS,
             .0200, .0145, .0038, "satin", COCKPIT, 32)
        bolt("Hex preload adjuster " + tag, top, FORK_AXIS, .0135, "steel", COCKPIT, .0055)
        rod("Rebound adjustment head " + tag, top + FORK_AXIS * .002,
            top + FORK_AXIS * .008, .0064, "alloy", COCKPIT, 16, .0008)
        plaque("Rebound screwdriver slot " + tag, top + FORK_AXIS * .0082,
               FORK_U, FORK_V, [(-.004, -.00065), (.004, -.00065), (.004, .00065), (-.004, .00065)],
               .0006, "black", COCKPIT)
        bolt("Tripletree pinch bolt " + tag, clamp_center + Vector((s * .138, -.010, .001)),
             (s, 0, 0), .0042, "alloy", COCKPIT, .0041)

    stem = clamp_center + FORK_V * stem_offset
    ring("Steering stem lock ring", stem + FORK_AXIS * .010, FORK_AXIS, .022, .0167,
         .0036, "steel", COCKPIT)
    ring("Hollow steering stem top nut", stem + FORK_AXIS * .014, FORK_AXIS, .0186, .0085,
         .0062, "alloy", COCKPIT, 12)
    ignition = Vector((0, -.447, .975))
    rod("Ignition stalk mounting sleeve", (0, -.438, .912), ignition - FORK_AXIS * .020,
        .0128, "frame", COCKPIT, 24, .0016)
    rod("Ignition cylinder", ignition - FORK_AXIS * .022, ignition, .0168, "matte", COCKPIT, 32, .002)
    ring("Ignition key escutcheon", ignition, FORK_AXIS, .0139, .0098, .003, "alloy", COCKPIT)
    plaque("Ignition machined key slot", ignition + FORK_AXIS * .0013, FORK_U, FORK_V,
           [(-.005, -.0014), (.005, -.0014), (.005, .0014), (-.005, .0014)],
           .0008, "black", COCKPIT)


def clip_ons():
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        root = fork_position(s, .922)
        grip_start = Vector((s * .186, -.384, .918))
        grip_end = Vector((s * .315, -.350, .889))
        axis = (grip_end - grip_start).normalized()
        u = Vector((0, 0, 1))
        u = (u - axis * u.dot(axis)).normalized()
        v = u.cross(axis)
        if v.y < 0:
            v = -v
        ring("Clip-on steering tube clamp " + tag, root, FORK_AXIS,
             .0335, .0281, .018, "satin", BARS, 32)
        bolt("Clip-on clamp tangential fastener " + tag, root + Vector((s * .030, -.012, 0)),
             (0, -1, 0), .0045, "alloy", BARS, .004)
        shoulder = grip_start - axis * .051
        rod("Clip-on forged root " + tag, root + Vector((s * .024, .003, 0)), shoulder + axis * .008,
            .0121, "satin", BARS, 20, .0029)
        rod("Clip-on aluminum handle " + tag, shoulder, grip_end, .0105, "alloy", BARS, 20, .001)
        rod("Textured rubber grip " + tag, grip_start, grip_end, .0157, "rubber", BARS, 32, .0014)
        for i in range(1, 13):
            ring("Grip traction rib " + tag, grip_start.lerp(grip_end, i / 14), axis,
                 .01645, .0154, .0017, "rubber", BARS, 20)
        ring("Rubber grip inboard lip " + tag, grip_start + axis * .003, axis,
             .018, .0152, .0052, "rubber", BARS, 32)
        rod("Handlebar end weight " + tag, grip_end - axis * .002, grip_end + axis * .013,
            .0157, "satin", BARS, 24, .0027)
        bolt("Handlebar end socket screw " + tag, grip_end + axis * .013, axis,
             .0045, "alloy", BARS, .002)

        housing_center = grip_start - axis * .015
        rod("Throttle housing" if s == -1 else "Clutch switch housing",
            grip_start - axis * .031, grip_start - axis * .002, .0202, "satin", BARS, 24, .0028)
        pod = housing_center + u * .019 + v * .006
        switch_outline = [(-.009, -.007), (.009, -.007), (.009, .007), (-.009, .007)]
        plaque("Engine cutoff rocker" if s == -1 else "High beam rocker",
               pod, axis, v, switch_outline,
               .006, "red_lens" if s == -1 else "matte", BARS, .0018)
        pod = housing_center + v * .019 + u * .006
        ellipsoid("Start button" if s == -1 else "Horn / indicator switch", pod,
                  (.007, .004, .005), "matte", BARS, 16, 10)

        hinge = Vector((s * .178, -.426, .920))
        rod("Master cylinder" if s == -1 else "Clutch perch", housing_center - v * .012, hinge,
            .011, "matte", BARS, 20, .0028)
        bolt("Lever hinge pin " + tag, hinge + u * .008, u, .0053, "alloy", BARS, .004)
        lever = [hinge - u * .001, (s * .199, -.437, .920),
                 (s * .222, -.430, .916), (s * .260, -.412, .907),
                 (s * .288, -.397, .902), (s * .303, -.391, .901)]
        strip("Front brake lever" if s == -1 else "Clutch lever", lever,
              [.012, .0126, .0094, .0078, .007, .0085], (0, -.22, 1), .007, "steel", BARS)
        ellipsoid("Safety ball tip " + tag, lever[-1], (.007, .007, .005), "steel", BARS, 20, 12)

        if s == -1:
            reservoir = Vector((-.143, -.424, .970))
            tube("Brake reservoir mounting tab", [hinge, (-.159, -.430, .941), reservoir + Vector((0, 0, -.011))],
                 .004, "frame", BARS)
            box("Front brake hydraulic reservoir", reservoir, (.034, .032, .028),
                "satin", BARS, .004)
            box("Brake reservoir top lid", reservoir + Vector((0, 0, .0155)), (.035, .033, .0036),
                "frame", BARS, .0012)
            for x in (-.153, -.133):
                bolt("Reservoir cap screw", (x, -.424, .987), (0, 0, 1), .0023, "alloy", BARS, .0012)
            tube("Brake master-cylinder feed hose", [
                reservoir + Vector((0, 0, -.009)), (-.147, -.435, .943), (-.164, -.434, .922),
            ], .0032, "rubber", BARS)
            cable_end = [(-.112, -.453, .859), BRAKE_DISTRIBUTOR]
        else:
            cable_end = [(.129, -.480, .841), (.095, -.440, .807)]
        tube("Brake hydraulic line" if s == -1 else "Clutch cable",
             [hinge - v * .009, (s * .162, -.445, .926), (s * .141, -.461, .901), *cable_end],
             .0029, "rubber", BARS)


def mirrors():
    from body import nose_point

    def surface(u, v, side):
        point = Vector(nose_point(u, v))
        along = Vector(nose_point(u + .001, v)) - Vector(nose_point(u - .001, v))
        rise = Vector(nose_point(u, v + .001)) - Vector(nose_point(u, v - .001))
        normal = along.cross(rise).normalized()
        point.x *= side
        normal.x *= side
        return point, normal

    foot = [(-1, -.68), (-.65, -1), (.57, -1), (.91, -.69),
            (1, .64), (.54, .86), (-.61, .89), (-1, .63)]
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        root, normal = surface(.770, .925, s)

        def foot_loop(scale, depth):
            loop = []
            for x, y in foot:
                point, axis = surface(.770 + .058 * scale * x, .925 + .074 * scale * y, s)
                loop.append(point + axis * depth)
            return loop if s == 1 else list(reversed(loop))

        layered("Mirror base conformal gasket " + tag, [foot_loop(1, -.0012), foot_loop(1, .0016)],
                "matte", DETAILS, .00045)
        layered("Mirror stalk bolt-on foot " + tag,
                [foot_loop(.92, .00145), foot_loop(.89, .0041), foot_loop(.78, .0053)],
                "satin", DETAILS, .0006)
        for along in (-1, 1):
            screw, axis = surface(.770, .925 + along * .045, s)
            bolt("Mirror base fixing " + tag, screw + axis * .0052,
                 axis, .0028, "alloy", DETAILS, .00125)
        ball = root + normal * .012
        elbow = (s * .209, -.644, 1.027)
        tip = (s * .266, -.594, 1.074)
        rod("Mirror root swivel " + tag, root + normal * .0044, ball + normal * .003,
            .009, "satin", DETAILS, 24, .0018)
        tube("Angled mirror support " + tag, [ball, elbow, tip], .0075, "satin", DETAILS)
        ellipsoid("Mirror articulation cover " + tag, tip, (.016, .012, .013), "matte", DETAILS)
        points = [
            (.246, -.589, 1.072), (.258, -.582, 1.047), (.288, -.578, 1.048),
            (.332, -.573, 1.067), (.3525, -.571, 1.093), (.344, -.571, 1.112),
            (.313, -.575, 1.116), (.275, -.582, 1.099),
        ]
        center = Vector((.299, -.58, 1.084))
        loops = []
        for scale, dy in ((.67, -.027), (.98, -.014), (1, 0), (.95, .005)):
            outline = [center.lerp(Vector(point), scale) for point in points]
            loop = [(s * p.x, p.y + dy, p.z) for p in outline]
            loops.append(loop if s == -1 else list(reversed(loop)))
        layered("Mirror aerodynamic shell " + tag, loops, "paint", DETAILS, .0018)
        lens = [center.lerp(Vector(point), .82) for point in points]
        face = [(s * p.x, p.y + .006, p.z) for p in lens]
        face = face if s == -1 else list(reversed(face))
        layered("Mirror glass " + tag, [[(x, y - .002, z) for x, y, z in face], face],
                "chrome", DETAILS, .0008)


def inner_cowling():
    """Form the stationary dashboard deck against the actual cowl edges."""
    from body import cheek_surface, nose_point, sample, shell

    outer_front = Vector(cheek_surface(0, 0))
    center_profile = [
        (-.858, .898), (-.753, .918), (-.653, .933),
        (-.571, .921), (-.518, .891),
    ]

    def deck(u, v):
        cross = 2*v - 1
        q = abs(cross)
        nose = Vector(nose_point(q, 1))
        rim = Vector(cheek_surface(.325*u, 0))
        y, z = sample(center_profile, u)
        point = Vector((0, y, z)).lerp(rim, q*q)
        point.x = q*rim.x
        front = Vector((q*outer_front.x,
                        -.858 + (outer_front.y + .858)*q*q,
                        .898 + (outer_front.z - .898)*q*q))
        point += (nose - front) * (1-u)**4
        # Raise the instrument shoulder ahead of the display and scallop the
        # wings into the side cowls. The rolled hem makes room at the steering head.
        center_crown = max(0., 1 - (q/.55)**2)**2
        wing_scallop = max(0., 1 - ((q-.72)/.28)**2)**2
        brow = sin(pi*min(u/.62, 1))**2
        point.z += .025*brow*center_crown - .016*sin(pi*u)*wing_scallop
        point.y -= .014*u**6*center_crown
        point.z -= u**7*(.008*(1-q*q) + .010*wing_scallop)
        point.x *= -1 if cross < 0 else 1
        return point + Vector((0, .001, -.003))

    shell("Inner meter deck • molded wraparound cowling", deck, 26, 40, "black",
          COCKPIT, (0, 0, -.003), 2, 1)
    for side in (-1, 1):
        for u in (.30, .77):
            seat = deck(u, .5 + side*.442)
            bolt("Inner cowling fixing", seat - Vector((0, 0, .0001)),
                 (0, .16, 1), .003, "alloy", COCKPIT, .0011)


def tank_shoulder_panels():
    """Bridge each upper cheek to the tank hem below the controls."""
    from body import cheek_surface, sample, shell, tank_hem

    cheek_stations = (.310, .400, .500, .600, .700, .810, .910)
    inner_stations = [
        (.160, -.540, .890),
        (.150, -.489, .844),
        (.149, -.438, .799),
    ]
    for y in (-.387, -.347, -.300, -.253):
        x, fitted_y, z = tank_hem(y)
        inner_stations.append((x - .002, fitted_y, z - .001))

    upper_band = .6
    for side, tag in ((1, "L"), (-1, "R")):
        def bridge(u, v):
            seam = Vector(sample(inner_stations, u))
            if v <= upper_band:
                across = v / upper_band
                cheek_u, = sample([(station,) for station in cheek_stations], u)
                flange = Vector(cheek_surface(cheek_u, .040))
                flange.x -= .0026
                point = flange.lerp(seam, across)
                point.z += .009*sin(pi*u)*sin(pi*across) - .004*across*(1-across)
            else:
                # The return tucks behind the turning fork instead of projecting
                # the full upper surface into the steering envelope.
                t = (v - upper_band) / (1 - upper_band)
                reach = max(0., 1 - ((u - .29)/.17)**2)**2
                point = seam + Vector((-.023*reach*t**1.8, .020*reach*t,
                                       -(.004 + .070*reach)*t))
            point.x *= side
            return point

        def thickness(u, v):
            t = max(0., (v - upper_band) / (1 - upper_band))
            return side*.0024*t, 0, -.003*(1-t)

        shell("Tank shoulder • molded inner bridge " + tag, bridge, 24, 20, "paint",
              COCKPIT, thickness, 2, 1)


def front_air_guides():
    """Back the fairing mouth with a molded upper return and radiator guides."""
    from body import main_fairing_surface, nose_lower_edge, nose_point, sample, shell

    front_group = "R7_FrontFairing"

    def ceiling(u, v):
        cross = 2*v - 1
        q = abs(cross)
        lip = Vector(nose_point(q, 0))
        rear = Vector((.219*q, -.628 + .024*q*q, .773 + .014*q*q - .047*sin(pi*q)))
        point = lip.lerp(rear, u)
        point.z += .020*sin(pi*u)*(1 - .30*q*q)
        point.x *= -1 if cross < 0 else 1
        # Tuck the flange into the nose return without showing through the paint.
        return point + Vector((0, .002, .0006))

    shell("Front intake • curved upper liner", ceiling, 16, 34, "black",
          front_group, (0, 0, .003), 2, -1)

    outer_lip = Vector(nose_point(.94, 0))
    cheek_join = Vector(main_fairing_surface(.022, 0))
    joint_shift = cheek_join - Vector(nose_lower_edge(cheek_join.y))
    for side, tag in ((1, "L"), (-1, "R")):
        def side_guide(u, v):
            # The outer lip follows the lower nose and the leading fairing edge.
            if u < .23:
                t = u/.23
                lip_y = outer_lip.y + (cheek_join.y - outer_lip.y)*t
                lip = Vector(nose_lower_edge(lip_y)) + joint_shift*t
            else:
                lip = Vector(main_fairing_surface(.022, (u-.23)/.77))
            lip.x -= .003
            z = .747 - .190*u
            middle = (.203 - .017*u, -.530 + .027*u, z + .008)
            shoulder = (.179 - .010*u, -.440 + .027*u, z + .002)
            seal = (.145, -.397 - .29*(z - .656), z)
            x, y, z = sample((lip, middle, shoulder, seal), v)
            return side*x, y, z

        shell("Front intake • curved radiator guide " + tag, side_guide, 22, 16, "black",
              front_group, (side*.003, 0, 0), 0, -side, triangulate=True)

    def brow(u, v):
        cross = 2*v - 1
        q = abs(cross)
        front = Vector((cross*.161, -.414 + .010*q*q, .758 + .018*(1-q*q)))
        rear = Vector((cross*.156, -.389 + .005*q*q, .754 + .006*(1-q*q)))
        point = front.lerp(rear, u)
        point.z += .010*sin(pi*u)*(1-.35*q*q)
        return point

    shell("Radiator • arched upper closeout", brow, 8, 20, "black",
          front_group, (0, 0, .003), 2, -1)


def dashboard():
    center = Vector((0, -.622, .953))
    u, v = Vector((-1, 0, 0)), Vector((0, -.57, .822)).normalized()
    n = u.cross(v)
    outline = [(-.083, -.028), (-.069, -.043), (.069, -.043), (.083, -.028),
               (.077, .027), (.062, .035), (-.062, .035), (-.077, .027)]
    # The pod seats in a molded, widened base on the inner deck.
    base = [(-x * 1.18, -.643 - y*.36, .917 + y*.17) for x, y in outline]
    root = [center + u*x*1.13 + v*y*1.05 - n*.023 for x, y in outline]
    rim = [center + u*x*1.045 + v*y*1.06 - n*.011 for x, y in outline]
    layered("Instrument nacelle • molded deck mount", (base, root, rim), "matte", COCKPIT, .002)
    tube("Instrument harness", [(0, -.619, .913), (0, -.563, .895), (.015, -.491, .859),
                                (.021, -.452, .850)], .0047, "rubber", COCKPIT)
    plaque("Digital instrument cluster housing", center, u, v, outline, .033, "satin", COCKPIT, .004)
    plaque("Instrument surrounding glass bezel", center + n * .017, u, v,
           [(x * .91, y * .90) for x, y in outline], .004, "alloy", COCKPIT, .001)
    plaque("Instrument polarized display glass", center + n * .020, u, v,
           [(x * .85, y * .79) for x, y in outline], .0026, "black", COCKPIT, .00065)

    def pixel(name, x, y, width, height, material):
        outline = [(-width / 2, -height / 2), (width / 2, -height / 2),
                   (width / 2, height / 2), (-width / 2, height / 2)]
        plaque(name, center + n * .0216 + u * x + v * y, u, v, outline,
               .0006, material, COCKPIT, .0002)

    for i in range(17):
        height = .004 + .004 * i / 16
        pixel("LCD tachometer tick", -.063 + i * .0077, .016 + height / 2, .004, height,
              "red_lens" if i > 13 else "decal")
    for x in (-.010, .010):
        pixel("LCD speed digit vertical segment", x, -.004, .0025, .021, "decal")
    for y in (-.015, .007):
        pixel("LCD speed digit horizontal segment", 0, y, .017, .0025, "decal")
    for x, length in ((-.039, .026), (.038, .023)):
        for y in (-.017, -.024):
            pixel("LCD trip / status graduation", x, y, length, .0014, "alloy")
    pixel("Neutral indicator stem", .0475, -.003, .0021, .013, "green")
    pixel("Neutral indicator stem", .0575, -.003, .0021, .013, "green")
    normal = center + n * .0218
    strip("Neutral indicator diagonal", [normal + u * .0482 + v * .0028, normal + u * .0568 - v * .0088],
          [.002, .002], n, .0005, "green", COCKPIT)
    for s in (-1, 1):
        for a, b in ((.075, -.021), (.064, .025)):
            bolt("Instrument surround fixing", center + u * s * a + v * b + n * .017,
                 n, .0025, "alloy", COCKPIT, .001)


def fuel_cap():
    from body import tank_surface

    y = -.225
    slope = (tank_surface(0, y + .001) - tank_surface(0, y - .001)) / .002
    axis = Vector((0, -slope, 1)).normalized()
    across = Vector((1, 0, 0))
    along = axis.cross(across)
    surface = Vector((0, y, tank_surface(0, y)))
    rod("Fuel cap inset gasket", surface - axis * .006, surface + axis * .0008,
        .0402, "black", COCKPIT, 48, .0005)
    ring("Fuel cap brushed mounting ring", surface + axis * .0007, axis, .0385, .0274,
         .0031, "steel", COCKPIT, 64)
    rod("Fuel filler hinged door", surface - axis * .0027, surface + axis * .0017,
        .0267, "satin", COCKPIT, 48, .00065)
    rotation = (atan(slope), 0, 0)
    box("Fuel flap locking cylinder surround", surface + along * .0055 + axis * .0018,
        (.026, .017, .0013), "alloy", COCKPIT, .00042, rotation=rotation)
    box("Keyway", surface + along * .006 + axis * .0026,
        (.0135, .0023, .0005), "black", COCKPIT, .00016, rotation=rotation)
    for i in range(7):
        a = pi / 2 + tau * i / 7
        point = surface + .033 * (across * cos(a) + along * sin(a)) + axis * .002
        bolt("Fuel cap recessed anchor", point, axis, .0025, "satin", COCKPIT, .0007)


def running_lights():
    from body import drl_channel, projector_center, shell

    for s in (-1, 1):
        tag = "L" if s == 1 else "R"

        def glazing(u, v, outset=0, trim=0):
            u = trim + u * (1 - 2 * trim)
            v = trim + v * (1 - 2 * trim)
            x, y, z = drl_channel(u, v)
            return s * x, y + outset, z

        shell("Running-light recessed seal " + tag, lambda u, v: glazing(u, v, .0042),
              28, 6, "black", LIGHTS, (0, .0048, 0), 1, -1)
        shell("Pearl white LED signature " + tag, lambda u, v: glazing(u, v, .0021, .17),
              28, 6, "white", LIGHTS, (0, .003, 0), 1, -1)

    face = Vector((0, -1, .05)).normalized()
    projector = Vector(projector_center()) - face * .0042
    rod("Projector headlight body", projector - face * .025, projector, .0175,
        "matte", LIGHTS, 40, .0017)
    ring("Projector fluted surround", projector + face * .0013, face, .0172, .0135,
         .0031, "satin", LIGHTS, 48)
    ring("Projector reflector edge", projector + face * .0016, face, .0132, .0112,
         .0023, "chrome", LIGHTS)
    ellipsoid("Projector convex cover glass", projector + face * .0004,
              (.0118, .0038, .0118), "glass", LIGHTS, 36, 20)
    ellipsoid("Projector interior LED optic", projector - face * .0007,
              (.0090, .0023, .0090), "chrome", LIGHTS, 24, 16)
    ellipsoid("Projector optic center", projector + face * .0013,
              (.0040, .0017, .0040), "white", LIGHTS)


def lights():
    running_lights()
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        tail = [(0, .960, .950), (s * .038, .956, .950), (s * .059, .944, .942),
                (s * .069, .925, .932)]
        strip("Rear LED taillight housing " + tag, tail,
              [.024, .024, .021, .011], (s * .3, 1, -.10), .017, "matte")
        lens = [(x + s * .0008, y + .002, z) for x, y, z in tail]
        strip("Red taillight lens " + tag, lens, [.017, .017, .014, .007],
              (s * .3, 1, -.10), .003, "red_lens")
        line = [(x + s * .0011, y + .003, z + .003) for x, y, z in tail]
        strip("Rear LED upper light guide " + tag, line, [.005, .005, .0045, .002],
              (s * .3, 1, -.10), .002, "red")
        signal(s, "Rear " + tag, (s * .050, .861, .892), (s * .087, .874, .892), rear=True)
        signal(s, "Front " + tag, (s * .183, -.577, .743), (s * .236, -.581, .742), rear=False)


def signal(s, label, root, lens_center, rear):
    rod(label + " indicator rubber stalk", root, lens_center, .008, "matte", LIGHTS, 24, .002)
    body = Vector(lens_center)
    n = Vector((s * .24, .970 if rear else -.970, 0)).normalized()
    u = Vector((1 if not rear else -1, s * .2475, 0))
    v = (0, 0, 1)
    outline = [(-.027, -.004), (-.020, -.009), (.020, -.0075), (.029, -.002),
               (.025, .005), (.016, .008), (-.021, .008)]
    plaque(label + " LED turn signal shell", body, u, v, outline,
           .022, "satin", LIGHTS, .003)
    plaque(label + " turn signal lens", body + n * .011, u, v,
           [(x * .90, y * .71) for x, y in outline], .004, "clear", LIGHTS, .0012)
    for i in range(5):
        led = body + n * .0118 + u * (-.015 + .007 * i)
        ellipsoid(label + " amber LED emitter", led, (.0024, .0012, .0024),
                  "amber", LIGHTS, 12, 8)


def tank_emblems():
    from body import tank_surface

    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        cx, cy = s * .128, -.246
        z = tank_surface(cx, cy)
        slope_x = (tank_surface(cx + .0006, cy) - tank_surface(cx - .0006, cy)) / .0012
        slope_y = (tank_surface(cx, cy + .0006) - tank_surface(cx, cy - .0006)) / .0012
        n = Vector((-slope_x, -slope_y, 1)).normalized()
        u = Vector((0, s, s * slope_y)).normalized()
        v = n.cross(u)
        center = Vector((cx, cy, z)) + n * .003
        rod("Yamaha tank emblem black enamel backing " + tag, center - n * .004, center,
            .022, "satin", DETAILS, 48, .0014)
        ring("Yamaha emblem polished border " + tag, center, n, .0212, .0186, .0021,
             "steel", DETAILS, 48)
        center = center + n * .001
        for i in range(3):
            theta = pi / 2 + tau * i / 3
            arm = u * cos(theta) + v * sin(theta)
            perp = u * -sin(theta) + v * cos(theta)
            rod("Yamaha emblem tuning fork stem " + tag, center - arm * .0135,
                center + arm * .0105, .0009, "steel", DETAILS, 10)
            for branch in (-1, 1):
                tube("Yamaha emblem fork prong " + tag, [
                    center + arm * .006,
                    center + arm * .011 + perp * branch * .0032,
                    center + arm * .016 + perp * branch * .0032,
                ], .00088, "steel", DETAILS)


def fairing_decals():
    from body import side_surface

    # Four quads leave the R counter open. Subdivisions adhere to the fairing.
    shapes = {
        "R": [
            [(0, 0), (.11, 0), (.24, 1), (.12, 1)],
            [(.20, .81), (.46, .81), (.50, 1), (.23, 1)],
            [(.37, .58), (.46, .58), (.50, 1), (.41, 1)],
            [(.17, .48), (.43, .48), (.46, .65), (.19, .65)],
            [(.29, 0), (.43, 0), (.30, .53), (.18, .53)],
        ],
        "7": [
            [(.52, .80), (.96, .80), (1, 1), (.55, 1)],
            [(.58, 0), (.72, 0), (1, 1), (.87, 1)],
        ],
    }
    resolution = 5
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        for character, quads in shapes.items():
            verts, faces = [], []
            for a, b, c, d in quads:
                length = len(verts)
                for j in range(resolution):
                    t = j / (resolution - 1)
                    for i in range(resolution):
                        u = i / (resolution - 1)
                        x = (1-t) * ((1-u) * a[0] + u * b[0]) + t * ((1-u) * d[0] + u * c[0])
                        z = (1-t) * ((1-u) * a[1] + u * b[1]) + t * ((1-u) * d[1] + u * c[1])
                        y = -.365 + s * (x - .5) * .133 + s * z * .018
                        z = .681 + z * .039
                        verts.append((s * (side_surface(y, z) + .0012), y, z))
                for j in range(resolution - 1):
                    for i in range(resolution - 1):
                        k = length + j * resolution + i
                        faces.append((k, k + 1, k + resolution + 1, k + resolution))
            mesh("R7 satin fairing " + character + " " + tag, verts, faces, "decal", DETAILS)


def screen_mounts():
    from body import windscreen

    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        for u, across in ((.070, .84), (.147, .91)):
            v = .5 + s * across / 2
            center = Vector(windscreen(u, v))
            long = Vector(windscreen(u + .001, v)) - Vector(windscreen(u - .001, v))
            cross = Vector(windscreen(u, v + .001)) - Vector(windscreen(u, v - .001))
            axis = long.cross(cross).normalized()
            if axis.y > 0:
                axis = -axis
            rod("Screen isolating well nut " + tag, center - axis * .006,
                center + axis * .0008, .0047, "matte", DETAILS, 20, .0006)
            bolt("Screen mounting button fastener " + tag, center + axis * .0007, axis,
                 .0035, "steel", DETAILS, .00165)
        # A stationary bridge runs behind the acrylic to the fairing shoulder.
        outer = Vector(windscreen(.147, .5 + s * .455))
        lower = Vector(windscreen(.070, .5 + s * .420))
        anchor = Vector(windscreen(0, .5 + s * .455))
        inset = Vector((0, .0057, -.0045))
        tube("Windscreen retaining stay " + tag, [anchor + inset, lower + inset, outer + inset],
             .0038, "matte", DETAILS)


def build_cockpit():
    steering()
    clip_ons()
    mirrors()
    inner_cowling()
    tank_shoulder_panels()
    front_air_guides()
    dashboard()
    fuel_cap()
    lights()
    tank_emblems()
    fairing_decals()
    screen_mounts()
