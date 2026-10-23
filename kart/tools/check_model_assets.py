#!/usr/bin/env python3
"""Check committed Blender exports, source hashes and Roblox import budgets."""
from pathlib import Path
import hashlib
import json
import math

root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'dist/KartRemodel.manifest.json').read_text())
source=manifest['source']
assert hashlib.sha256((root/source['path']).read_bytes()).hexdigest()==source['sha256'], 'Blender build source changed without rebuilding assets'
for name,digest in manifest['assets'].items():
    assert hashlib.sha256((root/'dist'/name).read_bytes()).hexdigest()==digest, f'Stale or damaged Blender artifact: {name}'
assert (root/'dist/KartRemodel.fbx').read_bytes().startswith(b'Kaydara FBX Binary'), 'Export is not a binary FBX'
assert (root/'dist/KartRemodel.blend').read_bytes().startswith(b'BLENDER'), 'Native Blender project is missing'
objects=manifest['objects']
required={'MainBody','FrontNose','LeftSidePod','RightSidePod','RearBody','RearBumper','Seat','SteeringWheel','FrontLeftWheel','FrontRightWheel','RearLeftWheel','RearRightWheel','LeftExhaust','RightExhaust','Chassis'}
assert {item['group'] for item in objects}==required, 'Incomplete functional mesh hierarchy'
assert 0<len(objects)<=256 and len({item['name'] for item in objects})==len(objects)
for item in objects:
    assert item['name'].startswith(item['group']+'__') and '__Mat' in item['name']
    assert 0<item['triangles']<10000, item['name']
    for axis in range(3):
        low,high=item['bounds']['min'][axis],item['bounds']['max'][axis]
        assert math.isfinite(low) and math.isfinite(high) and high>low, item['name']
triangles=sum(item['triangles'] for item in objects)
assert triangles==manifest['triangles'] and triangles<35000
assert manifest['max_mesh_triangles']==max(item['triangles'] for item in objects)
assert manifest['model_scale_runtime']==0.84 and manifest['wheel_track']==4.4 and manifest['wheelbase']==4.32
assert manifest['wheel_radius']==0.96 and manifest['wheel_width']==0.76
for name,pivot in manifest['wheel_pivots'].items():
    expected=[-2.2 if 'Left' in name else 2.2,0.4,-2.16 if name.startswith('Front') else 2.16]
    assert pivot==expected, (name,pivot)
assert manifest['alignment_markers']=={'KartOrigin':[0,0,0],'KartForward':[0,0,-4],'KartUp':[0,4,0]}
report=json.loads((root/'dist/KartRemodel.validation.json').read_text())
assert report['status']=='passed' and report['fbx_sha256']==manifest['assets']['KartRemodel.fbx'], 'FBX geometry validation is stale'
assert report['validator_source_sha256']==hashlib.sha256((root/'tools/check_blender_mesh.py').read_bytes()).hexdigest(), 'FBX validator changed without rerunning it'
assert report['fbx_meshes']==len(objects) and report['triangles']==triangles
assert report['swept_tire_poses']>=140 and report['wheel_component_envelopes']>=40
print(f'PASS: Blender source/export hashes, {len(objects)} separate meshes/{triangles} triangles, pivots, dimensions and import budgets')
