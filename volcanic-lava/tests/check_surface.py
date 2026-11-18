"""Check the actual surface module against mock Roblox geometry and bulk moves."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--luau", default="luau")
    executable = args.parse_args().luau
    fixture = Path(__file__).with_name("surface_fixture.luau").read_text()
    module = (ROOT / "src/ReplicatedStorage/VolcanicLava/Surface.luau").read_text()
    with tempfile.TemporaryDirectory() as directory:
        script = Path(directory) / "surface_check.luau"
        script.write_text(fixture.replace("-- MODULE_SURFACE", module))
        subprocess.run([executable, str(script)], check=True)


if __name__ == "__main__":
    main()
