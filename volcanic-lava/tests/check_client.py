"""Run the actual Config and client scheduler against Luau service fixtures."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    script = Path(__file__).with_name("client_fixture.luau").read_text()
    for label, relative in (
        ("CONFIG", "ReplicatedStorage/VolcanicLava/Config.luau"),
        ("CLIENT", "StarterPlayer/StarterPlayerScripts/VolcanicLavaClient.client.luau"),
    ):
        script = script.replace(f"-- MODULE_{label}", (ROOT/"src"/relative).read_text())
    with tempfile.TemporaryDirectory() as directory:
        test = Path(directory)/"check.luau"
        test.write_text(script)
        subprocess.run([args.luau, str(test)], check=True)


if __name__ == "__main__":
    main()
