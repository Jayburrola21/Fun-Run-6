"""Editable steering controls, lamps, mirrors, instruments and badges."""
from math import cos, pi, sin, tau

from mathutils import Vector

from common import bolt, box, ellipsoid, mesh, rod, tube

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


def steering():
    x_axis = (1, 0, 0)
    clamp_v = (0, .939, -.344)
    fork_axis = Vector((0, .385, .923)).normalized()
    outline = [
        (-.143, -.011), (-.128, -.036), (-.086, -.039), (-.053, -.028),
        (.053, -.028), (.086, -.039), (.128, -.036), (.143, -.011),
        (.131, .022), (.101, .033), (.063, .039), (.042, .055),
        (-.042, .055), (-.063, .039), (-.101, .033), (-.131, .022),
    ]
    plaque("Upper triple clamp • forged bridge", (0, -.432, .945), x_axis, clamp_v,
           outline, .018, "frame", COCKPIT, .004)
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        top = Vector((s * .102, -.411, .987))
        ring("Fork preload collar " + tag, top - fork_axis * .015, fork_axis,
             .030, .025, .010, "satin", COCKPIT, 32)
        bolt("Hex preload adjuster " + tag, top + fork_axis * .003,
             fork_axis, .014, "steel", COCKPIT, .008)
        rod("Rebound adjustment head " + tag, top + fork_axis * .004,
            top + fork_axis * .012, .0065, "alloy", COCKPIT, 16, .0009)
        plaque("Rebound screwdriver slot " + tag, top + fork_axis * .0125,
               x_axis, clamp_v, [(-.004, -.00065), (.004, -.00065), (.004, .00065), (-.004, .00065)],
               .0007, "black", COCKPIT)
        bolt("Tripletree pinch bolt " + tag, (s * .128, -.400, .935), (s, 0, 0),
             .006, "alloy", COCKPIT, .006)

    stem = Vector((0, -.376, .985))
    ring("Steering stem lock ring", stem - fork_axis * .009, fork_axis, .019, .012,
         .012, "steel", COCKPIT)
    bolt("Hollow steering stem top nut", stem, fork_axis, .013, "alloy", COCKPIT, .007)
    ignition = Vector((0, -.408, .975))
    rod("Ignition cylinder", ignition - fork_axis * .018, ignition, .018, "matte", COCKPIT, 32, .002)
    ring("Ignition key escutcheon", ignition, fork_axis, .014, .010, .003, "alloy", COCKPIT)
    plaque("Ignition machined key slot", ignition + fork_axis * .001, x_axis, clamp_v,
           [(-.005, -.0015), (.005, -.0015), (.005, .0015), (-.005, .0015)],
           .001, "black", COCKPIT)


def clip_ons():
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        root = Vector((s * .109, -.425, .944))
        grip_start = Vector((s * .188, -.393, .952))
        grip_end = Vector((s * .327, -.331, .924))
        axis, u, v = axis_basis(grip_end - grip_start)
        ring("Clip-on steering tube clamp " + tag, root, (0, .385, .923),
             .033, .026, .017, "satin", BARS, 32)
        rod("Clip-on aluminum handle " + tag, root, grip_end, .0105, "alloy", BARS, 20, .001)
        rod("Textured rubber grip " + tag, grip_start, grip_end, .0165, "rubber", BARS, 32, .002)
        for i in range(1, 13):
            ring("Grip traction rib " + tag, grip_start.lerp(grip_end, i / 14), axis,
                 .0175, .0161, .0020, "rubber", BARS, 20)
        rod("Handlebar end weight " + tag, grip_end - axis * .003, grip_end + axis * .012,
            .016, "satin", BARS, 24, .0027)
        bolt("Handlebar end socket screw " + tag, grip_end + axis * .012, axis,
             .0045, "alloy", BARS, .002)
        housing_center = grip_start - axis * .013
        rod("Throttle housing" if s == -1 else "Clutch switch housing",
            grip_start - axis * .030, grip_start + axis * .009, .023, "satin", BARS, 20, .003)
        box("Engine cutoff rocker" if s == -1 else "High beam rocker",
            housing_center + Vector((0, .007, .023)), (.016, .014, .005),
            "red_lens" if s == -1 else "matte", BARS, .0017)
        box("Start button" if s == -1 else "Horn / indicator switch",
            housing_center + Vector((0, .020, .006)), (.012, .006, .010), "matte", BARS, .0015)
        box("Master cylinder" if s == -1 else "Clutch lever bracket",
            (s * .183, -.425, .952), (.045, .043, .033), "matte", BARS, .005)
        pivot = (s * .194, -.449, .954)
        bolt("Lever hinge pin " + tag, pivot, (0, 0, 1), .006, "alloy", BARS, .006)
        lever = [(s * .190, -.447, .950), (s * .219, -.449, .949),
                 (s * .251, -.431, .945), (s * .292, -.408, .936), (s * .314, -.403, .932)]
        strip("Front brake lever" if s == -1 else "Clutch lever", lever,
              [.009, .013, .010, .008, .009], (0, 0, 1), .009, "steel", BARS)
        ellipsoid("Safety ball tip " + tag, lever[-1], (.008, .008, .006), "steel", BARS)
        tube("Brake hydraulic line" if s == -1 else "Clutch cable", [
            (s * .181, -.438, .951), (s * .165, -.47, .941),
            (s * .138, -.480, .897), (s * .091, -.467, .846),
            (s * .081, -.492, .779)], .0033, "rubber", BARS)
    box("Front brake hydraulic reservoir", (-.165, -.443, .989), (.041, .035, .032),
        "satin", BARS, .006)
    box("Brake reservoir top lid", (-.165, -.443, 1.007), (.041, .035, .006),
        "frame", BARS, .002)
    for x in (-.177, -.153):
        bolt("Reservoir cap screw", (x, -.443, 1.010), (0, 0, 1), .0024, "alloy", BARS, .0013)


def mirrors():
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        root = (s * .139, -.668, .994)
        elbow = (s * .203, -.621, 1.045)
        tip = (s * .264, -.589, 1.070)
        ellipsoid("Mirror base gasket " + tag, root, (.021, .028, .011), "matte", DETAILS)
        tube("Angled mirror support " + tag, [root, elbow, tip], .009, "satin", DETAILS)
        ellipsoid("Mirror articulation cover " + tag, tip, (.019, .013, .015), "matte", DETAILS)
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


def dashboard():
    center = Vector((0, -.543, .962))
    u, v = Vector((-1, 0, 0)), Vector((0, -.75, .66)).normalized()
    n = u.cross(v)
    outline = [(-.083, -.028), (-.069, -.043), (.069, -.043), (.083, -.028),
               (.077, .027), (.062, .035), (-.062, .035), (-.077, .027)]
    tube("Instrument harness", [(0, -.538, .948), (0, -.513, .916), (.021, -.485, .893)],
         .007, "rubber", COCKPIT)
    for s in (-1, 1):
        rod("Instrument cluster bracket", (s * .051, -.501, .922), (s * .056, -.545, .962),
            .007, "frame", COCKPIT)
    plaque("Digital instrument cluster housing", center, u, v, outline, .033, "satin", COCKPIT, .004)
    plaque("Instrument surrounding glass bezel", center + n * .017, u, v,
           [(x * .91, y * .90) for x, y in outline], .004, "alloy", COCKPIT, .001)
    plaque("Instrument polarized display glass", center + n * .020, u, v,
           [(x * .85, y * .79) for x, y in outline], .0025, "black", COCKPIT, .0014)

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
    pixel("Neutral indicator stem", .048, -.003, .0025, .013, "green")
    pixel("Neutral indicator stem", .057, -.003, .0025, .013, "green")
    normal = center + n * .0218
    strip("Neutral indicator diagonal", [normal + u * .048 + v * .003, normal + u * .057 - v * .009],
          [.002, .002], n, .0005, "green", COCKPIT)
    for s in (-1, 1):
        for a, b in ((.075, -.021), (.064, .025)):
            bolt("Instrument surround fixing", center + u * s * a + v * b + n * .017,
                 n, .0025, "alloy", COCKPIT, .001)


def fuel_cap():
    from body import tank_surface

    axis = (0, 0, 1)
    center = Vector((0, -.205, tank_surface(0, -.205) + .004))
    rod("Fuel cap inset gasket", center - Vector((0, 0, .006)), center, .041, "black", COCKPIT, 48, .002)
    ring("Fuel cap brushed mounting ring", center, axis, .038, .027, .006, "steel", COCKPIT, 64)
    rod("Fuel filler hinged door", center - Vector((0, 0, .003)), center + Vector((0, 0, .004)),
        .027, "satin", COCKPIT, 48, .0013)
    box("Fuel flap locking cylinder surround", center + Vector((0, .005, .005)),
        (.028, .019, .003), "alloy", COCKPIT, .003)
    box("Keyway", center + Vector((0, .006, .007)), (.015, .0027, .001), "black", COCKPIT, .001)
    for i in range(7):
        a = pi / 2 + tau * i / 7
        point = center + Vector((.033 * cos(a), .033 * sin(a), .003))
        bolt("Fuel cap recessed anchor", point, axis, .0027, "satin", COCKPIT, .0013)


def lights():
    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        drl = [
            (s * .062, -.925, .785), (s * .088, -.897, .815),
            (s * .119, -.869, .830), (s * .151, -.840, .842), (s * .179, -.806, .856),
        ]
        normal = Vector((s * .50, -.81, .18)).normalized()
        strip("Inset running light black surround " + tag, drl,
              [.008, .021, .019, .018, .005], normal, .016, "black")
        inset = [Vector(p) + normal * .0012 for p in drl]
        strip("Pearl white LED signature " + tag, inset,
              [.0025, .011, .010, .009, .0015], normal, .004, "white")
        glint = [p + normal * .0004 + Vector((0, 0, .001)) for p in inset]
        strip("Running light inner diffuser facet " + tag, glint,
              [.0008, .0035, .003, .002, .0007], normal, .001, "white")

    headlamp = Vector((0, -.936, .786))
    face = Vector((0, -1, .05)).normalized()
    rod("Projector headlight body", headlamp - face * .022, headlamp, .025,
        "matte", LIGHTS, 40, .004)
    ring("Projector fluted surround", headlamp, face, .0222, .016, .005, "satin", LIGHTS, 48)
    ring("Projector reflector edge", headlamp + face * .001, face, .016, .0128, .003, "chrome", LIGHTS)
    ellipsoid("Projector convex cover glass", headlamp + face * .001,
              (.014, .0055, .014), "glass", LIGHTS, 36, 20)
    ellipsoid("Projector interior LED optic", headlamp + face * .0007,
              (.0102, .003, .0102), "chrome", LIGHTS, 24, 16)
    ellipsoid("Projector optic center", headlamp + face * .0022,
              (.0044, .002, .0044), "white", LIGHTS)

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
        signal(s, "Rear " + tag, (s * .041, .976, .718), (s * .111, .989, .722), rear=True)
        signal(s, "Front " + tag, (s * .183, -.577, .743), (s * .236, -.581, .742), rear=False)

    plate_up = Vector((0, .3894, .9211))
    plate_axis = Vector((0, .9211, -.3894))
    plate_face = Vector((0, 1.032, .627))
    outline = [(-.037, -.009), (.037, -.009), (.040, -.004), (.040, .006), (.034, .010),
               (-.034, .010), (-.040, .006), (-.040, -.004)]
    plaque("Plate bracket red reflector gasket", plate_face, (-1, 0, 0), plate_up,
           outline, .008, "satin", LIGHTS, .0018)
    plaque("Plate bracket red reflector", plate_face + plate_axis * .0045, (-1, 0, 0), plate_up,
           [(x * .93, y * .8) for x, y in outline], .004, "red_lens", LIGHTS, .0010)
    for x in (-.036, .036):
        bolt("Rear reflector housing screw", plate_face + Vector((x, 0, 0)) + plate_axis * .005, plate_axis, .0024,
             "steel", LIGHTS, .001)


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
        cx, cy = s * .151, -.205
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
    from body import SCREEN_STATIONS, sample, windscreen

    def screen_y(x, z):
        lo, hi = 0.0, 1.0
        for _ in range(22):
            mid = (lo + hi) * .5
            half_width = sample(SCREEN_STATIONS, mid)[0]
            _, y, point_z = windscreen(mid, .5 + x / (2 * half_width))
            if point_z < z:
                lo = mid
            else:
                hi = mid
        return y

    for s in (-1, 1):
        tag = "L" if s == 1 else "R"
        for x, z in ((.129, 1.001), (.114, 1.054)):
            y = screen_y(x, z)
            center = (s * x, y - .0016, z)
            axis = (s * .60, -.73, .32)
            rod("Screen isolating washer " + tag, (s * x, y + .0009, z), center, .0055,
                "matte", DETAILS, 16, .0007)
            bolt("Screen mounting button fastener " + tag, center, axis,
                 .0040, "steel", DETAILS, .0020)


def build_cockpit():
    steering()
    clip_ons()
    mirrors()
    dashboard()
    fuel_cap()
    lights()
    tank_emblems()
    fairing_decals()
    screen_mounts()
