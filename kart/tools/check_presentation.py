#!/usr/bin/env python3
"""Execute the real visual motion module without the Roblox engine."""
from pathlib import Path
import argparse
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--luau',default='luau')
args=parser.parse_args()
source=(root/'src/ReplicatedStorage/KartSystem/KartPresentation.luau').read_text()
tests=(root/'tests/presentation.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='kart-presentation-') as directory:
    runner=Path(directory)/'run.luau'
    runner.write_text('local Presentation=(function()\n'+source+'\nend)()\n'+tests)
    subprocess.run([args.luau,str(runner)],check=True)
