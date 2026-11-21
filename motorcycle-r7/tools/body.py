"""Sculpted fairing skins, fuel tank, seats, and exterior trim for the R7."""
from math import cos, exp, sin

from mathutils import Vector

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
          omit=None, triangulate=False):
    """Give a sampled panel finite thickness, with a closed welded perimeter."""
    samples = [(i / nu, j / nv) for i in range(nu + 1) for j in range(nv + 1)]
    front = [fn(u, v) for u, v in samples]
    width = nv + 1
    count = len(front)
    offsets = [step(u, v) for u, v in samples] if callable(step) else [step] * count
    back = [tuple(c + d for c, d in zip(point, offset)) for point, offset in zip(front, offsets)]
    faces = [(i * width + j, (i + 1) * width + j, (i + 1) * width + j + 1, i * width + j + 1)
             for i in range(nu) for j in range(nv) if omit is None or not omit(i, j)]
    ia, ib, ic, _ = faces[len(faces) // 2]
    a, b, c = (front[i] for i in (ia, ib, ic))
    p = [(b[i] - a[i]) for i in range(3)]
    q = [(c[i] - b[i]) for i in range(3)]
    ax1, ax2 = (normal_axis + 1) % 3, (normal_axis + 2) % 3
    if (p[ax1] * q[ax2] - p[ax2] * q[ax1]) * normal_sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    if triangulate:
        faces = [triangle for a, b, c, d in faces for triangle in ((a, b, c), (a, c, d))]
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

# Tank stations define Y, maximum half-width, crown, shoulder, lower hem, and knee width ratio.
TANK_SECTIONS = [
    (-.439, .045, .905, .893, .847, .91),
    (-.400, .102, .982, .946, .812, .89),
    (-.350, .144, 1.030, .983, .794, .85),
    (-.289, .169, 1.064, 1.006, .786, .80),
    (-.254, .176, 1.067, 1.003, .784, .77),
    (-.205, .175, 1.067, .997, .784, .71),
    (-.157, .168, 1.0665, .979, .782, .66),
    (-.110, .156, 1.049, .952, .783, .65),
    (-.055, .138, 1.014, .912, .785, .67),
    (.013, .115, .951, .866, .787, .74),
    (.076, .088, .882, .832, .785, .86),
    (.115, .071, .840, .826, .788, .94),
    (.129, .066, .828, .820, .792, .96),
]

RIDER_SECTIONS = [
    (.126, .067, .828, .825, .794),
    (.164, .085, .826, .823, .786),
    (.237, .111, .824, .815, .783),
    (.334, .139, .829, .819, .785),
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
    y, width, top, shoulder, low = station[:5]
    span = top - low
    if tank:
        knee = station[5]
        positive = [(0, top), (.30, top-.001), (.58, top-.009),
                    (.83, top - .51*(top-shoulder)), (.97, shoulder+.003),
                    (1, shoulder-.058*span), (.96, shoulder-.15*span),
                    (.82*knee+.18, low+.44*span), (knee, low+.18*span),
                    (.91*knee, low+.047*span), (.44, low+.003), (0, low)]
    else:
        positive = [(0, top), (.36, top-.001), (.68, top-.003), (.91, shoulder),
                    (1, shoulder-.15*span), (.96, low+.22*span),
                    (.81, low+.035*span), (0, low)]
    points = [(x * width, y, z) for x, z in positive]
    points.extend([(-x * width, y, z) for x, z in reversed(positive[1:-1])])
    return points

def tank_steering_relief(point):
    """Recess the tank's nose around the steering head and upper bridge."""
    x, y, z = point
    width_fade = min(max((.142 - abs(x)) / .105, 0), 1)
    height_fade = min(max((1.042-z)/.065, 0), 1)
    forward_fade = max((-.286-y)/.153, 0)
    return x, y + .088*width_fade*height_fade*forward_fade, z


def loft(name, controls, material, collection, tank=False):
    intervals = 4 * (len(controls) - 1)
    rings = [cross_section(sample(controls, i / intervals), tank) for i in range(intervals + 1)]
    # Interpolate around the closed transom ring, including the center and bottom.
    vertices = []
    for ring in rings:
        surround = ring[-1:] + ring + ring[:2]
        span = len(ring) + 2
        vertices.extend([sample(surround, (1 + j * .5) / span) for j in range(2 * len(ring))])
    if tank:
        vertices = [tank_steering_relief(point) for point in vertices]
    width = 2 * len(rings[0])
    faces = [(i * width + j, i * width + (j + 1) % width,
              (i + 1) * width + (j + 1) % width, (i + 1) * width + j)
             for i in range(intervals) for j in range(width)]
    faces += [tuple(reversed(range(width))), tuple(intervals * width + j for j in range(width))]
    return mesh(name, vertices, faces, material, collection, smooth=True)

def row_at_y(row, y):
    """Evaluate a longitudinal control curve at a given Y."""
    lo, hi = 0., 1.
    for _ in range(20):
        mid = (lo + hi) / 2
        if sample(row, mid)[1] < y:
            lo = mid
        else:
            hi = mid
    return sample(row, (lo + hi) / 2)


def tank_ring(y):
    lo, hi = 0., 1.
    for _ in range(20):
        mid = (lo + hi) / 2
        if sample(TANK_SECTIONS, mid)[0] < y:
            lo = mid
        else:
            hi = mid
    return cross_section(sample(TANK_SECTIONS, (lo + hi) / 2), True)


def tank_surface(x, y):
    """Upper tank surface for centered cap and shoulder fixtures."""
    ring = tank_ring(y)
    lo, hi = 0., 5/21
    for _ in range(18):
        mid = (lo + hi) / 2
        if sample(ring, mid)[0] < abs(x):
            lo = mid
        else:
            hi = mid
    return sample(ring, (lo + hi) / 2)[2]


def tank_side_surface(y, z):
    """Outboard tank position between the shoulder and lower hem."""
    ring = tank_ring(y)
    lo, hi = 2/21, 11/21
    for _ in range(18):
        mid = (lo + hi) / 2
        if sample(ring, mid)[2] > z:
            lo = mid
        else:
            hi = mid
    return sample(ring, (lo + hi) / 2)[0]


# The upper cheek flows backward and downward between the nose and tank.
CHEEK = [
    [(.225,-.669,.929), (.210,-.576,.920), (.199,-.485,.884), (.180,-.411,.854), (.149,-.300,.819), (.127,-.215,.785)],
    [(.225,-.675,.850), (.229,-.579,.847), (.228,-.487,.827), (.229,-.411,.805), (.211,-.280,.771), (.151,-.208,.747)],
    [(.225,-.651,.773), (.236,-.570,.770), (.247,-.489,.758), (.252,-.419,.748), (.240,-.274,.729), (.174,-.196,.718)],
]
# Rows are (half-width, Y, Z) stations from the nose toward the engine.
SIDE = [
    [(.161,-.851,.704), (.208,-.748,.739), (.228,-.651,.763), (.249,-.455,.748),
     (.244,-.315,.733), (.217,-.222,.716), (.180,-.115,.684)],
    [(.173,-.814,.676), (.219,-.711,.702), (.241,-.611,.730), (.253,-.446,.724),
     (.247,-.329,.705), (.225,-.228,.678), (.186,-.103,.642)],
    [(.166,-.770,.611), (.213,-.661,.648), (.234,-.568,.661), (.238,-.419,.656),
     (.233,-.318,.639), (.214,-.223,.612), (.176,-.115,.579)],
    [(.156,-.703,.526), (.201,-.614,.545), (.216,-.511,.554), (.222,-.406,.546),
     (.210,-.311,.532), (.196,-.240,.503), (.201,-.150,.477)],
]


def side_top_row():
    """Index the row to the neighboring upper shell with a backed seam."""
    row = []
    rail = CHEEK[-1]
    for x, y, z in SIDE[0]:
        if y < rail[0][1] - .004:
            x, _, z = nose_lower_edge(y)
            row.append((x - .0015, y, z - .003))
        elif y <= rail[-1][1]:
            x, _, z = row_at_y(rail, y)
            row.append((x - .0015, y, z - .003))
        else:
            row.append((x, y, z))
    return row


def fairing_surface(rows, u, v):
    return sample([sample(row, u) for row in rows], v)

def cheek_surface(u, v):
    base = fairing_surface(CHEEK, u, v)
    lead = fairing_surface(CHEEK, 0, v)
    interface = nose_point(1, 1-v)
    blend = max(0., 1-u*5)**2
    return tuple(a + (c-b)*blend for a, b, c in zip(base, lead, interface))

def width_at_y_z(rows, y, z):
    lo, hi = 0., 1.
    for _ in range(17):
        v = (lo + hi) / 2
        result = row_at_y([sample([row[i] for row in rows], v) for i in range(len(rows[0]))], y)
        if result[2] > z:
            lo = v
        else:
            hi = v
    return result[0]


def side_surface(y, z):
    """Outboard fairing skin, used for the painted graphics and shell badges."""
    return width_at_y_z([side_top_row(), *SIDE[1:]], y, z)


def normal_thickness(point, side, thickness):
    """Offset a deeply sculpted side surface by its local inward normal."""
    def offset(u, v):
        epsilon = .0005
        du = Vector(point(min(1, u + epsilon), v)) - Vector(point(max(0, u - epsilon), v))
        dv = Vector(point(u, min(1, v + epsilon))) - Vector(point(u, max(0, v - epsilon)))
        return du.cross(dv).normalized() * (side * thickness)
    return offset


def main_fairing(side, label):
    rows = [side_top_row(), *SIDE[1:]]

    def aperture(u):
        progress = max(0., min((u - 10/32) / (15/32), 1.))
        return .53 + .12*progress, .63 + .24*progress

    def facepoint(u, v):
        upper, lower = aperture(u)
        band = min(int(v * 3), 2)
        limits = (0, upper, lower, 1)
        raw_v = limits[band] + (v * 3 - band) * (limits[band+1] - limits[band])
        x, y, z = fairing_surface(rows, u, raw_v)
        return side * x, y, z

    shell(f"{label} main fairing • convex pierced skin", facepoint, 32, 18,
          "paint_alt", BODY, (-side*.004, 0, 0), 0, side,
          omit=lambda i, j: 10 <= i < 25 and 6 <= j < 12)

    def duct(u, v):
        station = (10 + 15*u) / 32
        upper = facepoint(station, 1/3)
        lower = facepoint(station, 2/3)
        x, y, z = (a + (b-a)*v for a, b in zip(upper, lower))
        def ramp(value):
            value = min(4*value, 1)
            return value**2 * (3 - 2*value)
        inset = ramp(u) * ramp(1-u) * ramp(v) * ramp(1-v)
        return x - side * (.0035 + .023*inset), y, z

    shell(f"{label} side vent • molded duct interior", duct, 15, 12,
          "black", BODY, (-side*.002, 0, 0), 0, side, triangulate=True)
    for u in (.68, .84):
        points = [duct(u, v) for v in (.10, .32, .59, .83)]
        tube(f"{label} side vent • recessed air guide",
             [(x + side*.0017, y, z) for x, y, z in points], .0018, "satin", BODY)

    def joint(u, v):
        x, y, z = sample(rows[0], u)
        return side*(x - .0045), y, z + .012*v - .004

    shell(f"{label} upper fairing • internal seam return", joint, 30, 2,
          "matte", BODY, (-side*.002, 0, 0), 0, side)


BELLY = [
    [(x - .0015, y + .0015, z - .0035) for x, y, z in SIDE[-1]],
    [(.143,-.666,.457), (.191,-.589,.476), (.207,-.493,.470), (.219,-.375,.444),
     (.216,-.233,.402), (.201,-.068,.342), (.196,.090,.326)],
    [(.139,-.629,.413), (.179,-.550,.428), (.199,-.459,.407), (.211,-.357,.381),
     (.209,-.208,.359), (.194,-.074,.320), (.176,.114,.307)],
    [(.112,-.564,.300), (.153,-.504,.285), (.177,-.413,.276), (.191,-.304,.274),
     (.199,-.191,.281), (.183,-.035,.287), (.142,.114,.293)],
    [(.099,-.543,.294), (.140,-.480,.276), (.164,-.404,.264), (.176,-.305,.260),
     (.181,-.190,.269), (.161,-.051,.277), (.132,.102,.289)],
]

WING = [
    [(.144,-.315,.812), (.143,-.231,.813), (.113,-.119,.801), (.091,.015,.801), (.071,.136,.807)],
    [(.170,-.308,.765), (.160,-.202,.770), (.134,-.109,.764), (.113,.022,.763), (.094,.139,.779)],
    [(.163,-.300,.724), (.151,-.196,.721), (.131,-.099,.729), (.112,.028,.730), (.102,.134,.748)],
]

SEAT_SIDE = [
    [(.071,.136,.805), (.094,.201,.804), (.135,.316,.803), (.147,.425,.816), (.143,.501,.857)],
    [(.094,.139,.777), (.118,.192,.777), (.137,.310,.783), (.146,.404,.792), (.140,.482,.820)],
    [(.102,.135,.747), (.115,.174,.724), (.129,.289,.729), (.129,.391,.742), (.123,.452,.771)],
]

TANK_MOUNTS = [
    (-.327, .090, .783, .778, .744),
    (-.210, .107, .780, .776, .760),
    (-.102, .095, .778, .774, .750),
    (.032, .079, .781, .775, .742),
    (.132, .064, .786, .782, .754),
]

TAIL_SCALLOP = [
    [(.140,.495,.857), (.150,.588,.922), (.138,.684,.950), (.112,.791,.973), (.063,.925,.973)],
    [(.156,.515,.835), (.161,.602,.879), (.138,.703,.911), (.101,.804,.939), (.072,.929,.958)],
    [(.151,.553,.815), (.146,.625,.837), (.125,.726,.881), (.086,.826,.918), (.064,.930,.949)],
]
# Lateral stations on one side of the molded nose. Both sides share the same
# control surface, so the projector web and lamp edges are exactly symmetric.
NOSE_STATIONS = (0, .125, .1875, .25, .375, .50, .625, .75, .84375, 1)
NOSE_WIDTHS = (0, .027, .041, .057, .086, .116, .146, .173, .191, .225)
NOSE_RAILS = (
    # Lower return above the fender.
    ((-.943,.723), (-.944,.718), (-.946,.722), (-.939,.718), (-.914,.721),
     (-.876,.728), (-.829,.744), (-.785,.763), (-.740,.781), (-.651,.773)),
    # Lower lip of the projector mouth and DRL channels.
    ((-.955,.747), (-.954,.748), (-.951,.759), (-.936,.775), (-.906,.798),
     (-.872,.808), (-.837,.820), (-.801,.836), (-.769,.857), (-.665,.807)),
    # Upper lip; the projector is recessed behind the V-shaped opening.
    ((-.968,.817), (-.966,.816), (-.959,.807), (-.937,.782), (-.908,.812),
     (-.873,.822), (-.838,.834), (-.803,.848), (-.770,.863), (-.675,.850)),
    # Crown of the headlight brow rolls into the windshield and mirror shoulder.
    ((-.959,.846), (-.949,.853), (-.935,.859), (-.916,.865), (-.875,.884),
     (-.831,.906), (-.783,.927), (-.740,.939), (-.714,.934), (-.677,.898)),
)

SCREEN_STATIONS = [
    # Half-width, fore/aft center, center height, lateral sweep and edge rise.
    (.146, -.858, .902, .154, .075),
    (.147, -.813, .959, .124, .044),
    (.144, -.752, 1.024, .099, .016),
    (.133, -.677, 1.094, .075, -.015),
    (.118, -.604, 1.156, .056, -.052),
]

def screen_form(u, v):
    width, y, z, sweep, rise = sample(SCREEN_STATIONS, u)
    cross = 2 * v - 1
    distance = abs(cross)
    return cross * width, y + sweep * distance**2, z + rise * distance**2.2

def windscreen(u, v):
    # Leave a narrow tolerance for a real lower gasket at the paint seam.
    return screen_form(.021 + .979*u, v)

def nose_station(rail, distance):
    for i, right in enumerate(NOSE_STATIONS[1:]):
        if distance <= right:
            left = NOSE_STATIONS[i]
            interval = (distance - left) / (right - left)
            return sample(rail, (i + interval) / (len(NOSE_STATIONS) - 1))
    return rail[-1]

def nose_upper_edge(distance, width):
    # Precisely follow the windshield base before rolling into the mirror wing.
    screen_end = .625
    if distance <= screen_end:
        return screen_form(0, .5 + .5 * width / SCREEN_STATIONS[0][0])[1:]
    return sample(((-.704,.977), (-.681,.983), (-.669,.956), (-.669,.929)),
                  (distance - screen_end) / (1 - screen_end))

def section_height(values, height):
    # Shape-preserving cubic avoids foldback at narrow lamp slots.
    section = height * (len(values) - 1)
    i = min(int(section), len(values) - 2)
    t = section - i
    spans = [b-a for a, b in zip(values, values[1:])]
    d0 = spans[i]
    before = spans[max(0, i-1)]
    after = spans[min(len(spans)-1, i+1)]
    slope_in = 2 * d0 * before / (d0 + before) if d0 * before > 0 else 0.
    slope_out = 2 * d0 * after / (d0 + after) if d0 * after > 0 else 0.
    return values[i] + t*(slope_in + t*(3*d0 - 2*slope_in - slope_out +
                                      t*(slope_in+slope_out-2*d0)))

def nose_point(across, height):
    distance = abs(across)
    width, = nose_station([(width,) for width in NOSE_WIDTHS], distance)
    rails = [nose_station(rail, distance) for rail in NOSE_RAILS]
    rails.append(nose_upper_edge(distance, width))
    y, z = [section_height(column, height) for column in zip(*rails)]
    return (-width if across < 0 else width), y, z

def drl_channel(u, v):
    """Positive-side lamp opening, indexed inner→outer and bottom→top."""
    return nose_point((8 + 19*u) / 32, .25 + .25*v)

def projector_center():
    return (0, -.931, .783)

def mirror_mount():
    """Positive-side mirror shoulder and its outward surface normal."""
    return nose_point(.77, .953), (.42, -.22, .88)

def nose_lower_edge(y):
    """Nominal lower nose return for the side fairing joint."""
    lo, hi = .25, 1.
    for _ in range(18):
        mid = (lo + hi) / 2
        if nose_point(mid, 0)[1] < y:
            lo = mid
        else:
            hi = mid
    return nose_point((lo + hi) / 2, 0)

def build_nose():
    def remove_openings(i, j):
        if not 6 <= j < 12:
            return False
        return 5 <= i < 24 or 26 <= i < 38 or 40 <= i < 59

    shell("Front nose • unified molded fairing", lambda u, v: nose_point(2*u-1, v),
          64, 24, "paint_alt", FRONT, (0, .0032, -.001), 1, -1, omit=remove_openings)
    # The cylinder sits behind a shaped, tapered intake rather than in front of
    # the lip. Match the outer loop to the inner wall of the aperture.
    left, right, low, high = 26, 38, 6, 12
    edge = [(i, low) for i in range(left, right)]
    edge += [(right, j) for j in range(low, high)]
    edge += [(i, high) for i in range(right, left, -1)]
    edge += [(left, j) for j in range(high, low, -1)]
    contour = [nose_point(i/32 - 1, j/24) for i, j in edge]
    _, _, center_z = projector_center()
    loops = [
        [(x*.995, y+.0038, z-.001) for x, y, z in contour],
        [(x*.68, -.930, center_z + (z-center_z)*.69) for x, _, z in contour],
        [(x*.66, -.907, center_z + (z-center_z)*.67) for x, _, z in contour],
        [(x*1.01, y+.0067, z-.001) for x, y, z in contour],
    ]
    count = len(contour)
    faces = [(i*count+j, i*count+(j+1)%count, (i+1)%4*count+(j+1)%count, (i+1)%4*count+j)
             for i in range(4) for j in range(count)]
    mesh("Central headlight • molded recess liner", [p for row in loops for p in row], faces,
         "black", FRONT, smooth=True)

    shell("Windscreen • fitted smoked polycarbonate", windscreen, 26, 32, "smoke",
          FRONT, (0, .0021, -.0018), 1, -1)
    seam = [screen_form(.0105, i / 24) for i in range(25)]
    tube("Windscreen • seated lower gasket", [(x, y+.0006, z-.00035) for x, y, z in seam],
         .00165, "matte", FRONT)

def front_fender(u, v):
    cross = v * 2 - 1
    # The nose corners sweep back into a close, axle-concentric crown.
    angle = -1.03 + 2.075 * u + cross**2 * (.16 * (1-u)**3 - .075 * u**3)
    width = sample([(.053,), (.064,), (.072,), (.074,), (.073,), (.068,), (.060,)], u)[0]
    radius = .321 - .002 * abs(2*u-1)**2 - (.017 * cross**2 + .006 * cross**4)
    return cross * width, -.6975 + radius * sin(angle), .300 + radius * cos(angle)

def mudguard_mount(u, v, side):
    x, y, z = front_fender(.46 + .29 * u, .985)
    # At each fore-aft station the cheek descends directly from the crown.
    # The single tapered lobe reaches the cast axle foot under the stanchion.
    foot = exp(-((y + .634) / .029)**2)
    return side * (x + v * (.004 + .0083 * foot)), y, z - v * (.022 + .122 * foot)

def hugger(u, v):
    angle = -1.31 + 1.74 * u
    cross = 2*v - 1
    radius = .328 - .024 * cross**2
    return cross*(.082 - .008*u), .6975 + radius*sin(angle), .310 + radius*cos(angle)

def undertray(u, v):
    # One uninterrupted underside with constant longitudinal sections.
    y, width, floor, lip = sample([
        (.422,.093,.752,.779), (.554,.112,.782,.806),
        (.688,.095,.841,.864), (.821,.070,.890,.906),
        (.948,.058,.941,.948),
    ], u)
    cross = 2*v - 1
    return width*cross, y, floor + (lip-floor)*cross**2

def build_body():
    loft("Fuel tank • formed steel shell", TANK_SECTIONS, "paint", TANK, True)
    loft("Fuel tank • contoured mounting tray", TANK_MOUNTS, "satin", TANK)
    loft("Tail cowl • upswept seat unit", TAIL_SECTIONS, "paint", BODY)
    loft("Rider saddle • contoured grained vinyl", RIDER_SECTIONS, "seat", SEATS)
    loft("Pillion pad • tapered grained vinyl", PASSENGER_SECTIONS, "seat", SEATS)
    build_nose()
    shell("Front mudguard • curved tire crown", front_fender, 36, 16, "paint",
          FRONT, (0, 0, -.003), 2)
    shell("Rear hugger • close-fitting tire shield", hugger, 22, 14, "satin",
          BODY, (0, 0, -.004), 2)
    shell("Undertray • closed pillion silhouette", undertray, 20, 16, "matte",
          BODY, (0, 0, .0035), 2, -1, triangulate=True)

    for side, side_name in ((1, "Left"), (-1, "Right")):
        def fairing(name, rows, surface="paint", collection=BODY, **options):
            return patch(f"{side_name} {name}", rows, surface, collection, side, **options)

        def cheek(u, v):
            x, y, z = cheek_surface(u, v)
            return side*x, y+.0015, z
        shell(f"{side_name} upper cheek • joined side return", cheek, 24, 24,
              "paint_alt", FRONT, (-side*.004, 0, 0), 0, side)
        main_fairing(side, side_name)
        def belly_skin(u, v):
            x, y, z = fairing_surface(BELLY, u, v)
            return side*x, y, z

        shell(f"{side_name} lower cowl • single formed belly shield", belly_skin, 32, 16,
              "paint_alt", BODY, normal_thickness(belly_skin, side, .0038), 0, side)

        def belly_return(u, v):
            x, y, z = sample(SIDE[-1], u)
            return side*(x - .004), y + .001*v, z - .009*v + .002

        shell(f"{side_name} lower cowl • internal seam return", belly_return, 32, 2,
              "matte", BODY, (-side*.0025, 0, 0), 0, side)
        fairing("upper tank-side infil", WING, "satin")
        fairing("saddle side cover", SEAT_SIDE, "satin")
        fairing("tail side panel • scalloped shoulder", TAIL_SCALLOP, "paint_alt")
        shell(f"{side_name} mudguard mount • tapered fork shoulder", lambda u, v: mudguard_mount(u, v, side),
              24, 6, "satin", FRONT, (-side*.005, 0, 0), 0, side)
        fairing("rear eliminator arm • tapered structural web", [
            [(.044,.764,.895), (.056,.834,.867), (.058,.902,.813), (.052,.962,.758), (.041,1.002,.706)],
            [(.018,.788,.870), (.028,.850,.833), (.038,.917,.776), (.027,.964,.723), (.026,1.007,.692)],
        ], "satin", BODY, nu=15, nv=4)
        hem_points = []
        for y in (-.405, -.360, -.279, -.210, -.149, -.078, .009, .075, .109):
            ring = tank_ring(y)
            x, _, z = ring[9]
            hem_points.append(tank_steering_relief((side*(x - .002), y, z)))
        tube(f"{side_name} tank lower hem", hem_points, .0015, "satin", TANK)
        tube(f"{side_name} rider seat micro piping", [(side*x, y, z) for x, y, z in [
             (.068,.135,.814),(.085,.166,.810),(.113,.238,.804),(.141,.339,.809),
             (.149,.425,.822),(.134,.501,.851),(.106,.549,.874)]], .0011, "matte", SEATS)
        for index, (x, y, z) in enumerate([
             (side_surface(-.595,.699) - .001, -.595, .699),
             (side_surface(-.235,.685) - .001, -.235, .685),
             (width_at_y_z(BELLY,-.354,.417) - .001, -.354, .417),
             (width_at_y_z(BELLY,-.139,.326) - .001, -.139, .326),
             (width_at_y_z(SEAT_SIDE,.426,.800) - .001, .426, .800), (.148,.571,.848),
        ]):
            bolt(f"{side_name} recessed body screw {index + 1:02}", (side*x, y, z),
                 (side, 0, .12), .0042, "engine", DETAIL, depth=.0024)
        bolt(f"{side_name} mudguard retaining bolt", (side*.117, -.645, .466),
             (side, 0, .09), .0042, "steel", DETAIL, depth=.005)
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
