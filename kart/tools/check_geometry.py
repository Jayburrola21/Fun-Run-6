#!/usr/bin/env python3
"""Execute the actual builder in a geometry-only Luau mock; optionally export parts."""
from pathlib import Path
import argparse,json,subprocess,tempfile
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
print("PASS: builder executed; "..partCount.." connected parts, positive dimensions, finite frames, massless visual assemblies, four non-colliding visual wheels, COM traction")
'''
with tempfile.TemporaryDirectory(prefix='kart-geometry-') as folder:
 path=Path(folder)/'geometry.luau'; path.write_text(code)
 result=subprocess.run([args.luau,str(path)],text=True,capture_output=True,check=True)
parts=[]
for line in result.stdout.splitlines():
 if not line.startswith('PART|'):
  print(line); continue
 _,name,cls,shape,size,pos,matrix,color,material,transparency=line.split('|')
 parts.append(dict(name=name,cls=cls,shape=shape,size=list(map(float,size.split(','))),position=list(map(float,pos.split(','))),rotation=list(map(float,matrix.split(','))),color=list(map(float,color.split(','))),material=material,transparency=float(transparency)))
if args.output:
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(parts,separators=(',',':'))+'\n')
