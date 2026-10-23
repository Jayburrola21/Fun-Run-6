#!/usr/bin/env python3
"""Execute the actual builder in a geometry-only Luau mock; optionally export parts."""
from pathlib import Path
import argparse,json,math,subprocess,tempfile
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
print(string.format("META|MaxSteer|%.12f",Config.MaxSteer))
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
  print(string.format("PART|%s|%s|%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%s|%.6f,%.6f,%.6f|%s|%.3f",o.Name,o.ClassName,o.Shape or "Block",o.Size.X,o.Size.Y,o.Size.Z,p.X,p.Y,p.Z,table.concat(o.CFrame.m,","),o.Color.R,o.Color.G,o.Color.B,o.Material,o.Transparency))
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
 _,name,cls,shape,size,pos,matrix,color,material,transparency=line.split('|')
 parts.append(dict(name=name,cls=cls,shape=shape,size=list(map(float,size.split(','))),position=list(map(float,pos.split(','))),rotation=list(map(float,matrix.split(','))),color=list(map(float,color.split(','))),material=material,transparency=float(transparency)))
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

# Conservative contact test using real generated coil segment endpoints and the
# front tire cylinders. Expand the tires by coil tube radius; test each steering
# extreme as well as straight ahead, at the nominal suspension ride height.
coils=[p for p in parts if p['name']=='BlueCoilSpring']
tires=[p for p in parts if p['name']=='Tire' and p['position'][2]<0]
if coils:
 assert len(coils)==64, "Decorative coil segment budget changed"
 for angle in (-metadata['MaxSteer'],0,metadata['MaxSteer']):
  for coil in coils:
   tube=max(coil['size'][1:])/2
   for end in (-0.5,0,0.5):
    point=[coil['position'][i]+coil['rotation'][i*3]*coil['size'][0]*end for i in range(3)]
    for tire in tires:
     dx,dy,dz=[point[i]-tire['position'][i] for i in range(3)]
     x=math.cos(angle)*dx-math.sin(angle)*dz
     z=math.sin(angle)*dx+math.cos(angle)*dz
     assert not(abs(x)<tire['size'][0]/2+tube and math.hypot(dy,z)<tire['size'][1]/2+tube), "Front spring intersects a steered tire"
 print("PASS: 64 decorative coil segments clear front tires at nominal height for straight and both maximum steering angles; rear boost rings begin hidden")

if args.output:
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(parts,separators=(',',':'))+'\n')
