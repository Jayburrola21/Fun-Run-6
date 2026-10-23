"""Validate an exported FBX by importing it into a fresh Blender scene.
blender -b --python tools/check_blender_mesh.py -- dist/KartRemodel.fbx
This checks mesh/pivot/marker geometry, not Roblox physics or avatar IK.
"""
import bpy,hashlib,json,math,sys
from pathlib import Path
import numpy as np
from mathutils import Matrix,Vector
path=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(path),use_custom_props=True)
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
groups=['MainBody','FrontNose','LeftSidePod','RightSidePod','RearBody','RearBumper','Seat','SteeringWheel','FrontLeftWheel','FrontRightWheel','RearLeftWheel','RearRightWheel','LeftExhaust','RightExhaust','Chassis']
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
markers={name:bpy.data.objects.get(name) for name in ('KartOrigin','KartForward','KartUp')}
assert all(markers.values()),'FBX alignment markers are missing'
def center(o):return sum((o.matrix_world@Vector(corner) for corner in o.bound_box),Vector())/8
origin=center(markers['KartOrigin']); forward=center(markers['KartForward'])-origin; up=center(markers['KartUp'])-origin
assert abs(forward.length-4)<1e-4 and abs(up.length-4)<1e-4,'Marker unit scale changed'
assert abs(forward.normalized().dot(up.normalized()))<1e-6,'Marker basis is not perpendicular'
for name,p in [('KartOrigin',(0,0,0)),('KartForward',(0,0,-4)),('KartUp',(0,4,0))]:
 assert (C.transposed()@center(markers[name])-Vector(p)).length<1e-4,(name,'axis mismatch')
meshes=[o for o in objects if o not in markers.values()]
assert len(meshes)<=256
for group in groups:assert any(o.name.startswith(group+'__') for o in meshes),('Missing group',group)
triangles=0; points=[]; body_names=[]; wheel_envelopes={}
for o in meshes:
 assert '__Mat' in o.name,(o.name,'material role tag missing')
 o.data.calc_loop_triangles(); count=len(o.data.loop_triangles); triangles+=count
 assert count<10000,(o.name,'Roblox per-mesh triangle budget')
 group=o.name.split('__')[0]
 expected=None
 if group=='SteeringWheel':expected=(0,1.95,-1.05)
 elif group.endswith('Wheel'):
  side=-1 if 'Left' in group else 1; z=-2.16 if group.startswith('Front') else 2.16; expected=(side*2.20,.40,z)
 if expected is not None:
  assert (C.transposed()@o.matrix_world.translation-Vector(expected)).length<1e-4,(o.name,'pivot changed')
 # Surface samples for visible bodywork. Functional axle connections deliberately
 # reach the hubs and are excluded; the body, bumper, sidewalls and seat are not.
 if group.endswith('Wheel') and group!='SteeringWheel':
  pivot=np.array(expected,dtype=np.float64)
  wheel_world=np.array([tuple(C.transposed()@(o.matrix_world@v.co)) for v in o.data.vertices],dtype=np.float64)-pivot
  wheel_envelopes.setdefault(group,[]).append((o.name,float(wheel_world[:,0].min()),float(wheel_world[:,0].max()),float(np.sqrt(wheel_world[:,1]**2+wheel_world[:,2]**2).max())))
  continue
 if 'Wishbone' in o.name:continue
 world=np.array([tuple(C.transposed()@(o.matrix_world@v.co)) for v in o.data.vertices],dtype=np.float64)
 assert np.isfinite(world).all(),o.name
 # Vertices plus triangle centroids and edge midpoints exercise actual loft/bevel
 # geometry, not just centerline bounds or a decorative bounding box assertion.
 ids=np.array([tuple(t.vertices) for t in o.data.loop_triangles],dtype=np.int64)
 tris=world[ids]
 sample=np.concatenate([world,tris.mean(axis=1),(tris[:,0]+tris[:,1])/2,(tris[:,1]+tris[:,2])/2,(tris[:,2]+tris[:,0])/2])
 points.append(sample); body_names.extend([o.name]*len(sample))
assert triangles<35000,triangles
points=np.concatenate(points); body_names=np.array(body_names,dtype=object)
poses=0; minimum_margin=float('inf')
for front in (True,False):
 for side in (-1,1):
  for angle in (np.linspace(-math.radians(29),math.radians(29),9) if front else [0]):
   ca,sa=math.cos(angle),math.sin(angle)
   for height in np.linspace(-.25,1.30,7):
    delta=points-np.array([side*2.2,height,-2.16 if front else 2.16])
    x=ca*delta[:,0]-sa*delta[:,2]; z=sa*delta[:,0]+ca*delta[:,2]
    radial=np.sqrt(delta[:,1]**2+z*z)
    group=('Front' if front else 'Rear')+('LeftWheel' if side<0 else 'RightWheel')
    for wheel_name,xmin,xmax,radius in wheel_envelopes[group]:
     intersects=(x>xmin-.003)&(x<xmax+.003)&(radial<radius+.003)
     assert not intersects.any(),('Visible body intersects a swept wheel component',wheel_name,side,float(angle),float(height),sorted(set(body_names[intersects])))
    poses+=1
report={'fbx_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'validator_source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'fbx_meshes':len(meshes),'triangles':triangles,'markers':'all three present; 4-unit orthogonal basis round-trips','pivots':'all wheel and steering object origins round-trip','swept_tire_poses':poses,'body_surface_samples':len(points),'clearance_margin':.003,'wheel_component_envelopes':sum(len(v) for v in wheel_envelopes.values()),'sweep_geometry':'separate actual FBX wheel-component axial extents and radial envelopes including all rim, brake and hub protrusions','wheel_center_y_test_range':[-.25,1.30],'status':'passed'}
(path.parent/'KartRemodel.validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: FBX round-trip',json.dumps(report))
