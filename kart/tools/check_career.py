#!/usr/bin/env python3
"""Execute actual career-win storage code against deterministic task/DataStore doubles."""
from pathlib import Path
import argparse,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument("--luau",default="luau")
args=parser.parse_args()
mock=(root/"tests/career_mock.luau").read_text()
module=(root/"src/ReplicatedStorage/KartSystem/KartCareerWins.luau").read_text()
tests=(root/"tests/career.spec.luau").read_text()
program=mock+"\nlocal Career=(function()\n"+module+"\nend)()\n"+tests
with tempfile.TemporaryDirectory(prefix="kart-career-tests-") as folder:
    path=Path(folder)/"career.luau"; path.write_text(program)
    subprocess.run([args.luau,str(path)],check=True)
