"""Sculpted fairing skins, fuel tank, seats, and exterior trim for the R7."""
from math import cos, sin

from common import bolt, box, mesh, tube

BODY = "R7_Body"
FRONT = "R7_FrontFairing"
TANK = "R7_FuelTank"
SEATS = "R7_Seats"
DETAIL = "R7_Details"

def sample(values, t):
    """Interpolate adjacent model control points with endpoint-safe cubics."""
    position = max(0, min(1, t)) * (len(values) - 1)
    index = min(int(position), len(values) - 2)
    f = position - index
    p0 = values[max(index - 1, 0)]
    p1 = values[index]
    p2 = values[index + 1]
    p3 = values[min(index + 2, len(values) - 1)]
    return tuple(
        b + 0.5 * f * ((c - a) + f * ((2*a - 5*b + 4*c - d) + f * (3*b - a - 3*c + d)))
        for a, b, c, d in zip(p0, p1, p2, p3)
    )

def shell(name, fn, nu, nv, material, collection, step, normal_axis=0, normal_sign=1,
          omit=None):
    """Give a sampled panel finite thickness, with a closed welded perimeter."""
    front = [fn(i / nu, j / nv) for i in range(nu + 1) for j in range(nv + 1)]
    width = nv + 1
    count = len(front)
    back = [tuple(c + d for c, d in zip(p, step)) for p in front]
    faces = [(i * width + j, (i + 1) * width + j, (i + 1) * width + j + 1, i * width + j + 1)
             for i in range(nu) for j in range(nv) if omit is None or not omit(i, j)]
    ia, ib, ic, _ = faces[len(faces) // 2]
    a, b, c = (front[i] for i in (ia, ib, ic))
    p = [(b[i] - a[i]) for i in range(3)]
    q = [(c[i] - b[i]) for i in range(3)]
    ax1, ax2 = (normal_axis + 1) % 3, (normal_axis + 2) % 3
    if (p[ax1] * q[ax2] - p[ax2] * q[ax1]) * normal_sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    edges = {}
    for face in faces:
        for a, b in zip(face, face[1:] + face[:1]):
            key = tuple(sorted((a, b)))
            if key in edges:
                del edges[key]
            else:
                edges[key] = (a, b)
    faces.extend([tuple(count + i for i in reversed(f)) for f in faces[:]])
    smooth_faces = len(faces)
    faces.extend([(b, a, a + count, b + count) for a, b in edges.values()])
    vertices = front + back
    if omit is not None:
        used = sorted({vertex for face in faces for vertex in face})
        indices = {old: new for new, old in enumerate(used)}
        vertices = [vertices[i] for i in used]
        faces = [tuple(indices[i] for i in face) for face in faces]
    result = mesh(name, vertices, faces, material, collection, smooth=True)
    for face in result.data.polygons[smooth_faces:]:
        face.use_smooth = False
    return result

def patch(name, rows, material, collection, side, nu=20, nv=10, thickness=.005, axis=0):
    def point(u, v):
        x, y, z = sample([sample(row, u) for row in rows], v)
        return (x * side, y, z)
    offset = (-thickness * side, 0, 0) if axis == 0 else (0, 0, -thickness)
    return shell(name, point, nu, nv, material, collection, offset, axis, side if axis == 0 else 1)

# Sections hold the fore-aft station, half width, spine, shoulder, and lower contour.
TANK_SECTIONS = [
    (-.455, .036, .907, .897, .844),
    (-.397, .087, 1.010, .971, .810),
    (-.325, .155, 1.073, 1.031, .786),
    (-.236, .183, 1.095, 1.052, .778),
    (-.163, .187, 1.097, 1.046, .775),
    (-.074, .164, 1.070, 1.016, .774),
    (.008, .128, 1.020, .958, .781),
    (.078, .110, .947, .897, .793),
    (.144, .087, .861, .841, .802),
    (.161, .069, .829, .822, .806),
]

RIDER_SECTIONS = [
    (.109, .074, .831, .830, .799),
    (.165, .090, .829, .825, .788),
    (.237, .114, .825, .816, .783),
    (.334, .140, .829, .820, .785),
    (.421, .147, .842, .834, .796),
    (.505, .135, .869, .861, .823),
    (.559, .106, .899, .882, .848),
]

PASSENGER_SECTIONS = [
    (.527, .071, .942, .935, .901),
    (.588, .105, .968, .961, .923),
    (.665, .111, .975, .968, .934),
    (.738, .097, .979, .972, .944),
    (.796, .072, .977, .969, .948),
    (.832, .051, .971, .962, .945),
]

TAIL_SECTIONS = [
    (.290, .079, .797, .778, .749),
    (.417, .145, .815, .795, .759),
    (.492, .146, .863, .831, .774),
    (.571, .145, .925, .895, .801),
    (.667, .136, .950, .926, .844),
    (.767, .122, .967, .950, .881),
    (.858, .102, .977, .963, .910),
    (.925, .081, .978, .969, .929),
    (.956, .061, .972, .965, .945),
]

def cross_section(station, tank=False):
    y, width, top, shoulder, low = station
    span = top - low
    if tank:
        positive = [(0, top), (.33, top-.002), (.64, top-.012), (.86, shoulder),
                    (.992, shoulder-.12*span), (1, low+.42*span),
                    (.84, low+.12*span), (.62, low+.02*span), (0, low)]
    else:
        positive = [(0, top), (.36, top-.001), (.68, top-.003), (.91, shoulder),
                    (1, shoulder-.15*span), (.96, low+.22*span),
                    (.81, low+.035*span), (0, low)]
    points = [(x * width, y, z) for x, z in positive]
    points.extend([(-x * width, y, z) for x, z in reversed(positive[1:-1])])
    return points

def loft(name, controls, material, collection, tank=False):
    intervals = 4 * (len(controls) - 1)
    rings = [cross_section(sample(controls, i / intervals), tank) for i in range(intervals + 1)]
    # Interpolate around the closed transom ring, including the center and bottom.
    vertices = []
    for ring in rings:
        surround = ring[-1:] + ring + ring[:2]
        span = len(ring) + 2
        vertices.extend([sample(surround, (1 + j * .5) / span) for j in range(2 * len(ring))])
    width = 2 * len(rings[0])
    faces = [(i * width + j, i * width + (j + 1) % width,
              (i + 1) * width + (j + 1) % width, (i + 1) * width + j)
             for i in range(intervals) for j in range(width)]
    faces += [tuple(reversed(range(width))), tuple(intervals * width + j for j in range(width))]
    return mesh(name, vertices, faces, material, collection, smooth=True)

def tank_surface(x, y):
    """Fuel tank upper surface for the cap, inlays, and Yamaha emblems."""
    lo, hi = 0., 1.
    for _ in range(16):
        mid = (lo + hi) / 2
        if sample(TANK_SECTIONS, mid)[0] < y:
            lo = mid
        else:
            hi = mid
    ring = cross_section(sample(TANK_SECTIONS, (lo + hi) / 2), True)
    lo, hi = 0., .31
    for _ in range(16):
        mid = (lo + hi) / 2
        if sample(ring, mid)[0] < abs(x):
            lo = mid
        else:
            hi = mid
    return sample(ring, (lo + hi) / 2)[2]

# The upper cheek flows backward and downward between the nose and tank.
CHEEK = [
    [(.109,-.939,.765), (.191,-.807,.815), (.224,-.637,.868), (.193,-.444,.868), (.142,-.302,.827), (.127,-.215,.785)],
    [(.132,-.896,.730), (.216,-.791,.775), (.240,-.616,.814), (.233,-.432,.799), (.225,-.280,.771), (.151,-.208,.747)],
    [(.159,-.854,.705), (.210,-.750,.738), (.237,-.595,.775), (.252,-.419,.748), (.240,-.274,.729), (.174,-.196,.718)],
]
# Each row is (outboard width, longitudinal position, height) from nose to engine.
SIDE = [
    [(.159,-.840,.702), (.210,-.731,.742), (.235,-.592,.771), (.247,-.425,.746), (.234,-.267,.724), (.187,-.111,.699)],
    [(.171,-.812,.680), (.223,-.699,.714), (.245,-.551,.738), (.253,-.409,.711), (.241,-.274,.690), (.183,-.098,.663)],
    [(.169,-.761,.622), (.217,-.662,.650), (.239,-.535,.658), (.249,-.402,.658), (.239,-.280,.644), (.178,-.121,.611)],
    [(.159,-.693,.525), (.209,-.598,.557), (.218,-.496,.556), (.218,-.385,.559), (.198,-.306,.539), (.145,-.191,.515)],
]

def fairing_surface(rows, u, v):
    return sample([sample(row, u) for row in rows], v)

def side_surface(y, z):
    """Outboard fairing skin, used for the painted graphics and shell badges."""
    if z >= sample(SIDE[0], .64)[2]:
        rows = CHEEK
    else:
        rows = SIDE
    def get(u, v):
        return fairing_surface(rows, u, v)
    # Solve the ruled grid locally, where both station axes are monotonic.
    lo, hi = 0., 1.
    offset = 0.
    for _ in range(14):
        v = (lo + hi) / 2
        a, b = 0., 1.
        for _ in range(14):
            offset = (a + b) / 2
            if get(offset, v)[1] < y:
                a = offset
            else:
                b = offset
        if get(offset, v)[2] > z:
            lo = v
        else:
            hi = v
    return get(offset, (lo + hi) / 2)[0]

def main_fairing(side, label):
    def aperture(u):
        progress = max(0., min((u - 10/24) / (9/24), 1.))
        return .46 + .19*progress, .56 + .31*progress

    def facepoint(u, v):
        upper, lower = aperture(u)
        a = min(int(v * 3), 2)
        vs = (0, upper, lower, 1)
        raw_v = vs[a] + (v * 3 - a) * (vs[a+1] - vs[a])
        x, y, z = fairing_surface(SIDE, u, raw_v)
        return side * x, y, z

    shell(f"{label} main fairing • convex pierced skin", facepoint, 24, 12,
          "paint", BODY, (-side*.006, 0, 0), 0, side,
          omit=lambda i, j: 10 <= i < 19 and 4 <= j < 8)

    def duct(u, v):
        raw_u = (10 + 9*u) / 24
        raw_v = (1 + v) / 3
        x, y, z = facepoint(raw_u, raw_v)
        # Retain a crisp aperture and roll down into a physically recessed duct.
        distance = min(u*3, v*4, (1-u)*3, (1-v)*4, 1)
        return x - side * (.005 + .026*distance), y, z

    shell(f"{label} side vent • molded duct interior", duct, 18, 10,
          "black", BODY, (-side*.0025, 0, 0), 0, side)
    for u in (.58, .79):
        endpoints = [duct(u, v) for v in (.08, .38, .64, .92)]
        points = [(x + side*.0055, y, z) for x, y, z in endpoints]
        tube(f"{label} side vent • recessed air guide", points, .0015, "satin", BODY)

BROW = [
    [(.016,-.980,.838), (.039,-.950,.866), (.081,-.907,.905), (.121,-.829,.949), (.146,-.736,.989), (.154,-.690,.987)],
    [(.035,-.968,.824), (.079,-.935,.851), (.123,-.880,.886), (.159,-.809,.923), (.182,-.736,.950), (.175,-.680,.950)],
    [(.056,-.941,.795), (.098,-.889,.838), (.151,-.841,.850), (.182,-.791,.868), (.200,-.722,.894), (.186,-.674,.911)],
]
DRL_LIP = [
    [(.045,-.948,.780), (.073,-.920,.782), (.111,-.878,.805), (.156,-.827,.824), (.190,-.781,.843), (.208,-.720,.875)],
    [(.047,-.954,.754), (.089,-.933,.749), (.136,-.884,.753), (.179,-.816,.775), (.209,-.759,.796), (.223,-.701,.832)],
    [(.047,-.937,.736), (.082,-.918,.731), (.133,-.852,.732), (.180,-.789,.756), (.214,-.731,.779), (.227,-.672,.809)],
]
BELLY = [
    [(.160,-.696,.528), (.202,-.572,.553), (.208,-.480,.535), (.199,-.348,.514), (.166,-.217,.482), (.149,-.113,.460)],
    [(.141,-.641,.459), (.189,-.562,.449), (.206,-.465,.418), (.214,-.310,.391), (.212,-.144,.367), (.166,.083,.358)],
    [(.127,-.584,.348), (.161,-.518,.329), (.185,-.445,.320), (.193,-.291,.303), (.193,-.102,.301), (.151,.116,.323)],
    [(.111,-.548,.295), (.147,-.488,.278), (.162,-.387,.270), (.172,-.261,.268), (.166,-.082,.272), (.126,.083,.288)],
]
WING = [
    [(.173,-.320,.775), (.190,-.226,.791), (.160,-.106,.798), (.141,.027,.812), (.108,.110,.809)],
    [(.177,-.312,.753), (.185,-.207,.756), (.162,-.099,.764), (.145,.027,.766), (.112,.115,.777)],
    [(.157,-.301,.729), (.155,-.198,.721), (.146,-.089,.729), (.128,.025,.723), (.110,.108,.753)],
]
SEAT_SIDE = [
    [(.084,.100,.814), (.100,.199,.813), (.137,.311,.807), (.148,.425,.820), (.144,.501,.861)],
    [(.112,.095,.783), (.128,.186,.779), (.143,.306,.785), (.146,.407,.795), (.140,.482,.822)],
    [(.095,.088,.737), (.106,.170,.718), (.129,.292,.731), (.129,.391,.744), (.123,.452,.773)],
]
TAIL_SCALLOP = [
    [(.140,.495,.857), (.150,.588,.922), (.138,.684,.950), (.112,.791,.973), (.063,.925,.973)],
    [(.156,.515,.835), (.161,.602,.879), (.138,.703,.911), (.101,.804,.939), (.072,.929,.958)],
    [(.151,.553,.815), (.146,.625,.837), (.125,.726,.881), (.086,.826,.918), (.064,.930,.949)],
]
SCREEN_STATIONS = [
    # (half-width, center Y, center Z, rearward sweep, edge height delta)
    (.144, -.855, .894, .132, .084),
    (.150, -.805, .953, .115, .043),
    (.150, -.742, 1.027, .072, .010),
    (.143, -.661, 1.103, .043, -.023),
    (.135, -.601, 1.160, .046, -.073),
]

def windscreen(u, v):
    w, y, z, sweep, drop = sample(SCREEN_STATIONS, u)
    p = v * 2 - 1
    return p*w, y + sweep * abs(p)**1.85, z + drop * abs(p)**1.7

def front_fender(u, v):
    angle = -1.04 + 2.16 * u
    cross = v * 2 - 1
    # A narrowed tail clears the fork sliders and inner brake lines.
    width = sample([(.047,), (.071,), (.076,), (.079,), (.063,), (.065,)], u)[0]
    radius = .329 - .029 * cross**2 - .006 * abs(2*u-1)**2
    return cross * width, -.6975 + radius * sin(angle), .300 + radius * cos(angle)

def hugger(u, v):
    angle = -1.31 + 1.74 * u
    cross = 2*v - 1
    radius = .328 - .024 * cross**2
    return cross*(.082 - .008*u), .6975 + radius*sin(angle), .310 + radius*cos(angle)

def build_body():
    loft("Fuel tank • formed steel shell", TANK_SECTIONS, "paint", TANK, True)
    loft("Tail cowl • upswept seat unit", TAIL_SECTIONS, "paint", BODY)
    loft("Rider saddle • contoured grained vinyl", RIDER_SECTIONS, "seat", SEATS)
    loft("Pillion pad • tapered grained vinyl", PASSENGER_SECTIONS, "seat", SEATS)
    def nose_spine(u, v):
        cross = v * 2 - 1
        y, z, width = sample([(-.983,.835,.018),(-.948,.854,.045),
                              (-.906,.877,.077),(-.848,.902,.102)], u)
        return width*cross, y + .009*cross**2, z - .0045*cross**2

    shell("Nose spine • sculpted center bridge", nose_spine, 16, 14, "paint",
          FRONT, (0, 0, -.0045), 2)
    shell("Windscreen • curved smoked polycarbonate", windscreen, 26, 32, "smoke",
          FRONT, (0, .0023, -.0018), 1, -1)
    tube("Windscreen • polished upper edge", [windscreen(1, i / 12) for i in range(13)],
         .0009, "smoke", FRONT)
    shell("Front mudguard • curved tire crown", front_fender, 36, 16, "paint",
          FRONT, (0, 0, -.005), 2)
    shell("Rear hugger • close-fitting tire shield", hugger, 22, 14, "satin",
          BODY, (0, 0, -.004), 2)

    for side, side_name in ((1, "Left"), (-1, "Right")):
        def fairing(name, rows, surface="paint", collection=BODY, **options):
            return patch(f"{side_name} {name}", rows, surface, collection, side, **options)

        fairing("nose brow • swept upper surfacing", BROW, collection=FRONT, axis=2)
        fairing("DRL lower lip • sharp intake contour", DRL_LIP, collection=FRONT)
        fairing("upper cheek • aerodynamic crease", CHEEK, collection=FRONT)
        main_fairing(side, side_name)
        fairing("lower cowl • sculpted belly shield", BELLY, "paint")
        fairing("lower cowl • tapered diagonal ridge", [
            [(.198,-.592,.489), (.211,-.528,.467), (.216,-.458,.434), (.219,-.371,.404), (.215,-.287,.392)],
            [(.200,-.568,.460), (.213,-.503,.430), (.221,-.443,.404), (.220,-.371,.381), (.211,-.315,.380)],
            [(.176,-.536,.402), (.193,-.480,.390), (.201,-.426,.373), (.207,-.367,.368), (.204,-.316,.367)],
        ], "paint_alt", nu=16, nv=6)
        fairing("upper tank-side infil", WING, "satin")
        fairing("saddle side cover", SEAT_SIDE, "satin")
        fairing("tail side panel • scalloped shoulder", TAIL_SCALLOP, "paint_alt")
        fairing("chin spoiler • curved intake edge", [
            [(.036,-.952,.742), (.096,-.936,.736), (.147,-.877,.728), (.185,-.816,.720), (.211,-.719,.742)],
            [(.037,-.940,.720), (.094,-.922,.715), (.145,-.860,.704), (.180,-.786,.696), (.204,-.713,.723)],
            [(.044,-.913,.710), (.094,-.893,.705), (.142,-.843,.693), (.175,-.767,.683), (.196,-.694,.707)],
        ], "satin", FRONT)
        fairing("forward body intake • recessed duct", [
            [(.018,-.935,.820), (.057,-.919,.813), (.096,-.889,.838), (.144,-.831,.862), (.190,-.770,.905)],
            [(.019,-.929,.781), (.058,-.907,.778), (.093,-.868,.790), (.148,-.809,.815), (.195,-.752,.861)],
            [(.019,-.914,.748), (.062,-.895,.749), (.097,-.853,.758), (.147,-.784,.779), (.193,-.725,.827)],
        ], "black", FRONT, nu=14, nv=6)
        fairing("side air exit • inside of open blade", [
            [(.218,-.274,.670), (.195,-.190,.697), (.157,-.087,.700), (.148,-.038,.667)],
            [(.215,-.278,.646), (.181,-.192,.643), (.154,-.109,.640), (.148,-.057,.612)],
            [(.202,-.313,.552), (.170,-.213,.560), (.142,-.150,.568), (.132,-.112,.558)],
        ], "black")
        fairing("side air exit • leading slash", [
            [(.232,-.307,.719), (.246,-.275,.718), (.240,-.232,.699), (.217,-.196,.682)],
            [(.231,-.286,.686), (.240,-.249,.682), (.232,-.211,.667), (.207,-.179,.656)],
            [(.219,-.251,.628), (.220,-.225,.625), (.215,-.186,.615), (.196,-.162,.610)],
            [(.206,-.233,.586), (.209,-.215,.584), (.194,-.186,.582), (.183,-.168,.575)],
        ], "paint_alt")
        fairing("lower air exit • recessed fin", [
            [(.176,-.528,.468), (.202,-.424,.490), (.202,-.350,.484), (.172,-.268,.464)],
            [(.172,-.510,.444), (.193,-.430,.431), (.192,-.347,.427), (.165,-.269,.438)],
        ], "matte")
        fairing("belly splitter • raised lower edge", [
            [(.146,-.553,.328), (.176,-.461,.313), (.199,-.339,.325), (.209,-.207,.330), (.200,-.037,.319), (.155,.123,.336)],
            [(.136,-.553,.306), (.165,-.470,.288), (.190,-.347,.286), (.199,-.208,.293), (.188,-.033,.290), (.140,.122,.320)],
        ], "paint_alt")
        fairing("mudguard mount • tapered fork shoulder", [
            [(.060,-.753,.588), (.074,-.693,.601), (.078,-.619,.590), (.064,-.536,.563)],
            [(.063,-.743,.559), (.079,-.676,.545), (.088,-.612,.487), (.068,-.555,.533)],
            [(.059,-.716,.562), (.076,-.663,.511), (.093,-.610,.429), (.076,-.565,.506)],
        ], "satin", FRONT, nu=18)
        fairing("undertray • closed pillion silhouette", [
            [(.093,.422,.779), (.113,.564,.806), (.095,.693,.864), (.069,.830,.906), (.058,.950,.949)],
            [(.070,.430,.751), (.078,.555,.783), (.062,.687,.844), (.050,.813,.890), (.053,.942,.944)],
            [(.002,.430,.752), (.002,.553,.780), (.002,.687,.840), (.002,.813,.887), (.002,.942,.940)],
        ], "matte", BODY, axis=2)
        fairing("rear eliminator arm • tapered structural web", [
            [(.044,.764,.895), (.056,.834,.867), (.058,.902,.813), (.052,.962,.758), (.041,1.002,.706)],
            [(.018,.788,.870), (.028,.850,.833), (.038,.917,.776), (.027,.964,.723), (.026,1.007,.692)],
        ], "satin", BODY, nu=15, nv=4)
        tube(f"{side_name} tank lower hem", [(side*x, y, z) for x, y, z in [
             (.051,-.437,.843),(.112,-.345,.803),(.163,-.232,.796),
             (.159,-.104,.791),(.124,.001,.793),(.103,.082,.804)]], .0017, "satin", TANK)
        tube(f"{side_name} rider seat micro piping", [(side*x, y, z) for x, y, z in [
             (.071,.118,.814),(.086,.160,.810),(.113,.238,.804),(.141,.339,.809),
             (.149,.425,.822),(.134,.501,.851),(.106,.549,.874)]], .0011, "matte", SEATS)
        for index, (x, y, z) in enumerate([
             (.190,-.688,.906), (.243,-.597,.777), (.241,-.294,.726), (.218,-.315,.396),
             (.200,-.135,.335), (.146,.426,.800), (.148,.571,.848),
        ]):
            bolt(f"{side_name} recessed body screw {index + 1:02}", (side*x, y, z),
                 (side, 0, .12), .0042, "engine", DETAIL, depth=.0024)
        bolt(f"{side_name} mudguard retaining bolt", (side*.090, -.615, .472),
             (side, 0, .12), .0042, "engine", DETAIL, depth=.0024)
    box("Rear eliminator • transverse signal support", (0, .984, .724), (.172, .036, .025),
        "matte", BODY, bevel=.005)
    box("Rear eliminator • plate mounting saddle", (0, 1.004, .706), (.098, .093, .024),
        "satin", BODY, bevel=.005, rotation=(-.23, 0, 0))
    box("Tail plate holder • polymer base", (0, 1.022, .658), (.104, .027, .137),
        "satin", BODY, bevel=.006, rotation=(-.40, 0, 0))
    box("License plate • charcoal blank", (0, 1.038, .652), (.103, .008, .071),
        "matte", DETAIL, bevel=.003, rotation=(-.40, 0, 0))
    for side in (-1, 1):
        bolt(f"Plate holder retaining screw {side:+}", (side*.041, 1.049, .678),
             (0, 1, -.33), .0035, "steel", DETAIL, depth=.0025)
