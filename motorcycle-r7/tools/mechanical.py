"""Sculpted chassis, parallel twin, driveline and controls for the YZF-R7."""
from math import atan2, cos, hypot, pi, sin, sqrt, tau

import bpy
from mathutils import Matrix, Vector

from common import bolt, box, ellipsoid, mesh, rod, tube


ENGINE = "R7_Engine"
FRAME = "R7_Frame"
SWINGARM = "R7_Swingarm"
CHAIN = "R7_Chain"
EXHAUST = "R7_Exhaust"
DETAILS = "R7_Details"


def side_casting(name, outline, x_inner, x_outer, material, collection, bevel=.004):
    """A casting or stamping from its longitudinal section and axial thickness."""
    vertices = [(x, y, z) for x in (x_inner, x_outer) for y, z in outline]
    count = len(outline)
    area = sum(y * outline[(i + 1) % count][1] - z * outline[(i + 1) % count][0]
               for i, (y, z) in enumerate(outline))
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    if (x_outer - x_inner) * area < 0:
        faces = [tuple(reversed(face)) for face in faces]
    return mesh(name, vertices, faces, material, collection, bevel=bevel)


def turned_cover(name, y, z, stations, material, collection, segments=48):
    vertices = [(x, y + radius * cos(tau * i / segments), z + radius * sin(tau * i / segments))
                for x, radius in stations for i in range(segments)]
    faces = [tuple(reversed(range(segments)))]
    for ring in range(len(stations) - 1):
        first = ring * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((first + i, first + j, first + j + segments, first + i + segments))
    faces.append(tuple(range(len(vertices) - segments, len(vertices))))
    if stations[0][0] > stations[-1][0]:
        faces = [tuple(reversed(face)) for face in faces]
    return mesh(name, vertices, faces, material, collection, smooth=True)


def build_frame():
    rod("Steering head casting", (0, -.466, .779), (0, -.391, .951), .058, "frame", FRAME, bevel=.005)
    rod("Upper steering bearing race", (0, -.396, .934), (0, -.388, .952), .053, "steel", FRAME)
    rod("Steering spindle", (0, -.470, .768), (0, -.387, .959), .017, "steel", FRAME)
    rod("Lower steering bearing race", (0, -.470, .770), (0, -.460, .794), .052, "engine", FRAME)
    rod("Swingarm pivot cross tube", (-.148, .237, .489), (.148, .237, .489), .046, "frame", FRAME, bevel=.003)
    rod("Lower engine support crossbar", (-.117, -.106, .321), (.117, -.106, .321), .021, "frame", FRAME)
    for side, label in ((-1, "Left"), (1, "Right")):
        tube(label + " tubular front cradle", [(side * .039, -.443, .826), (side * .119, -.365, .744),
                                              (side * .138, -.279, .574), (side * .112, -.195, .343),
                                              (side * .120, .090, .324)], .022, "frame", FRAME)
        rod(label + " load-bearing spine", (side * .051, -.392, .850), (side * .137, .123, .715),
            .043, "frame", FRAME, bevel=.004)
        side_casting(label + " cast pivot plate", [(-.062, .723), (.146, .759), (.272, .680),
                                                    (.291, .535), (.271, .453), (.164, .405),
                                                    (.103, .498), (.150, .594), (.092, .666)],
                     side * .095, side * .155, "frame", FRAME, .012)
        side_casting(label + " pivot plate rib", [(.122, .732), (.168, .714), (.222, .636),
                                                  (.230, .532), (.198, .490), (.176, .510),
                                                  (.182, .579), (.145, .662)],
                     side * .155, side * .164, "engine", FRAME, .004)
        rod(label + " upper seat rail", (side * .133, .126, .739), (side * .095, .697, .904),
            .018, "frame", FRAME)
        rod(label + " tail subframe diagonal", (side * .126, .247, .587), (side * .097, .654, .887),
            .015, "frame", FRAME)
        rod(label + " seat rail secondary brace", (side * .113, .370, .694), (side * .100, .474, .839),
            .012, "frame", FRAME)
        for y, z in ((.216, .660), (.145, .736), (.247, .547), (.157, .429)):
            bolt(label + " chassis mount", (side * .166, y, z), (side, 0, 0), .010, "steel", FRAME)
        rod(label + " pivot machined flange", (side * .153, .237, .489), (side * .170, .237, .489),
            .030, "engine", FRAME, bevel=.002)
        bolt(label + " pivot spindle hex", (side * .172, .237, .489), (side, 0, 0), .015, "alloy", FRAME)


def build_engine():
    side_casting("Cast aluminum crankcase", [(-.249, .439), (-.231, .552), (-.133, .608),
                                              (-.051, .623), (.067, .600), (.145, .552),
                                              (.172, .452), (.117, .383), (-.055, .349),
                                              (-.205, .370)], -.132, .134, "engine", ENGINE, .017)
    side_casting("Crankcase lower oil pan", [(-.187, .409), (.095, .433), (.071, .334),
                                             (.019, .316), (-.149, .323), (-.182, .357)],
                 -.108, .108, "engine", ENGINE, .010)
    # The two cylinders are canted forward and fed by separate exhaust ports.
    for index, x in enumerate((-.064, .064), start=1):
        side_casting("Cylinder %d barrel" % index, [(-.190, .500), (-.292, .694), (-.259, .744),
                                                      (-.138, .728), (-.106, .672), (-.079, .542)],
                     x - .060, x + .060, "engine", ENGINE, .008)
        for z, y in ((.588, -.154), (.605, -.163), (.625, -.171), (.639, -.181), (.653, -.187)):
            box("Cylinder %d casting web" % index, (x, y, z), (.130, .121, .009), "frame", ENGINE,
                bevel=.002, rotation=(.35, 0, 0))
        side_casting("Cylinder %d head" % index, [(-.295, .676), (-.303, .707), (-.274, .744),
                                                    (-.201, .755), (-.119, .733), (-.125, .687)],
                     x - .065, x + .065, "engine", ENGINE, .010)
        rod("Cylinder %d cam cover lip" % index, (x - .063, -.213, .743), (x + .063, -.213, .743),
            .018, "alloy", ENGINE, bevel=.002)
        rod("Cylinder %d intake throat" % index, (x, -.135, .692), (x, -.061, .758), .023, "engine", ENGINE)
        rod("Cylinder %d exhaust port" % index, (x, -.225, .619), (x, -.271, .601),
            .025, "engine", ENGINE, bevel=.003)
        rod("Cylinder %d header collar" % index, (x, -.259, .604), (x, -.277, .598),
            .029, "alloy", EXHAUST, bevel=.003)
        for offset in (-.028, .028):
            bolt("Header flange bolt", (x + offset, -.279, .602), (0, -1, -.22), .006, "steel", ENGINE)
    for side, label, y, z, radius in ((-1, "Generator", -.006, .465, .102), (1, "Clutch", .016, .466, .105)):
        turned_cover(label + " casing gasket", y, z, [(side*.124, radius*.92), (side*.145, radius)],
                     "black", ENGINE)
        turned_cover(label + " cast metal cover", y, z,
                     [(side*.143, radius), (side*.152, radius*.99), (side*.172, radius*.87),
                      (side*.179, radius*.77), (side*.183, radius*.69)], "engine", ENGINE)
        turned_cover(label + " concentric finishing ring", y, z,
                     [(side*.176, radius*.76), (side*.181, radius*.75), (side*.185, radius*.71)],
                     "frame", ENGINE)
        turned_cover(label + " machined center", y, z, [(side*.182, radius*.70),
                     (side*.187, radius*.65), (side*.188, radius*.61)], "engine", ENGINE)
        for i in range(10):
            angle = tau * i / 10 + .17
            by, bz = y + radius*.91 * cos(angle), z + radius*.91 * sin(angle)
            ellipsoid(label + " casing flange lug", (side*.152, by, bz), (.012, .013, .013),
                      "engine", ENGINE, segments=12, rings=6)
            bolt(label + " flange bolt", (side*.164, by, bz), (side, 0, 0), .0055, "steel", ENGINE)
            rod(label + " radial stiffening web",
                (side*.174, y + radius*.72*cos(angle), z + radius*.72*sin(angle)),
                (side*.164, y + radius*.88*cos(angle), z + radius*.88*sin(angle)),
                .004, "frame", ENGINE, vertices=8)
    turned_cover("Water pump housing", -.113, .425,
                 [(.123, .047), (.153, .047), (.169, .041), (.172, .035)], "engine", ENGINE)
    for angle in (0, 2.1, 4.2):
        bolt("Water pump cover bolt", (.172, -.113 + .038*cos(angle), .425 + .038*sin(angle)),
             (1, 0, 0), .005, "steel", ENGINE)
    rod("Oil fill boss", (.136, .081, .568), (.161, .086, .587), .017, "engine", ENGINE)
    bolt("Oil fill cap", (.169, .087, .592), (.81, .1, .58), .015, "alloy", ENGINE)
    bolt("Oil drain plug", (0, -.030, .313), (0, 0, -1), .010, "steel", ENGINE)
    for side in (-1, 1):
        side_casting("Engine mount ear", [(-.279, .574), (-.212, .599), (-.179, .548), (-.232, .517)],
                     side*.116, side*.142, "frame", ENGINE)
        bolt("Forward engine mount bolt", (side*.144, -.242, .556), (side, 0, 0), .012, "steel", ENGINE)
        tube("Coolant return hose", [(side*.145, -.156, .436), (side*.161, -.256, .463),
                                    (side*.151, -.298, .508), (side*.147, -.340, .569)],
             .013, "rubber", ENGINE)
        tube("Breather hose", [(side*.100, -.154, .719), (side*.137, -.040, .705),
                               (side*.110, .019, .754)], .007, "rubber", ENGINE)
    build_radiator()


def build_radiator():
    box("Radiator fin pack", (0, -.379, .656), (.292, .035, .190), "black", ENGINE,
        bevel=.010, rotation=(.29, 0, 0))
    for i in range(19):
        z = .570 + i * .0095
        rod("Radiator cooling row", (-.137, -.398 - .29*(z - .656), z),
            (.137, -.398 - .29*(z - .656), z), .0021, "alloy", ENGINE, vertices=6)
    for i in range(17):
        x = -.121 + i * .0151
        rod("Radiator vertical grille rib", (x, -.376, .570), (x, -.428, .740),
            .0016, "engine", ENGINE, vertices=6)
    for side in (-1, 1):
        side_casting("Radiator end tank", [(-.382, .551), (-.344, .563), (-.391, .747), (-.424, .739)],
                     side*.138, side*.158, "engine", ENGINE, .006)
        rod("Radiator side mounting tab", (side*.137, -.397, .730), (side*.173, -.365, .747),
            .008, "frame", ENGINE)
    tube("Radiator head inlet hose", [(-.153, -.400, .726), (-.163, -.363, .755),
                                     (-.146, -.307, .769), (-.105, -.250, .736)], .014, "rubber", ENGINE)
    rod("Radiator pressure cap neck", (.138, -.403, .737), (.138, -.403, .757), .013, "engine", ENGINE)
    bolt("Radiator pressure cap", (.138, -.403, .759), (0, 0, 1), .018, "steel", ENGINE)


def build_exhaust():
    for index, x in enumerate((-.064, .064), start=1):
        path = [(x, -.274, .600), (x, -.315, .565), (x, -.324, .485), (x, -.304, .365),
                (x, -.257, .255), (x, -.173, .220), (x*.65 + .021, -.061, .217), (.044, .015, .214)]
        tube("Stainless exhaust header %d" % index, path, .018, "exhaust", EXHAUST, resolution=5)
    side_casting("Underbody collector", [(-.084, .233), (-.022, .263), (.104, .251),
                                        (.133, .190), (.093, .164), (-.053, .177)],
                 -.065, .127, "exhaust", EXHAUST, .019)
    side_casting("Low-slung silencer shell", [( .037, .239), (.206, .261), (.293, .240),
                                               (.307, .186), (.265, .161), (.093, .158),
                                               (.047, .184)], -.040, .156, "exhaust", EXHAUST, .015)
    side_casting("Formed silencer heat shield", [(.002, .230), (.061, .250), (.201, .268),
                                                 (.269, .241), (.259, .204), (.146, .174),
                                                 (.054, .176)], .155, .165, "alloy", EXHAUST, .007)
    for y, z in ((.045, .217), (.225, .239), (.165, .191)):
        bolt("Heat shield button fastener", (.168, y, z), (1, 0, 0), .005, "engine", EXHAUST)
    a = (.106, .274, .204)
    b = (.138, .329, .217)
    axis = (Vector(b) - Vector(a)).normalized()
    radial_u = axis.cross(Vector((0, 0, 1))).normalized()
    radial_v = axis.cross(radial_u)
    profile = [(a, .025), (Vector(b) - axis*.003, .026), (b, .024),
               (b, .020), (Vector(b) - axis*.003, .018), (a, .018)]
    segments = 32
    vertices = [Vector(center) + radius*(radial_u*cos(tau*i/segments) + radial_v*sin(tau*i/segments))
                for center, radius in profile for i in range(segments)]
    faces = [(ring*segments + i,
              ring*segments + (i+1) % segments,
              (ring+1) % len(profile)*segments + (i+1) % segments,
              (ring+1) % len(profile)*segments + i)
             for ring in range(len(profile)) for i in range(segments)]
    mesh("Hollow exhaust outlet with rolled lip", vertices, faces, "exhaust", EXHAUST, smooth=True)
    rod("Recessed exhaust baffle", a, Vector(b) - axis*.019, .0185, "black", EXHAUST, vertices=24)


def build_swingarm():
    for side, label in ((-1, "Left"), (1, "Right")):
        side_casting(label + " box-section swingarm", [(.223, .539), (.339, .495), (.432, .445),
                     (.683, .357), (.732, .336), (.736, .291), (.695, .276), (.549, .307),
                     (.386, .374), (.279, .411), (.221, .429), (.198, .489)],
                     side*.095, side*.135, "frame", SWINGARM, .009)
        side_casting(label + " recessed swingarm reinforcement", [(.249, .513), (.439, .427),
                     (.677, .351), (.677, .332), (.547, .352), (.368, .415), (.244, .459)],
                     side*.134, side*.141, "engine", SWINGARM, .004)
        turned_cover(label + " rear axle boss", .6975, .310,
                     [(side*.120, .037), (side*.146, .037), (side*.156, .031)], "frame", SWINGARM)
        rod(label + " swingarm gusset", (side*.100, .295, .448), (side*.098, .397, .432),
            .018, "frame", SWINGARM)
    rod("Swingarm boxed bridge", (-.107, .340, .430), (.107, .340, .430), .034, "frame", SWINGARM)
    rod("Shock upper mount", (-.071, .245, .727), (.071, .245, .727), .020, "frame", FRAME, bevel=.002)
    rod("Shock lower rockshaft", (-.062, .419, .425), (.062, .419, .425), .016, "engine", SWINGARM, bevel=.002)
    for side in (-1, 1):
        side_casting("Suspension linkage dogbone", [(.265, .420), (.290, .387), (.427, .409), (.439, .437),
                                                    (.416, .451), (.294, .433)],
                     side*.046, side*.058, "alloy", SWINGARM)
        bolt("Shock lower linkage fastener", (side*.063, .419, .425), (side, 0, 0), .010, "steel", SWINGARM)
    lower = (0, .414, .430)
    upper = (0, .245, .726)
    mid = tuple(lower[i]*.52 + upper[i]*.48 for i in range(3))
    rod("Rear shock hydraulic body", mid, upper, .023, "engine", SWINGARM, bevel=.003)
    rod("Rear shock polished piston", lower, mid, .011, "chrome", SWINGARM)
    helix = []
    length = hypot(upper[1] - lower[1], upper[2] - lower[2])
    ortho_y, ortho_z = (upper[2] - lower[2])/length, (lower[1] - upper[1])/length
    for i in range(113):
        t = i / 112
        u = .15 + t*.69
        angle = tau * 7 * t
        helix.append((.035*cos(angle), lower[1] + u*(upper[1]-lower[1]) + ortho_y*.035*sin(angle),
                      lower[2] + u*(upper[2]-lower[2]) + ortho_z*.035*sin(angle)))
    tube("Rear shock helical spring", helix, .0055, "satin", SWINGARM, resolution=1)
    for u in (.13, .86):
        center = tuple(lower[i] + u*(upper[i]-lower[i]) for i in range(3))
        end = tuple(center[i] + .027*(upper[i]-lower[i]) for i in range(3))
        rod("Rear shock spring seat", center, end, .041, "alloy", SWINGARM, bevel=.002)


def sprocket(name, center, radius, teeth):
    x, y, z = center
    # Four radial stations model the root, flanks and narrow tips of each tooth.
    tooth_profile = (.956, .957, 1.026, 1.026, .957, .956)
    points = []
    for i in range(teeth * len(tooth_profile)):
        angle = tau * i / (teeth * len(tooth_profile))
        radius_at_tooth = radius * tooth_profile[i % len(tooth_profile)]
        points.append((angle, radius_at_tooth))
    for side, label in ((-1, "outer"), (1, "inner")):
        # A split face allows the outer machined shoulder to take its own material.
        phase = x + side * .0032
        vertices = [(phase, y + r*cos(a), z + r*sin(a)) for a, r in points]
        vertices += [(phase - side*.0006, y + radius*.833*cos(a), z + radius*.833*sin(a))
                     for a, _ in points]
        count = len(points)
        faces = [(i, (i+1) % count, (i+1) % count + count, i + count) for i in range(count)]
        if side < 0:
            faces = [tuple(reversed(face)) for face in faces]
        mesh(name + " " + label + " face", vertices, faces, "steel", CHAIN)
    vertices = [(x + offset, y + r*cos(a), z + r*sin(a)) for offset in (-.0032, .0032) for a, r in points]
    count = len(points)
    faces = [(i, (i+1) % count, (i+1) % count + count, i + count) for i in range(count)]
    mesh(name + " pitched teeth", vertices, faces, "alloy", CHAIN)
    turned_cover(name + " hub", y, z, [(x - .006, radius*.427), (x + .009, radius*.425)], "alloy", CHAIN)
    for i in range(6):
        angle = tau * i / 6 + .17
        profile = [(.34, -.17), (.54, -.19), (.86, -.09), (.86, .09), (.50, .17), (.34, .17)]
        outline = [(y + radius*r*cos(angle + da), z + radius*r*sin(angle + da)) for r, da in profile]
        side_casting(name + " formed web", outline, x - .0026, x + .0026, "alloy", CHAIN, .0014)
        by, bz = y + radius*.375*cos(angle), z + radius*.375*sin(angle)
        bolt(name + " carrier stud", (x - .006, by, bz), (-1, 0, 0), .0067 if teeth > 20 else .003, "steel", CHAIN)


def chain_path(front, rear, front_radius, rear_radius):
    """Return points at a consistent pitch around the common external tangents."""
    dy, dz = rear[0] - front[0], rear[1] - front[1]
    span = hypot(dy, dz)
    unit_y, unit_z = dy / span, dz / span
    projection = (front_radius - rear_radius) / span
    orthogonal = sqrt(1 - projection**2)
    high = atan2(unit_z*projection + unit_y*orthogonal, unit_y*projection - unit_z*orthogonal)
    low = atan2(unit_z*projection - unit_y*orthogonal, unit_y*projection + unit_z*orthogonal)

    def contact(center, radius, angle):
        return center[0] + radius*cos(angle), center[1] + radius*sin(angle)

    fh, rh = contact(front, front_radius, high), contact(rear, rear_radius, high)
    fl, rl = contact(front, front_radius, low), contact(rear, rear_radius, low)
    straight_length = hypot(rh[0] - fh[0], rh[1] - fh[1])
    rear_length = rear_radius*(high-low)
    length = straight_length*2 + rear_length + front_radius*(tau + low-high)
    points = []
    count = 2 * round(length/.03175)
    for i in range(count):
        t = length * i / count
        if t < straight_length:
            t /= straight_length
            point = (fh[0]*(1-t) + rh[0]*t, fh[1]*(1-t) + rh[1]*t)
        elif t < straight_length + rear_length:
            point = contact(rear, rear_radius, high - (t - straight_length)/rear_radius)
        elif t < straight_length*2 + rear_length:
            t = (t - straight_length - rear_length)/straight_length
            point = (rl[0]*(1-t) + fl[0]*t, rl[1]*(1-t) + fl[1]*t)
        else:
            point = contact(front, front_radius, low - (t - straight_length*2 - rear_length)/front_radius)
        points.append(point)
    return points


def build_chain():
    axle_x = -.145
    front, rear = (.142, .470), (.6975, .310)
    front_radius, rear_radius = .041, .106
    sprocket("42-tooth rear sprocket", (axle_x, *rear), rear_radius, 42)
    sprocket("16-tooth countershaft sprocket", (axle_x, *front), front_radius, 16)
    path = chain_path(front, rear, front_radius, rear_radius)
    # Alternate the inner and outer pair of plates. Profile has flared ends around each pin.
    outline = [(-.057, -.47), (.11, -.55), (.28, -.37), (.72, -.37), (.89, -.55), (1.057, -.47),
               (1.110, -.21), (1.110, .21), (1.057, .47), (.89, .55), (.72, .37), (.28, .37),
               (.11, .55), (-.057, .47), (-.110, .21), (-.110, -.21)]
    for parity, name, material in ((0, "Chain inner links", "engine"), (1, "Chain outer links", "steel")):
        vertices, faces = [], []
        for i in range(parity, len(path), 2):
            a, b = path[i], path[(i + 1) % len(path)]
            dy, dz = b[0] - a[0], b[1] - a[1]
            for side in (-1, 1):
                offset = len(vertices)
                count = len(outline)
                x = axle_x + side * (.0061 + parity*.0020)
                vertices += [(phase, a[0] + u*dy - .58*v*dz, a[1] + u*dz + .58*v*dy)
                             for phase in (x - .0008, x + .0008) for u, v in outline]
                faces += [tuple(reversed(range(offset, offset + count))),
                          tuple(range(offset + count, offset + count*2))]
                faces += [(offset + j, offset + (j+1) % count,
                           offset + (j+1) % count + count, offset + j + count) for j in range(count)]
        mesh(name, vertices, faces, material, CHAIN)
    vertices, faces = [], []
    segments = 8
    for y, z in path:
        offset = len(vertices)
        for phase, radius in ((-.0099, .0022), (-.0074, .0027), (-.0056, .00365),
                              (.0056, .00365), (.0074, .0027), (.0099, .0022)):
            vertices += [(axle_x + phase, y + radius*cos(tau*j/segments),
                          z + radius*sin(tau*j/segments)) for j in range(segments)]
        for level in range(5):
            start = offset + level*segments
            faces += [(start + j, start + (j+1) % segments,
                       start + (j+1) % segments + segments, start + j + segments) for j in range(segments)]
        faces += [tuple(reversed(range(offset, offset + segments))),
                  tuple(range(offset + 5*segments, offset + 6*segments))]
    mesh("Chain rollers and rivet pins", vertices, faces, "alloy", CHAIN, smooth=True)
    side_casting("Countershaft protective cover", [(.103, .517), (.176, .516), (.210, .487),
                (.190, .445), (.164, .437), (.161, .479), (.121, .469), (.099, .476)],
                 -.150, -.173, "frame", CHAIN, .006)
    for y, z in ((.114, .490), (.177, .507)):
        bolt("Countershaft cover screw", (-.173, y, z), (-1, 0, 0), .005, "steel", CHAIN)
    side_casting("Molded upper chain guard", [(.270, .505), (.415, .468), (.557, .442),
                 (.634, .439), (.651, .416), (.612, .409), (.548, .420), (.408, .445), (.263, .480)],
                 -.120, -.163, "satin", CHAIN, .004)
    for y, z in ((.293, .479), (.525, .433)):
        rod("Chain guard stand-off stay", (-.125, y, z - .036), (-.147, y, z),
            .009, "frame", CHAIN)
        bolt("Chain guard screw", (-.163, y, z+.009), (-1, 0, 0), .0045, "steel", CHAIN)


def build_controls():
    for side, label in ((-1, "Shifter"), (1, "Rear brake")):
        side_casting(label + " cast rearset", [(.158, .558), (.255, .534), (.313, .458),
                     (.283, .424), (.194, .446), (.173, .476), (.215, .484)],
                     side*.147, side*.181, "frame", DETAILS, .006)
        side_casting(label + " boot heel guard", [(.240, .551), (.305, .540), (.347, .467),
                     (.303, .453), (.235, .491)], side*.179, side*.185, "engine", DETAILS, .004)
        for y, z in ((.176, .536), (.277, .493)):
            bolt(label + " rearset bolt", (side*.186, y, z), (side, 0, 0), .007, "steel", DETAILS)
        a, b = (side*.176, .253, .437), (side*.307, .249, .435)
        rod(label + " rider footrest pin", (side*.155, .252, .437), a, .016, "frame", DETAILS, bevel=.002)
        rod(label + " knurled rider footrest barrel", a, b, .012, "alloy", DETAILS, vertices=16, bevel=.002)
        for i in range(9):
            x = side * (.196 + i*.0115)
            rod(label + " footrest gripping ring", (x-side*.0016, .251, .436), (x+side*.0016, .251, .436),
                .0134, "steel", DETAILS, vertices=12)
        bolt(label + " footrest feeler", (side*.300, .250, .421), (0, 0, -1), .004, "steel", DETAILS)
        side_casting(label + " curved pedal", [(.270, .426), (.246, .410), (.158, .380), (.084, .382),
                    (.088, .399), (.151, .396), (.233, .428), (.255, .448)],
                     side*.191, side*.201, "alloy", DETAILS, .004)
        rod(label + " toe peg core", (side*.197, .095, .391), (side*.250, .095, .391), .009, "steel",
            DETAILS, bevel=.001)
        rod(label + " toe grip", (side*.204, .095, .391), (side*.248, .095, .391), .011, "rubber",
            DETAILS, vertices=16, bevel=.001)
        for i in range(5):
            x = side * (.207 + i*.008)
            rod(label + " toe grip rib", (x, .095, .391), (x+side*.0015, .095, .391),
                .0118, "rubber", DETAILS, vertices=12)
        rod(label + " passenger hanger leading brace", (side*.104, .427, .827), (side*.161, .530, .627),
            .011, "alloy", DETAILS)
        rod(label + " passenger hanger trailing brace", (side*.101, .597, .864), (side*.161, .530, .627),
            .009, "alloy", DETAILS)
        rod(label + " passenger peg", (side*.151, .530, .627), (side*.227, .549, .636), .010, "engine",
            DETAILS, vertices=16, bevel=.001)
        rod(label + " passenger grip pad", (side*.169, .534, .631), (side*.228, .550, .639), .011, "rubber",
            DETAILS, vertices=16, bevel=.001)
        bolt(label + " passenger peg hinge", (side*.166, .522, .626), (0, -1, 0), .008, "steel", DETAILS)
    rod("Shift linkage rod", (-.189, .217, .423), (-.176, .122, .528), .004, "steel", DETAILS, vertices=10)
    for y, z in ((.217, .423), (.122, .528)):
        bolt("Shift linkage ball end", (-.193, y, z), (-1, 0, 0), .006, "alloy", DETAILS)
    rod("Rear master cylinder", (.171, .236, .476), (.177, .261, .569), .012, "engine", DETAILS, bevel=.002)
    rod("Rear master cylinder push rod", (.173, .230, .441), (.171, .236, .479), .004, "steel", DETAILS)
    tube("Rear brake hydraulic hose", [(.177, .260, .561), (.162, .322, .520), (.151, .447, .438),
                                     (.143, .583, .390), (.123, .665, .385)],
         .004, "rubber", DETAILS)


def build_mechanical():
    prior_objects = set(bpy.data.objects)
    build_frame()
    build_engine()
    build_swingarm()
    build_exhaust()
    build_chain()
    build_controls()
    # The mechanical layouts use chain-side negative X in their section drawings.
    # Reflect that datum into the asset coordinates, where rider-left is positive X.
    lateral_conversion = Matrix.Diagonal((-1, 1, 1, 1))
    for part in set(bpy.data.objects) - prior_objects:
        part.data.transform(lateral_conversion)
        if part.type == 'MESH':
            part.data.flip_normals()
            part.data.update()
