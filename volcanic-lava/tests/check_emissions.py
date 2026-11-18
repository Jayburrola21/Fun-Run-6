"""Run the lava emissions module against a small Roblox API test double."""
import argparse
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau", help="Luau CLI executable")
    args = parser.parse_args()
    tests = Path(__file__).resolve().parent
    module = tests.parent / "src/ReplicatedStorage/VolcanicLava/Emissions.luau"
    fixture = (tests / "emissions_fixture.luau").read_text()
    marker = "-- EMISSIONS_MODULE"
    if fixture.count(marker) != 1:
        raise ValueError("Expected exactly one emissions fixture marker")

    # Standalone Luau isolates package globals, so pair the actual source with the fixture.
    with TemporaryDirectory(prefix="lava-emissions-tests-") as directory:
        script = Path(directory) / "emissions.spec.luau"
        script.write_text(fixture.replace(marker, module.read_text()))
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
