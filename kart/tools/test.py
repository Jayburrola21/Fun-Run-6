#!/usr/bin/env python3
"""Compile every Luau file and execute engine-independent driving tests."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
parser.add_argument("--compiler", default="luau-compile")
args = parser.parse_args()
for path in sorted(ROOT.rglob("*.luau")):
    subprocess.run([args.compiler, "--null", str(path)], check=True, stdout=subprocess.DEVNULL)
print("All Luau source files compiled.", flush=True)
config = (ROOT / "src/ReplicatedStorage/KartSystem/KartConfig.luau").read_text()
dynamics = (ROOT / "src/ReplicatedStorage/KartSystem/KartDynamics.luau").read_text()
tests = (ROOT / "tests/dynamics.spec.luau").read_text()
# Only presentation constructors are stubbed. All numeric tuning is the real Config.
program = 'local Config=(function()\nlocal CFrame={new=function(...) return {...} end}\nlocal Color3={fromRGB=function(...) return {...} end}\n' + config + '\nend)()\n'
program += 'local Dynamics=(function()\n' + dynamics + '\nend)()\n' + tests
with tempfile.TemporaryDirectory(prefix="kart-tests-") as directory:
    path = Path(directory) / "run.luau"
    path.write_text(program)
    subprocess.run([args.luau, str(path)], check=True)
seat_module = (ROOT / "src/ReplicatedStorage/KartSystem/KartSeatLock.luau").read_text()
seat_tests = (ROOT / "tests/seat_lock.spec.luau").read_text()
seat_program = 'local Enum={HumanoidStateType={Jumping="Jumping",GettingUp="GettingUp"}}\n'
seat_program += 'local SeatLock=(function()\n' + seat_module + '\nend)()\n' + seat_tests
with tempfile.TemporaryDirectory(prefix="kart-seat-tests-") as directory:
    path = Path(directory) / "run.luau"
    path.write_text(seat_program)
    subprocess.run([args.luau, str(path)], check=True)
subprocess.run(["python3", str(ROOT / "tools/check_hud.py"), "--luau", args.luau], check=True)
subprocess.run(["python3", str(ROOT / "tools/check_installer.py"), "--luau", args.luau], check=True)
subprocess.run(["python3", str(ROOT / "tools/check_race.py"), "--luau", args.luau], check=True)
subprocess.run(["python3", str(ROOT / "tools/check_geometry.py"), "--luau", args.luau], check=True)
for checker in ("check_presentation.py", "check_meshes.py", "check_career.py"):
    subprocess.run(["python3", str(ROOT / "tools" / checker), "--luau", args.luau], check=True)
subprocess.run(["python3", str(ROOT / "tools/check_model_assets.py")], check=True)
subprocess.run(["python3", str(ROOT / "tools/package.py")], check=True)
