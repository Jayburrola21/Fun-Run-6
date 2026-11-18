"""Run the fire-effects ModuleScript against a small Roblox API test double."""
import argparse
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau", help="Luau CLI executable")
    args = parser.parse_args()

    tests = Path(__file__).resolve().parent
    module = tests.parent / "src/ReplicatedStorage/VolcanicDragon/FireEffects.luau"
    fixture = (tests / "fire_effects_fixture.luau").read_text()
    marker = "-- FIRE_EFFECTS_MODULE"
    if fixture.count(marker) != 1:
        raise ValueError("Expected exactly one FireEffects fixture marker")
    with TemporaryDirectory(prefix="dragon-effects-tests-") as directory:
        combined = Path(directory) / "fire_effects.spec.luau"
        combined.write_text(fixture.replace(marker, module.read_text()))
        subprocess.run([args.luau, str(combined)], check=True)


if __name__ == "__main__":
    main()
