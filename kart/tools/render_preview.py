"""Run in Blender: blender -b --python tools/render_preview.py -- parts.json output.png.
Render geometry exported by check_geometry.py; no Roblox engine/physics is simulated.
"""
import bpy,json,math,sys
from mathutils import Matrix,Vector
args=sys.argv[sys.argv.index('--')+1:]
parts=json.load(open(args[0]))
bpy.ops.wm.read_factory_settings(use_empty=True)
convert=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
materials={}
for part in parts:
 if part['transparency']>=1:continue
 key=tuple(part['color'])+(part['material'],part['name']=='Tire')
 if key not in materials:
  mat=bpy.data.materials.new(part['name']); mat.diffuse_color=(*part['color'],1); mat.use_nodes=True
  shader=mat.node_tree.nodes.get('Principled BSDF'); shader.inputs['Base Color'].default_value=(*(v**2.2 for v in part['color']),1)
  shader.inputs['Metallic'].default_value=.65 if part['material']=='Metal' else .05
  shader.inputs['Roughness'].default_value=.75 if part['name']=='Tire' else .28
  materials[key]=mat
 if part['shape']=='Cylinder':
  vertices=[]
  for x in (-.5,.5):
   for n in range(40):vertices.append((x,.5*math.cos(n*math.tau/40),.5*math.sin(n*math.tau/40)))
  faces=[tuple(range(39,-1,-1)),tuple(range(40,80))]
  faces += [(i,(i+1)%40,(i+1)%40+40,i+40) for i in range(40)]
  mesh=bpy.data.meshes.new(part['name']); mesh.from_pydata(vertices,[],faces)
  obj=bpy.data.objects.new(part['name'],mesh); bpy.context.collection.objects.link(obj)
  for polygon in obj.data.polygons:polygon.use_smooth=len(polygon.vertices)==4
 elif part['shape']=='Ball':
  bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,radius=.5); obj=bpy.context.object
  for polygon in obj.data.polygons:polygon.use_smooth=True
 else:
  bpy.ops.mesh.primitive_cube_add(size=1); obj=bpy.context.object
 obj.name=part['name']; r=part['rotation']; p=part['position']
 transform=Matrix(((r[0],r[1],r[2],p[0]),(r[3],r[4],r[5],p[1]),(r[6],r[7],r[8],p[2]),(0,0,0,1)))
 obj.matrix_world=convert@transform@Matrix.Diagonal((*part['size'],1))
 obj.data.materials.append(materials[key])
 if part['shape']=='Block' and min(part['size'])>.06:
  bevel=obj.modifiers.new('Soft edges','BEVEL'); bevel.width=.035; bevel.segments=2
ground=min(p['position'][1]-p['size'][1]/2 for p in parts if p['name']=='Tire')-0.01
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,ground))
mat=bpy.data.materials.new('Studio floor'); mat.diffuse_color=(.13,.15,.19,1); bpy.context.object.data.materials.append(mat)
world=bpy.data.worlds.new('Studio'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.29,.36,1); world.node_tree.nodes['Background'].inputs[1].default_value=.4; bpy.context.scene.world=world
for location,power,size in [((2,6,10),1800,7),((-6,1,5),1200,6),((2,-6,7),1600,5)]:
 bpy.ops.object.light_add(type='AREA',location=location); light=bpy.context.object; light.data.energy=power; light.data.shape='DISK'; light.data.size=size; light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(10,14,9))
camera=bpy.context.object; camera.rotation_euler=(Vector((0,0,.7))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=11.7
scene=bpy.context.scene; scene.camera=camera; scene.render.engine='CYCLES'; scene.cycles.samples=48; scene.cycles.use_denoising=False
scene.render.resolution_x=1100; scene.render.resolution_y=850; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=args[1]
bpy.ops.render.render(write_still=True)
