#!/usr/bin/env python3
"""Execute the actual builder in a geometry-only Luau mock; optionally export parts."""
from pathlib import Path
import argparse,itertools,json,math,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--luau',default='luau'); p.add_argument('--output',type=Path); args=p.parse_args()
module=root/'src/ReplicatedStorage/KartSystem'
code=(root/'tests/geometry_mock.luau').read_text()
code+='\nlocal Config=(function()\n'+(module/'KartConfig.luau').read_text()+'\nend)()\n'
builder=(module/'KartBuilder.luau').read_text().replace('local Config = require(script.Parent.KartConfig)','')
code+='local Builder=(function()\n'+builder+'\nend)()\n'
code+='''
local kart=Builder.build("GeometryTest",CFrame.new(),Config.Palette.Red)
assert(#kart.wheels==4 and kart.driveForce.ApplyAtCenterOfMass)
local scale=Config.ModelScale or 0.84
assert(math.abs(kart.chassis.Size.X-3.7*scale)<1e-8,"Chassis must be uniformly scaled once")
assert(math.abs(kart.chassis.Size.Z-6.5*scale)<1e-8,"Chassis length scale mismatch")
assert(math.abs(kart.seat.Size.X-1.95*scale)<1e-8,"Cockpit width mismatch")
for _,wheel in ipairs(kart.wheels) do
 assert(math.abs(wheel.motor.Part1.Size.Y/2-Config.WheelRadius)<1e-8,"Physical tire radius/config mismatch")
 assert((wheel.origin-wheel.motor.C0.Position-Vector3.new(0,Config.SuspensionRest,0)).Magnitude<1e-8,"Scaled wheel metadata mismatch")
end
assert((kart.steeringBase.Position-kart.steering.C0.Position).Magnitude<1e-8,"Scaled steering metadata mismatch")
for _,wheel in ipairs(kart.wheels) do
 assert(#wheel.glow==(wheel.front and 0 or 16),"Rear-only boost ring budget mismatch")
 for _,piece in ipairs(wheel.glow) do assert(piece.Transparency==1 and piece.Material==Enum.Material.Neon,"Glow should start disabled") end
end
for key,value in pairs({MaxSteer=Config.MaxSteer,Rest=Config.SuspensionRest,Travel=Config.SuspensionTravel,Scale=scale,WheelTrack=Config.WheelTrack or 4.4*scale,Wheelbase=Config.Wheelbase,WheelRadius=Config.WheelRadius}) do
 print(string.format("META|%s|%.12f",key,value))
end
assert(kart.chassis.Transparency==1,"Original inertia collider must be hidden behind remade bodywork")
for _,flame in ipairs(kart.flames) do
 local outlet=flame.emitter.Parent.CFrame
 assert(math.abs(math.abs(outlet.Position.X)-0.78*scale)<1e-5,"Exhaust lateral position does not match Blender")
 assert(math.abs(outlet.Position.Y-1.20866*scale)<2e-5,"Exhaust outlet height does not match Blender")
 assert(math.abs(outlet.Position.Z-3.01590*scale)<2e-5,"Exhaust outlet depth does not match Blender")
 local magnitude=math.sqrt(0.32^2+0.948^2)
 assert(math.abs(-outlet.m[6]-0.32/magnitude)<1e-8 and math.abs(-outlet.m[9]-0.948/magnitude)<1e-8,"Exhaust particles must point rearward along the pipe")
end
local connected={[kart.chassis]=true}
for _=1,#instances do
 local changed=false
 for _,o in ipairs(instances) do
  if o:IsA("WeldConstraint") or o:IsA("Motor6D") then
   if connected[o.Part0] and not connected[o.Part1] then connected[o.Part1]=true; changed=true end
  end
 end
 if not changed then break end
end
local partCount=0
for _,o in ipairs(instances) do
 if o:IsA("BasePart") then
  partCount+=1
  assert(connected[o],"Disconnected part: "..o.Name)
  assert(o.Size.X>0 and o.Size.Y>0 and o.Size.Z>0,"Invalid size")
  assert(not o.Anchored,"Unexpected anchored part")
  if o~=kart.chassis then assert(o.Massless,"Visual mass affects inertia") end
  local p=o.CFrame.p
  for _,v in ipairs(o.CFrame.m) do assert(v==v and math.abs(v)<1.001,"Invalid rotation matrix") end
  print(string.format("PART|%s|%s|%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%s|%.6f,%.6f,%.6f|%s|%.3f|%s",o.Name,o.ClassName,o.Shape or "Block",o.Size.X,o.Size.Y,o.Size.Z,p.X,p.Y,p.Z,table.concat(o.CFrame.m,","),o.Color.R,o.Color.G,o.Color.B,o.Material,o.Transparency,o.Parent.Name))
 end
end
assert(partCount<400,"Geometry budget exceeded")
for _,wheel in ipairs(kart.wheels) do assert(wheel.motor.Part1.CanCollide==false,"Visual tire must not collide") end
print("PASS: builder executed; "..partCount.." connected parts, positive dimensions, finite frames, massless visual assemblies, four non-colliding visual wheels, COM traction; uniform scale and tire/config metadata match")
'''
with tempfile.TemporaryDirectory(prefix='kart-geometry-') as folder:
 path=Path(folder)/'geometry.luau'; path.write_text(code)
 result=subprocess.run([args.luau,str(path)],text=True,capture_output=True,check=True)
parts=[]
metadata={}
for line in result.stdout.splitlines():
 if line.startswith('META|'):
  _,key,value=line.split('|'); metadata[key]=float(value); continue
 if not line.startswith('PART|'):
  print(line); continue
 _,name,cls,shape,size,pos,matrix,color,material,transparency,group=line.split('|')
 parts.append(dict(name=name,cls=cls,shape=shape,size=list(map(float,size.split(','))),position=list(map(float,pos.split(','))),rotation=list(map(float,matrix.split(','))),color=list(map(float,color.split(','))),material=material,transparency=float(transparency),group=group))
# Badge top corners must sit above the curved center stripe rather than being
# buried by one of its loft panels; its white center remains an actual opening.
stripes=[p for p in parts if p['name']=='WhiteCenterStripe']
badges=[p for p in parts if p['name']=='NoseSquareBadge']
if badges:
 assert len(badges)==4 and len(stripes)==8, "Hood stripe/logo geometry changed"
 for badge in badges:
  for x in (-0.5,0.5):
   for z in (-0.5,0.5):
    local=[badge['size'][0]*x,badge['size'][1]/2,badge['size'][2]*z]
    point=[badge['position'][i]+sum(badge['rotation'][i*3+j]*local[j] for j in range(3)) for i in range(3)]
    covered=0
    for stripe in stripes:
     offset=[point[i]-stripe['position'][i] for i in range(3)]
     coordinates=[sum(stripe['rotation'][i*3+j]*offset[i] for i in range(3)) for j in range(3)]
     if abs(coordinates[0])<=stripe['size'][0]/2 and abs(coordinates[2])<=stripe['size'][2]/2:
      covered+=1
      assert coordinates[1]>stripe['size'][1]/2, "Nose logo is buried in the curved stripe"
    assert covered, "Nose logo falls off the white stripe"
 print("PASS: red nose square is centered fully above the curved white stripe")

# Check the swept volume of the actual tire geometry against visible generated
# bodywork. Invisible mass/inertia collision hulls are deliberately excluded:
# arcade tires never collide with those hulls. Sample both object surfaces, not
# just the tire centers, throughout steering AND the supported suspension range.
wheel_groups={"FrontLeft","FrontRight","RearLeft","RearRight"}
body=[p for p in parts if p['group'] not in wheel_groups and p['transparency']<1 and p['name'] not in {'Wishbone','RearAxle'}]
tires=[p for p in parts if p['name']=='Tire']

def world(part,point):
 return tuple(part['position'][i]+sum(part['rotation'][i*3+j]*point[j] for j in range(3)) for i in range(3))

def local(part,point):
 delta=[point[i]-part['position'][i] for i in range(3)]
 return tuple(sum(part['rotation'][i*3+j]*delta[i] for i in range(3)) for j in range(3))

def surface(part):
 half=[v/2 for v in part['size']]
 if part['shape']=='Ball':
  for latitude in range(-6,7):
   phi=latitude*math.pi/12
   for longitude in range(24):
    theta=longitude*math.tau/24
    yield world(part,(half[0]*math.cos(phi)*math.cos(theta),half[1]*math.sin(phi),half[2]*math.cos(phi)*math.sin(theta)))
 elif part['shape']=='Cylinder':
  for x in (-half[0],0,half[0]):
   for n in range(32):
    theta=n*math.tau/32
    yield world(part,(x,half[1]*math.cos(theta),half[2]*math.sin(theta)))
 else:
  for axis in range(3):
   for sign in (-1,1):
    for u,v in itertools.product((-1,-0.5,0,0.5,1),repeat=2):
     point=[0,0,0];point[axis]=sign*half[axis]
     other=[i for i in range(3) if i!=axis]
     point[other[0]]=u*half[other[0]];point[other[1]]=v*half[other[1]]
     yield world(part,point)

def contains(part,point):
 x,y,z=local(part,point); a,b,c=[v/2 for v in part['size']]
 epsilon=0.0002
 if part['shape']=='Ball':return (x/a)**2+(y/b)**2+(z/c)**2<1-epsilon
 if part['shape']=='Cylinder':return abs(x)<a-epsilon and (y/b)**2+(z/c)**2<1-epsilon
 return abs(x)<a-epsilon and abs(y)<b-epsilon and abs(z)<c-epsilon

for part in body:
 part['_surface']=list(surface(part))
 part['_bounds']=[(min(p[i] for p in part['_surface']),max(p[i] for p in part['_surface'])) for i in range(3)]

cases=0
for tire in tires:
 assert abs(abs(tire['position'][0])-metadata['WheelTrack']/2)<1e-6,"Actual wheel track differs from physics Config"
 assert abs(abs(tire['position'][2])-metadata['Wheelbase']/2)<1e-6,"Actual wheelbase differs from physics Config"
 assert abs(tire['size'][0]-0.76*metadata['Scale'])<1e-6,"Tire width was not remodeled"
 front=tire['group'].startswith('Front')
 angles=[metadata['MaxSteer']*i/4 for i in range(-4,5)] if front else [0]
 # The server supports distance down to -0.2 and full rest+travel droop.
 distances=[-0.2+i*(metadata['Rest']+metadata['Travel']+0.2)/8 for i in range(9)]
 distances.append(metadata['Rest'])
 for angle,distance in itertools.product(angles,distances):
  cases+=1
  cy=tire['position'][1]+metadata['Rest']-distance
  center=(tire['position'][0],cy,tire['position'][2])
  c,s=math.cos(angle),math.sin(angle)
  half=tire['size'][0]/2;radius=tire['size'][1]/2
  extent=(abs(c)*half+abs(s)*radius,radius,abs(s)*half+abs(c)*radius)
  tire_points=[]
  for ax in (-half,0,half):
   for n in range(32):
    phase=n*math.tau/32; y=radius*math.cos(phase);z=radius*math.sin(phase)
    tire_points.append((center[0]+c*ax+s*z,center[1]+y,center[2]-s*ax+c*z))
  for part in body:
   if any(part['_bounds'][i][1]<center[i]-extent[i] or part['_bounds'][i][0]>center[i]+extent[i] for i in range(3)):continue
   for point in part['_surface']:
    dx,dy,dz=[point[i]-center[i] for i in range(3)]
    x=c*dx-s*dz;z=s*dx+c*dz
    assert not(abs(x)<half-0.0002 and dy*dy+z*z<radius*radius-0.0002), f"Visible {part['name']} intersects {tire['group']} at steer {math.degrees(angle):.2f}, suspension distance {distance:.3f}"
   for point in tire_points:
    assert not contains(part,point),f"{tire['group']} intersects visible {part['name']} at steer {math.degrees(angle):.2f}, suspension distance {distance:.3f}"
print(f"PASS: {cases} sampled wheel poses clear visible bodywork across full steering and suspension ranges; actual track, wheelbase and tire width match remodel")
for part in body:
 del part['_surface'];del part['_bounds']

if args.output:
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(parts,separators=(',',':'))+'\n')
