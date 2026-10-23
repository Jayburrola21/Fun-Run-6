#!/usr/bin/env python3
"""Build Studio XML files using only Python's standard library. No uploaded assets."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "KartConfig": ROOT / "src/ReplicatedStorage/KartSystem/KartConfig.luau",
    "KartDynamics": ROOT / "src/ReplicatedStorage/KartSystem/KartDynamics.luau",
    "KartBuilder": ROOT / "src/ReplicatedStorage/KartSystem/KartBuilder.luau",
    "KartSeatLock": ROOT / "src/ReplicatedStorage/KartSystem/KartSeatLock.luau",
    "KartHUD": ROOT / "src/ReplicatedStorage/KartSystem/KartHUD.luau",
    "KartServer": ROOT / "src/ServerScriptService/KartServer.server.luau",
    "KartController": ROOT / "src/StarterPlayer/StarterPlayerScripts/KartController.client.luau",
}


def item(parent, cls, name):
    element = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{name}"})
    props = ET.SubElement(element, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    return element, props


def code(parent, name, disabled=False):
    cls = "Script" if name == "KartServer" else "LocalScript" if name == "KartController" else "ModuleScript"
    element, props = item(parent, cls, name)
    ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = SOURCES[name].read_text()
    if cls != "ModuleScript":
        ET.SubElement(props, "bool", {"name": "Disabled"}).text = str(disabled).lower()
    return element


def system(parent):
    folder, _ = item(parent, "Folder", "KartSystem")
    for name in ("KartConfig", "KartDynamics", "KartBuilder", "KartSeatLock", "KartHUD"):
        code(folder, name)


def document():
    return ET.Element("roblox", {"version": "4"})


def write(root, filename):
    ET.indent(root)
    ET.ElementTree(root).write(ROOT / "dist" / filename, encoding="utf-8", xml_declaration=True)


def vector(props, name, xyz):
    prop = ET.SubElement(props, "Vector3", {"name": name})
    for axis, value in zip("XYZ", xyz):
        ET.SubElement(prop, axis).text = str(value)


def frame(props, xyz):
    prop = ET.SubElement(props, "CoordinateFrame", {"name": "CFrame"})
    for axis, value in zip("XYZ", xyz):
        ET.SubElement(prop, axis).text = str(value)
    for r in range(3):
        for c in range(3):
            ET.SubElement(prop, f"R{r}{c}").text = "1" if r == c else "0"


def main():
    (ROOT / "dist").mkdir(exist_ok=True)
    root = document()
    package, _ = item(root, "Folder", "KartPackage")
    system(package)
    code(package, "KartServer", disabled=True)
    code(package, "KartController", disabled=True)
    write(root, "KartPackage.rbxmx")

    root = document()
    workspace, _ = item(root, "Workspace", "Workspace")
    ground, props = item(workspace, "Part", "KartTestGround")
    vector(props, "Size", (600, 1, 600))
    frame(props, (0, -0.5, 0))
    ET.SubElement(props, "bool", {"name": "Anchored"}).text = "true"
    spawn, props = item(workspace, "SpawnLocation", "PlayerSpawn")
    vector(props, "Size", (6, 1, 6))
    frame(props, (9, 0.5, 6))
    ET.SubElement(props, "bool", {"name": "Anchored"}).text = "true"
    storage, _ = item(root, "ReplicatedStorage", "ReplicatedStorage")
    system(storage)
    server, _ = item(root, "ServerScriptService", "ServerScriptService")
    code(server, "KartServer")
    starter, _ = item(root, "StarterPlayer", "StarterPlayer")
    scripts, _ = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    code(scripts, "KartController")
    write(root, "KartDemo.rbxlx")
    manifest = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in SOURCES.values()}
    (ROOT / "dist/source-hashes.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # Parse serialized artifacts and confirm all embedded source text round-trips.
    for path in (ROOT / "dist").glob("*.rbx*"):
        tree = ET.parse(path)
        scripts = tree.findall(".//ProtectedString[@name='Source']")
        assert len(scripts) == len(SOURCES), path
        assert {s.text for s in scripts} == {p.read_text() for p in SOURCES.values()}, path
        refs = [x.attrib["referent"] for x in tree.findall(".//Item")]
        assert len(refs) == len(set(refs)), path
    with zipfile.ZipFile(ROOT / "dist/KartRelease.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob("*")):
            if path.is_file() and path.suffix != ".zip" and "__pycache__" not in path.parts:
                archive.write(path, Path("kart") / path.relative_to(ROOT))
    print(f"Built KartPackage.rbxmx and KartDemo.rbxlx; {len(SOURCES)} scripts round-tripped in each.")


if __name__ == "__main__":
    main()
