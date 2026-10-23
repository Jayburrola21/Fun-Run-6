#!/usr/bin/env python3
"""Execute actual HUD/config code against an offline GUI data mock, not Roblox.

Optional --api-dump validates the compact checked-in name fixture against a full
Roblox public API dump. Default tests require only Python and the official Luau CLI.
"""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
parser.add_argument('--api-dump', type=Path)
parser.add_argument('--export-graph', type=Path, help='Export actual GUI instances/properties with labeled sample data')
args = parser.parse_args()
fixture = json.loads((ROOT / 'tests/hud_api_properties.json').read_text())['classes']
if args.api_dump:
    api = json.loads(args.api_dump.read_text())
    classes = {item['Name']: item for item in api['Classes']}
    for name, expected in fixture.items():
        props = set()
        item = classes[name]
        while item:
            props.update(member['Name'] for member in item['Members'] if member['MemberType'] == 'Property')
            item = classes.get(item.get('Superclass'))
        assert set(expected) <= props, (name, set(expected) - props)
    print('PASS: compact HUD property fixture matches supplied Roblox API dump', flush=True)
allowed = 'local allowed={' + ','.join(
    '["' + name + '"]={' + ','.join('["' + prop + '"]=true' for prop in props) + '}'
    for name, props in fixture.items()
) + '}\n'
code = allowed + (ROOT / 'tests/hud_mock.luau').read_text()
for name in ('Config', 'HUD'):
    source = ROOT / ('src/ReplicatedStorage/KartSystem/Kart' + name + '.luau')
    code += '\nlocal ' + name + '=(function()\n' + source.read_text() + '\nend)()\n'
code += (ROOT / 'tests/hud.spec.luau').read_text()
if args.export_graph:
    code += '\n' + (ROOT / 'tests/hud_export.luau').read_text()
with tempfile.TemporaryDirectory(prefix='kart-hud-test-') as directory:
    runner = Path(directory) / 'run.luau'
    runner.write_text(code)
    result = subprocess.run([args.luau, str(runner)], check=True, capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith('HUDGRAPH|'):
            args.export_graph.parent.mkdir(parents=True, exist_ok=True)
            args.export_graph.write_text(json.dumps(json.loads(line.split('|', 1)[1]), indent=2) + '\n')
            print('Exported actual GUI graph with sample preview values:', args.export_graph)
        else:
            print(line)
