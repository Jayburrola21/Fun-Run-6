"""Build the actual remodel, export FBX, validate geometry and render four views.
Run: BLENDER_USER_RESOURCES=/workspace/.cache/fun-run-6/blender blender -b --python tools/build_kart_blender.py
Canonical coordinates are Roblox studs, X right/Y up/-Z forward. No global shrink.
"""
import bpy, bmesh, hashlib, json, math, os
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]
DIST=ROOT/'dist'; DIST.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
scene.unit_settings.system='NONE'
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def B(p): return C@Vector(p)
def R(rx=0,ry=0,rz=0):
 return Matrix.Rotation(rx,3,'X')@Matrix.Rotation(ry,3,'Y')@Matrix.Rotation(rz,3,'Z')
def transform(p,center=(0,0,0),rot=None): return Vector(center)+(rot@Vector(p) if rot is not None else Vector(p))
def srgb(v): return ((v+.055)/1.055)**2.4 if v>.04045 else v/12.92

def material(name,rgb,rough=.28,metal=0,emission=0):
 m=bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*rgb,1)
 sh=m.node_tree.nodes.get('Principled BSDF'); sh.inputs['Base Color'].default_value=(*(srgb(x) for x in rgb),1)
 sh.inputs['Roughness'].default_value=rough; sh.inputs['Metallic'].default_value=metal
 if emission:
  sh.inputs['Emission Color'].default_value=(*rgb,1); sh.inputs['Emission Strength'].default_value=emission
 return m
M={
 'red':material('KartPaint_Red',(0.88,.035,.075),.22,.12),
 'white':material('Pearl_White',(.94,.955,.98),.25,.12),
 'blue':material('LowerShell_Blue',(.035,.21,.69),.28,.10),
 'black':material('Satin_Black',(.035,.043,.055),.45,.15),
 'rubber':material('Tire_Rubber',(.045,.049,.058),.76,0),
 'groove':material('Tire_Grooves',(.015,.018,.022),.82,0),
 'seat':material('BucketSeat_Graphite',(.055,.065,.085),.72,0),
 'seatInset':material('Seat_PaddedInset',(.09,.105,.135),.83,0),
 'metal':material('Brushed_Alloy',(.42,.47,.54),.30,.78),
 'yellow':material('Rim_Gold',(.99,.72,.045),.24,.65),
 'spring':material('Spring_Cobalt',(.03,.29,.91),.24,.55),
 'lamp':material('Lamp_White',(.80,.93,1),.2,.1,1.5),
 'brake':material('Brake_Red',(.95,.02,.025),.28,.1,.8),
 'glass':material('Dashboard_Display',(.035,.19,.27),.28,.15,.4),
 'marker':material('Alignment_Marker',(.1,1,.2),.5,0),
}
collection=bpy.data.collections.new('KartRoot'); scene.collection.children.link(collection)
root=bpy.data.objects.new('KartRoot',None); collection.objects.link(root)
groups={}
for label in ['MainBody','FrontNose','LeftSidePod','RightSidePod','RearBody','RearBumper','Seat','SteeringWheel','FrontLeftWheel','FrontRightWheel','RearLeftWheel','RearRightWheel','LeftExhaust','RightExhaust','Chassis']:
 e=bpy.data.objects.new(label,None); collection.objects.link(e); e.parent=root; groups[label]=e
objects=[]

def mesh(name,vertices,faces,mat,group,pivot=(0,0,0),smooth=True,bevel=0,solidify=0):
 data=bpy.data.meshes.new(name); bp=B(pivot)
 data.from_pydata([B(v)-bp for v in vertices],[],faces); data.update()
 bm=bmesh.new(); bm.from_mesh(data)
 if all(not edge.is_boundary for edge in bm.edges): bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(data); bm.free(); data.update()
 ob=bpy.data.objects.new(name,data); collection.objects.link(ob); ob.location=bp; ob.parent=groups[group]
 ob.data.materials.append(M[mat]); ob['KartGroup']=group; ob['CanonicalPivot']=[float(v) for v in pivot]; ob['MaterialRole']=mat
 for poly in ob.data.polygons: poly.use_smooth=smooth
 if solidify:
  mod=ob.modifiers.new('Manufactured shell thickness','SOLIDIFY'); mod.thickness=solidify; mod.offset=-1
 if bevel:
  mod=ob.modifiers.new('Soft molded edges','BEVEL'); mod.width=bevel; mod.segments=2; mod.profile=.5; mod.use_clamp_overlap=True
  try: mod.harden_normals=True
  except AttributeError: pass
  mod=ob.modifiers.new('Balanced normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=40
 objects.append(ob); return ob

BOX_VERTS=[(-.5,-.5,-.5),(.5,-.5,-.5),(.5,.5,-.5),(-.5,.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)]
BOX_FACES=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
def box(name,size,center,mat,group,bevel=.04,rot=None,pivot=(0,0,0)):
 vs=[transform(tuple(v[i]*size[i] for i in range(3)),center,rot) for v in BOX_VERTS]
 return mesh(name,vs,BOX_FACES,mat,group,pivot,False,bevel)
def loft(name,sections,profile,mat,group,bevel=.025):
 # sections contain z, centerX, width, bottomY, topY
 vs=[]; n=len(profile)
 for z,cx,width,low,high in sections:
  for px,py in profile: vs.append((cx+px*width,low+py*(high-low),z))
 fs=[]
 for j in range(len(sections)-1):
  for i in range(n): fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 fs += [tuple(range(n-1,-1,-1)),tuple((len(sections)-1)*n+i for i in range(n))]
 return mesh(name,vs,fs,mat,group,smooth=True,bevel=bevel)
def tube(name,points,radius,mat,group,pivot=(0,0,0),sides=10):
 vs=[]
 for j,p in enumerate(points):
  tangent=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])).normalized()
  seed=Vector((1,0,0)) if abs(tangent.x)<.8 else Vector((0,1,0))
  u=tangent.cross(seed).normalized(); v=tangent.cross(u).normalized()
  for i in range(sides):vs.append(Vector(p)+radius*(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v))
 fs=[]
 for j in range(len(points)-1):
  for i in range(sides):fs.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
 fs += [tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+i for i in range(sides))]
 return mesh(name,vs,fs,mat,group,pivot,True)
def cylinder(name,radius,depth,center,mat,group,axis=(1,0,0),pivot=(0,0,0),segments=40,bevel=.015):
 axis=Vector(axis).normalized(); seed=Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))
 u=axis.cross(seed).normalized(); v=axis.cross(u).normalized(); vs=[]
 for d in (-depth/2,depth/2):
  for i in range(segments):vs.append(Vector(center)+axis*d+radius*(u*math.cos(i*math.tau/segments)+v*math.sin(i*math.tau/segments)))
 fs=[tuple(range(segments-1,-1,-1)),tuple(segments+i for i in range(segments))]
 fs += [(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
 ob=mesh(name,vs,fs,mat,group,pivot,True,bevel)
 ob.data.polygons[0].use_smooth=False; ob.data.polygons[1].use_smooth=False
 return ob

def rounded_panel(name,width,height,depth,radius,center,rot,mat,group):
 outline=[]
 for cx,cz,start in [(width/2-radius,height/2-radius,0),(-width/2+radius,height/2-radius,90),(-width/2+radius,-height/2+radius,180),(width/2-radius,-height/2+radius,270)]:
  for n in range(7):
   a=math.radians(start+n*90/6)
   outline.append((cx+radius*math.cos(a),cz+radius*math.sin(a)))
 vs=[]
 for y in (-depth/2,depth/2):
  for x,z in outline:vs.append(transform((x,y,z),center,rot))
 n=len(outline); fs=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]
 fs.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
 return mesh(name,vs,fs,mat,group,smooth=True,bevel=.012)

# Tapered undertray and sculpted lower tub conceal the old exposed construction.
profile=[(-.5,.2),(-.48,.7),(-.35,1),(.35,1),(.48,.7),(.5,.2),(.35,0),(-.35,0)]
loft('Chassis__TaperedSkid',[(-3.22,0,2.12,-.14,.15),(-1.18,0,2.40,-.14,.19),(-.80,0,3.18,-.14,.25),(1.15,0,3.28,-.14,.25),(2.62,0,2.98,-.14,.24)],profile,'black','Chassis',.045)
loft('MainBody__BlueLowerTub',[(-3.18,0,2.14,.04,.32),(-1.14,0,2.38,.04,.40),(-.78,0,3.22,.04,.43),(1.18,0,3.30,.04,.43),(2.58,0,3.0,.04,.43)],profile,'blue','MainBody',.045)
box('MainBody__CockpitFloor',(2.14,.12,2.30),(0,.31,.10),'black','MainBody',.08)

# Continuous molded sidewalls, with low white/blue belts and an open cockpit.
pod_profile=[(-.50,.12),(-.50,.67),(-.42,.90),(-.25,.99),(.24,1),(.45,.89),(.50,.66),(.50,.25),(.37,.07),(.06,0),(-.30,.02),(-.46,.06)]
pod_sections=[(-1.04,1.30,.42,.13,.62),(-.65,1.37,.58,.12,.98),(0,1.39,.60,.12,1.14),(.70,1.39,.62,.12,1.13),(1.26,1.35,.58,.12,.98),(1.60,1.28,.48,.14,.77)]
for side,label in [(-1,'LeftSidePod'),(1,'RightSidePod')]:
 sections=[(z,side*cx,width,lo,hi) for z,cx,width,lo,hi in pod_sections]
 loft(label+'__PaintRed_Shell',sections,pod_profile,'red',label,.035)
 for role,low,high,offset in [('blue',.17,.37,.009),('white',.39,.54,.014)]:
  vs=[]
  for z,cx,w,lo,hi in pod_sections:
   x=side*(cx+w/2+offset)
   vs.extend([(x,low,z),(x,high,z)])
  faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(sections)-1)]
  if side<0:faces=[tuple(reversed(face)) for face in faces]
  mesh(label+'__'+role.title()+'Belt',vs,faces,role,label,smooth=True,bevel=.015,solidify=.025)
 # A small integrated badge avoids moving the panel out into the tires.
 center=(side*1.716,.74,.28)
 cylinder(label+'__WhiteRoundel',.27,.012,center,'white',label,segments=40,bevel=.004)
 vs=[]
 for radius in (.17,.071):
  for i in range(4):
   a=math.pi/4+i*math.pi/2+math.radians(15)
   vs.append((side*1.727,.74+radius*math.cos(a),.28+radius*math.sin(a)))
 emblem_faces=[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
 if side<0:emblem_faces=[tuple(reversed(face)) for face in emblem_faces]
 mesh(label+'__PaintRed_Emblem',vs,emblem_faces,'red',label,smooth=False,solidify=.006)
 # Thin dark cockpit weather strip, following the upper inner edge.
 points=[(side*(cx-w*.46),hi-.035,z) for z,cx,w,lo,hi in pod_sections[1:-1]]
 tube(label+'__CockpitEdge',points,.033,'black',label,sides=8)

# Smooth arched nose with a curved inlaid center stripe, not a faceted slab.
def hood(z,x):
 t=(z+3.22)/2.38; width=1.07+.07*math.sin(math.pi*t)-.10*t
 y=.41+1.02*t+.24*math.sin(math.pi*t)-.23*(x/width)**2
 return y,width
for label,mat,f0,f1 in [('LeftPaintRed','red',-1,-.30),('WhiteCenter','white',-.30,.30),('RightPaintRed','red',.30,1)]:
 vs=[]; rows=19; cols=6
 for j in range(rows):
  z=-3.22+j*2.38/(rows-1); _,w=hood(z,0)
  for k in range(cols):
   f=f0+(f1-f0)*k/(cols-1); x=f*w
   shaped_z=z+.20*f*f*math.exp(-9*j/(rows-1))
   y,_=hood(shaped_z,x)
   vs.append((x,y,shaped_z))
 fs=[(j*cols+k,(j+1)*cols+k,(j+1)*cols+k+1,j*cols+k+1) for j in range(rows-1) for k in range(cols-1)]
 name='FrontNose__'+('PaintRed_'+label if mat=='red' else 'PearlCenterStripe')
 mesh(name,vs,fs,mat,'FrontNose',smooth=True,bevel=.025,solidify=.10)
# Small red hollow-square logo conforms to the actual nose surface.
vs=[]; center_z=-2.05
for radius in (.285,.12):
 for i in range(4):
  a=math.pi/4+i*math.pi/2+math.radians(15); x=radius*math.cos(a); z=center_z+radius*math.sin(a)
  y,_=hood(z,x); vs.append((x,y+.014,z))
mesh('FrontNose__PaintRed_Brand',vs,[(i,i+4,(i+1)%4+4,(i+1)%4) for i in range(4)],'red','FrontNose',smooth=False,bevel=.004,solidify=.008)
# Nose-to-side transition panels stay behind the front-wheel steering sweep.
for side in (-1,1):
 loft('FrontNose__PaintRed_Shoulder'+str(side),[(-1.10,side*.98,.30,.27,.80),(-.92,side*1.17,.40,.23,.88),(-.67,side*1.36,.54,.23,.93)],pod_profile,'red','FrontNose',.025)

# Curved front bumper and properly paired lamps.
front_path=[]
for i in range(17):
 x=-1.44+i*2.88/16; z=-3.48+.20*(abs(x)/1.44)**2
 front_path.append((x,.22,z))
tube('FrontNose__WhiteBumper',front_path,.15,'white','FrontNose',sides=12)
tube('FrontNose__BlueBumperLip',[(x,.055,z+.025) for x,y,z in front_path],.085,'blue','FrontNose',sides=10)
for side in (-1,1):
 box('FrontNose__LampHousing'+str(side),(.34,.16,.10),(side*1.18,.39,-3.25),'black','FrontNose',.045)
 box('FrontNose__LampLens'+str(side),(.25,.075,.035),(side*1.18,.40,-3.312),'lamp','FrontNose',.025)
for x in (-.72,-.36,.36,.72):box('FrontNose__BumperVent'+str(x),(.13,.12,.025),(x,.23,-3.55),'blue','FrontNose',.025)

# Rear housing closes the silhouette around the seat and rear wheels.
rear_profile=[(-.5,.14),(-.48,.72),(-.36,.98),(.36,.98),(.48,.72),(.5,.14),(.35,0),(-.35,0)]
loft('RearBody__PaintRed_EngineCowl',[(1.22,0,2.95,.20,.91),(1.64,0,3.10,.20,1.02),(2.25,0,3.05,.19,.88),(2.67,0,2.79,.19,.59)],rear_profile,'red','RearBody',.055)
box('RearBody__EngineVentInset',(1.20,.055,.65),(0,.935,1.94),'black','RearBody',.08,rot=R(math.radians(7),0,0))
for x in (-.44,-.22,0,.22,.44):box('RearBody__EngineVentFin'+str(x),(.065,.065,.51),(x,.975,1.94),'metal','RearBody',.018)
rear_path=[(-1.50,.18,2.81),(-1.37,.18,2.96),(-.90,.18,3.03),(0,.18,3.06),(.90,.18,3.03),(1.37,.18,2.96),(1.50,.18,2.81)]
tube('RearBumper__BlackRubber',rear_path,.145,'black','RearBumper',sides=12)
tube('RearBumper__WhiteHighlight',[(x,.31,z-.018) for x,y,z in rear_path[1:-1]],.034,'white','RearBumper',sides=8)
for side in (-1,1):
 box('RearBody__BrakeHousing'+str(side),(.42,.16,.10),(side*1.12,.55,2.72),'black','RearBody',.04)
 box('RearBody__BrakeLens'+str(side),(.31,.08,.025),(side*1.12,.56,2.779),'brake','RearBody',.025)

# Compact rear branding, flush to the cowl and inside the existing silhouette.
rounded_panel('RearBody__WhiteRearBadge',.68,.25,.014,.075,(0,.415,2.679),R(math.pi/2,0,0),'white','RearBody')
vs=[]
for radius in (.127,.055):
 for i in range(4):
  a=math.pi/4+i*math.pi/2+math.radians(15)
  vs.append((radius*math.cos(a),.415+radius*math.sin(a),2.693))
mesh('RearBody__PaintRed_RearEmblem',vs,[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)],'red','RearBody',smooth=False,solidify=.006)

# A proper concave bucket seat: backrest, pads and raised lateral supports.
box('Seat__LowerBucket',(1.94,.30,1.58),(0,.80,.55),'seat','Seat',.16)
box('Seat__Cushion',(1.58,.13,1.28),(0,.98,.49),'seatInset','Seat',.13)
seat_back=[(.98,0,1.86,.85,1.35),(1.12,0,1.97,1.10,1.72),(1.32,0,1.91,1.50,2.10),(1.45,0,1.68,1.91,2.50)]
loft('Seat__SculptedBack',seat_back,[(-.5,.05),(-.5,.62),(-.46,.80),(-.35,.96),(-.18,1),(.18,1),(.35,.96),(.46,.80),(.5,.62),(.5,.05),(.31,0),(-.31,0)],'seat','Seat',.10)
rounded_panel('Seat__BackPad',1.48,1.28,.16,.20,(0,1.68,1.12),R(math.radians(80),0,0),'seatInset','Seat')
for side in (-1,1):
 tube('Seat__RaisedBolster'+str(side),[(side*.83,1.06,-.06),(side*.92,1.24,.50),(side*.94,1.57,1.02),(side*.83,2.13,1.29)],.13,'seat','Seat',sides=12)
rounded_panel('Seat__HeadrestInset',.69,.39,.13,.14,(0,2.19,1.18),R(math.radians(80),0,0),'black','Seat')

# A restrained compact dashboard beneath the steering wheel.
box('MainBody__Dashboard', (1.74,.23,.49),(0,1.35,-.60),'black','MainBody',.12,rot=R(math.radians(-13),0,0))
box('MainBody__DisplayGlass',(.61,.025,.23),(0,1.478,-.61),'glass','MainBody',.035,rot=R(math.radians(-13),0,0))
for side in (-1,1):box('MainBody__DashboardButton'+str(side),(.10,.035,.10),(side*.51,1.48,-.60),'yellow','MainBody',.025)

# Separate steering objects, all with the existing functional motor pivot.
steer_pivot=(0,1.95,-1.05); steer_rot=R(math.radians(-24),0,0)
steer_points=[transform((.60*math.cos(i*math.tau/48),.60*math.sin(i*math.tau/48),0),steer_pivot,steer_rot) for i in range(49)]
tube('SteeringWheel__RubberRim',steer_points,.075,'black','SteeringWheel',steer_pivot,sides=8)
for n,a in enumerate((math.radians(90),math.radians(210),math.radians(330))):
 p0=transform((.11*math.cos(a),.11*math.sin(a),0),steer_pivot,steer_rot); p1=transform((.54*math.cos(a),.54*math.sin(a),0),steer_pivot,steer_rot)
 tube('SteeringWheel__AlloySpoke'+str(n),[p0,p1],.045,'metal','SteeringWheel',steer_pivot,sides=8)
cylinder('SteeringWheel__CenterHub',.14,.12,steer_pivot,'black','SteeringWheel',axis=steer_rot@Vector((0,0,1)),pivot=steer_pivot,segments=24)
tube('MainBody__SteeringColumn',[(0,.45,-.64),(0,1.86,-1.03)],.065,'metal','MainBody',sides=10)

# Narrow, chunky tires with rounded shoulders, actual tread grooves and gold rims.
wheel_profile=[(-.38,.52),(-.38,.72),(-.35,.83),(-.28,.93),(-.18,.96),(.18,.96),(.28,.93),(.35,.83),(.38,.72),(.38,.52)]
for front,z in [(True,-2.16),(False,2.16)]:
 for side in (-1,1):
  group=('Front' if front else 'Rear')+('LeftWheel' if side<0 else 'RightWheel')
  pivot=(side*2.20,.40,z); vs=[]; segments=40
  for x,radius in wheel_profile:
   for i in range(segments):
    a=i*math.tau/segments; vs.append((pivot[0]+x,pivot[1]+radius*math.cos(a),pivot[2]+radius*math.sin(a)))
  fs=[]
  for j in range(len(wheel_profile)):
   for i in range(segments):fs.append((j*segments+i,j*segments+(i+1)%segments,((j+1)%len(wheel_profile))*segments+(i+1)%segments,((j+1)%len(wheel_profile))*segments+i))
  mesh(group+'__RoundedTire',vs,fs,'rubber',group,pivot,True)
  cylinder(group+'__InnerBrakeCover',.545,.05,(pivot[0]-side*.35,pivot[1],pivot[2]),'black',group,pivot=pivot,segments=32,bevel=.014)
  cylinder(group+'__InnerAxleBoss',.13,.065,(pivot[0]-side*.376,pivot[1],pivot[2]),'metal',group,pivot=pivot,segments=20,bevel=.012)
  # Fine wraparound V grooves follow the barrel instead of floating above it.
  vs=[]; fs=[]
  for n in range(20):
   for half in (-1,1):
    first=len(vs)
    for k in range(5):
     x=half*(.02+k*.067); rr=.961-.045*(abs(x)/.38)**2; a=n*math.tau/20+abs(x)*.30
     for da in (-.009,.009):vs.append((pivot[0]+x,pivot[1]+rr*math.cos(a+da),pivot[2]+rr*math.sin(a+da)))
    fs.extend((first+k*2,first+k*2+1,first+k*2+3,first+k*2+2) for k in range(4))
  mesh(group+'__ChevronTread',vs,fs,'groove',group,pivot,True)
  cylinder(group+'__RimOuter',.62,.070,(pivot[0]+side*.372,pivot[1],pivot[2]),'yellow',group,pivot=pivot,segments=40,bevel=.035)
  cylinder(group+'__RimInset',.48,.055,(pivot[0]+side*.398,pivot[1],pivot[2]),'yellow',group,pivot=pivot,segments=32,bevel=.04)
  cylinder(group+'__AxleHub',.16,.070,(pivot[0]+side*.423,pivot[1],pivot[2]),'black',group,pivot=pivot,segments=24,bevel=.02)
  for n in range(3):
   a=n*math.tau/3+math.pi/6
   center=(pivot[0]+side*.430,pivot[1]+.32*math.cos(a),pivot[2]+.32*math.sin(a))
   box(group+'__RimVent'+str(n),(.013,.12,.19),center,'black',group,.022,rot=R(a,0,0),pivot=pivot)
  # Visible A-arms remain subtle, well inside the tire steering sweep.
  if front:
   for rise in (.11,.28):tube('MainBody__FrontWishbone'+str(side)+str(rise),[(side*1.10,rise,z+.40),(side*1.55,.40,z+.05),(side*1.10,rise,z-.27)],.043,'black','MainBody',sides=8)

# Decorative coilovers do not add physical Roblox suspension constraints.
for side in (-1,1):
 lower=Vector((side*1.30,.31,-1.30)); upper=Vector((side*1.12,1.18,-1.04)); axis=upper-lower; d=axis.normalized()
 u=d.cross(Vector((0,0,1))).normalized(); v=d.cross(u).normalized()
 tube('MainBody__DamperRod'+str(side),[lower,upper],.036,'metal','MainBody',sides=10)
 tube('MainBody__DamperSleeve'+str(side),[lower,lower+axis*.42],.075,'metal','MainBody',sides=12)
 points=[]
 for i in range(65):
  t=i/64; a=t*math.pi*8; points.append(lower+axis*(.10+t*.78)+.10*(u*math.cos(a)+v*math.sin(a)))
 tube('MainBody__BlueCoil'+str(side),points,.021,'spring','MainBody',sides=7)

# Compact symmetric twin exhausts, short and angled rearward/upward.
for side,label in [(-1,'LeftExhaust'),(1,'RightExhaust')]:
 axis=Vector((0,.32,.948)).normalized(); base=Vector((side*.78,.94,2.22)); tip=base+axis*.76
 cylinder(label+'__BlackCanister',.235,.76,(base+tip)/2,'black',label,axis=axis,segments=32,bevel=.035)
 cylinder(label+'__GoldTip',.246,.075,tip,'yellow',label,axis=axis,segments=32,bevel=.014)
 cylinder(label+'__DarkOpening',.18,.081,tip+axis*.010,'black',label,axis=axis,segments=32,bevel=.008)
 cylinder(label+'__InnerBore',.125,.084,tip+axis*.014,'groove',label,axis=axis,segments=24,bevel=.006)
 tube(label+'__Mount',[(side*.75,.70,2.15),(side*.78,1.0,2.30)],.052,'metal',label,sides=8)

# Apply mesh modifiers, preserving axle/object origins and unit transforms.
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:
 bpy.context.view_layer.objects.active=ob; ob.select_set(True)
 for mod in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
 ob.select_set(False)

# Material tags survive FBX import even when Studio drops Blender shaders.
roles={'red':'Paint','white':'White','blue':'Blue','black':'Black','rubber':'Rubber','groove':'Rubber','seat':'Seat','seatInset':'Seat','metal':'Metal','yellow':'Yellow','spring':'Spring','lamp':'Lamp','brake':'Brake','glass':'Glass'}
for ob in objects: ob.name += '__Mat'+roles[ob['MaterialRole']]

# Alignment marker cubes are exported, but never rendered.
markers=[]
for name,point in [('KartOrigin',(0,0,0)),('KartForward',(0,0,-4)),('KartUp',(0,4,0))]:
 ob=box(name,(.035,.035,.035),point,'marker','Chassis',0)
 ob.name=name; ob.hide_render=True; ob['AlignmentMarker']=True; markers.append(ob)

# Save unambiguous pivot/axis/material metadata for Roblox integration.
manifest={'version':1,'coordinate_system':'Roblox canonical: X right, Y up, -Z forward','blender_conversion':'(x,y,z) -> (x,-z,y)','model_scale_runtime':.84,'wheel_track':4.4,'wheelbase':4.32,'wheel_radius':.96,'wheel_width':.76,'wheel_pivots':{},'steering_pivot':{'position':list(steer_pivot),'rotation_x_degrees':-24},'alignment_markers':{'KartOrigin':[0,0,0],'KartForward':[0,0,-4],'KartUp':[0,4,0]},'blender_version':bpy.app.version_string,'objects':[]}
for front,z in [(True,-2.16),(False,2.16)]:
 for side in (-1,1):manifest['wheel_pivots'][('Front' if front else 'Rear')+('LeftWheel' if side<0 else 'RightWheel')]=[side*2.2,.4,z]
triangles=0
for ob in objects:
 if ob in markers:continue
 ob.data.calc_loop_triangles(); tris=len(ob.data.loop_triangles); triangles+=tris
 assert tris<10000,(ob.name,tris)
 canonical_vertices=[C.transposed()@(ob.matrix_world@v.co) for v in ob.data.vertices]
 lo=[min(v[i] for v in canonical_vertices) for i in range(3)]; hi=[max(v[i] for v in canonical_vertices) for i in range(3)]
 assert all(math.isfinite(x) for x in lo+hi)
 manifest['objects'].append({'name':ob.name,'group':ob['KartGroup'],'material_role':ob['MaterialRole'],'pivot':list(ob['CanonicalPivot']),'triangles':tris,'vertices':len(ob.data.vertices),'bounds':{'min':lo,'max':hi}})
manifest['triangles']=triangles
manifest['max_mesh_triangles']=max(o['triangles'] for o in manifest['objects'])
print('KART_TRIANGLE_COUNT',triangles)
assert triangles<35000,triangles
(DIST/'KartRemodel.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

# Real FBX asset with separate functional wheel and steering meshes.
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
for ob in [root,*groups.values()]:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.fbx(filepath=str(DIST/'KartRemodel.fbx'),use_selection=True,object_types={'MESH','EMPTY'},use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y',global_scale=1.0,apply_unit_scale=True,mesh_smooth_type='FACE',path_mode='AUTO',use_custom_props=True)

# Separate presentation collection; no studio props enter the FBX.
studio=bpy.data.collections.new('Presentation Studio (not exported)'); scene.collection.children.link(studio)
def move_to_studio(ob):
 for c in list(ob.users_collection):c.objects.unlink(ob)
 studio.objects.link(ob)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.57)); floor=bpy.context.object; floor.name='StudioFloor'; move_to_studio(floor)
floor_mat=material('StudioFloor',(.14,.16,.20),.72,0); floor.data.materials.append(floor_mat)
world=bpy.data.worlds.new('Soft studio'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.24,.32,1); world.node_tree.nodes['Background'].inputs[1].default_value=.35; scene.world=world
for name,location,power,size in [('Key',(1,5,8),1000,6),('Fill',(-6,2,4),750,5),('Rear',(2,-6,6),1200,4)]:
 bpy.ops.object.light_add(type='AREA',location=location); ob=bpy.context.object; ob.name=name; move_to_studio(ob); ob.data.energy=power; ob.data.shape='DISK'; ob.data.size=size; ob.rotation_euler=(Vector((0,0,.8))-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(9,12,7)); camera=bpy.context.object; camera.name='ShowcaseCamera'; move_to_studio(camera); scene.camera=camera
camera.data.type='ORTHO'; camera.data.ortho_scale=9.3
camera.rotation_euler=(Vector((0,0,.85))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples=32
scene.render.resolution_x=1000; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
# Markers hidden only in viewport/render; their FBX export above is retained.
for ob in markers:ob.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(DIST/'KartRemodel.blend'))
manifest['source']={'path':'tools/build_kart_blender.py','sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
manifest['assets']={name:hashlib.sha256((DIST/name).read_bytes()).hexdigest() for name in ('KartRemodel.blend','KartRemodel.fbx')}
(DIST/'KartRemodel.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if os.environ.get('KART_SKIP_RENDER')=='1':
 print('KART_MODEL_COMPLETE',len(manifest['objects']),'mesh objects',triangles,'triangles; preview rendering skipped by explicit flag')
 raise SystemExit(0)
views=[('KartPreview.png',(9,12,7),(0,0,.85),9.3),('KartRemodelRear.png',(8,-12,6.7),(0,0,.85),9.3),('KartRemodelSide.png',(13,0,4.1),(0,0,.85),8.9),('KartRemodelTop.png',(0,0,15),(0,0,0),9.6)]
for filename,location,target,scale in views:
 camera.location=location; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=scale
 scene.render.filepath=str(DIST/filename); bpy.ops.render.render(write_still=True)
print('KART_MODEL_COMPLETE',len(manifest['objects']),'mesh objects',triangles,'triangles')

# Reproducible four-view contact sheet, assembled from the actual renders.
from array import array
width,height=2000,1600
pixels=array('f',[0])*(width*height*4)
for path,left,bottom in [('KartPreview.png',0,800),('KartRemodelRear.png',1000,800),('KartRemodelSide.png',0,0),('KartRemodelTop.png',1000,0)]:
 image=bpy.data.images.load(str(DIST/path),check_existing=False)
 source=array('f',[0])*(1000*800*4); image.pixels.foreach_get(source)
 for row in range(800):
  start=((bottom+row)*width+left)*4
  pixels[start:start+1000*4]=source[row*1000*4:(row+1)*1000*4]
 sheet=bpy.data.images.get('KartRemodelFourViews')
 if sheet: bpy.data.images.remove(sheet)
 bpy.data.images.remove(image)
sheet=bpy.data.images.new('KartRemodelFourViews',width=width,height=height,alpha=True)
sheet.pixels.foreach_set(pixels); sheet.filepath_raw=str(DIST/'KartRemodelPreview.png'); sheet.file_format='PNG'; sheet.save()
