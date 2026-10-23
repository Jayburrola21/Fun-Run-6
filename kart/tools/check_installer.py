#!/usr/bin/env python3
"""Execute actual Studio command-bar installer against minimal offline service mocks."""
from pathlib import Path
import argparse, json, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--luau',default='luau'); args=p.parse_args()
def quote(value):
    n=0
    while ']'+('='*n)+']' in value:n+=1
    return '['+'='*n+'['+value+']'+'='*n+']'
sources={path.stem:path.read_text() for path in (root/'src/ReplicatedStorage/KartSystem').glob('*.luau')}
sources['KartServer']=(root/'src/ServerScriptService/KartServer.server.luau').read_text()
sources['KartController']=(root/'src/StarterPlayer/StarterPlayerScripts/KartController.client.luau').read_text()
command=(root/'tools/Upgrade.command.luau').read_text()
assert command==(root/'tools/Install.command.luau').read_text(),'Install/Upgrade entry points diverged'
program='local Sources={'+','.join('['+json.dumps(k)+']='+quote(v) for k,v in sources.items())+'}\nlocal Command='+quote(command)+'\n'
program+=(root/'tests/installer_mock.luau').read_text()+'\n'+(root/'tests/installer.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='kart-install-tests-') as folder:
    path=Path(folder)/'installer.luau'; path.write_text(program)
    subprocess.run([args.luau,str(path)],check=True)
