#!/usr/bin/env python3
"""Execute the real race rules/adapter against deterministic service/geometry doubles."""
from pathlib import Path
import argparse,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument("--luau",default="luau")
args=parser.parse_args()
rules=(root/"src/ReplicatedStorage/KartSystem/KartRaceRules.luau").read_text()
adapter=(root/"src/ReplicatedStorage/KartSystem/KartRace.luau").read_text().replace('local Rules=require(script.Parent.KartRaceRules)',"")
program=(root/"tests/race_mock.luau").read_text()+"\nlocal Rules=(function()\n"+rules+"\nend)()\n"
program+="local Race=(function()\n"+adapter+"\nend)()\n"
program+=(root/"tests/race.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="kart-race-tests-") as folder:
    path=Path(folder)/"race.luau"; path.write_text(program)
    subprocess.run([args.luau,str(path)],check=True)
