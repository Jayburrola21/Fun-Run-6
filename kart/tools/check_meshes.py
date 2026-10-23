#!/usr/bin/env python3
"""Run actual mesh adapter and edit-mode importer in offline geometry doubles."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--luau',default='luau')
args=parser.parse_args()

def quote(text):
    index=0
    while ']'+('='*index)+']' in text:index+=1
    return '['+'='*index+'['+text+']'+'='*index+']'

program=(ROOT/'tests/mesh_mock.luau').read_text()
program+='\nlocal script={Parent=Instance.new("Folder")}\n'
program+='local MeshVisuals=(function()\n'+(ROOT/'src/ReplicatedStorage/KartSystem/KartMeshVisuals.luau').read_text()+'\nend)()\n'
program+='local ImportCommand='+quote((ROOT/'tools/ImportBlender.command.luau').read_text())+'\n'
program+=(ROOT/'tests/mesh.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='kart-mesh-tests-') as directory:
    runner=Path(directory)/'run.luau'
    runner.write_text(program)
    subprocess.run([args.luau,str(runner)],check=True)
