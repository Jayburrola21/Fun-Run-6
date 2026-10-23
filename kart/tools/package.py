#!/usr/bin/env python3
"""Build Studio XML files using only Python's standard library. No uploaded assets."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET
import zipfile
from itertools import count

ROOT = Path(__file__).resolve().parents[1]
REFERENTS = count(1)
SOURCES = {
    "KartConfig": ROOT / "src/ReplicatedStorage/KartSystem/KartConfig.luau",
    "KartDynamics": ROOT / "src/ReplicatedStorage/KartSystem/KartDynamics.luau",
    "KartBuilder": ROOT / "src/ReplicatedStorage/KartSystem/KartBuilder.luau",
    "KartSeatLock": ROOT / "src/ReplicatedStorage/KartSystem/KartSeatLock.luau",
    "KartHUD": ROOT / "src/ReplicatedStorage/KartSystem/KartHUD.luau",
    "KartRace": ROOT / "src/ReplicatedStorage/KartSystem/KartRace.luau",
    "KartRaceRules": ROOT / "src/ReplicatedStorage/KartSystem/KartRaceRules.luau",
    "KartCareerWins": ROOT / "src/ReplicatedStorage/KartSystem/KartCareerWins.luau",
    "KartMeshVisuals": ROOT / "src/ReplicatedStorage/KartSystem/KartMeshVisuals.luau",
    "KartPresentation": ROOT / "src/ReplicatedStorage/KartSystem/KartPresentation.luau",
    "KartServer": ROOT / "src/ServerScriptService/KartServer.server.luau",
    "KartController": ROOT / "src/StarterPlayer/StarterPlayerScripts/KartController.client.luau",
}


def item(parent, cls, name):
    element = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{next(REFERENTS)}"})
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
    for name in ("KartConfig", "KartDynamics", "KartBuilder", "KartSeatLock", "KartHUD", "KartRace", "KartRaceRules", "KartCareerWins", "KartMeshVisuals", "KartPresentation"):
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


def color(props, rgb):
    prop = ET.SubElement(props, "Color3", {"name": "Color"})
    for axis, value in zip("RGB", rgb):
        ET.SubElement(prop, axis).text = str(value / 255)


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
    # A real, intentionally simple test route. The minimap uses these exact
    # waypoints, not an unrelated decorative outline.
    course, _ = item(workspace, "Folder", "KartRace")
    path_folder, _ = item(course, "Folder", "Path")
    route = ((0, -35), (32.5, -35), (65, -35), (65, 5), (65, 45), (32.5, 45), (0, 45), (0, 5))
    road_folder, _ = item(workspace, "Folder", "DemoRoad")
    for index, (x, z) in enumerate(route, 1):
        node, node_props = item(path_folder, "Part", str(index))
        vector(node_props, "Size", (1, 1, 1))
        frame(node_props, (x, 0, z))
        ET.SubElement(node_props, "bool", {"name": "Anchored"}).text = "true"
        ET.SubElement(node_props, "bool", {"name": "CanCollide"}).text = "false"
        ET.SubElement(node_props, "float", {"name": "Transparency"}).text = "1"
        nx, nz = route[index % len(route)]
        # Axis-aligned route legs keep this XML test course asset-free.
        road, road_props = item(road_folder, "Part", f"Road{index}")
        vector(road_props, "Size", (abs(nx-x)+18 if nx != x else 18, 0.04, abs(nz-z)+18 if nz != z else 18))
        frame(road_props, ((x+nx)/2, 0.02, (z+nz)/2))
        color(road_props, (48, 52, 59))
        ET.SubElement(road_props, "bool", {"name": "Anchored"}).text = "true"
    markers, _ = item(workspace, "Folder", "KartSpawns")
    for index, name in enumerate(("Red", "Blue", "Green", "Yellow", "Purple", "Black")):
        marker, marker_props = item(markers, "Part", name)
        vector(marker_props, "Size", (1, 1, 1))
        frame(marker_props, (((index % 3)-1)*6, 4, 4+(index//3)*8))
        ET.SubElement(marker_props, "bool", {"name": "Anchored"}).text = "true"
        ET.SubElement(marker_props, "bool", {"name": "CanCollide"}).text = "false"
        ET.SubElement(marker_props, "float", {"name": "Transparency"}).text = "1"
    checkpoints, _ = item(course, "Folder", "Checkpoints")
    for index, position in enumerate(((0, 3, -35), (65, 3, -35), (65, 3, 45), (0, 3, 45)), 1):
        gate, gate_props = item(checkpoints, "Part", str(index))
        vector(gate_props, "Size", (14, 8, 14))
        frame(gate_props, position)
        ET.SubElement(gate_props, "bool", {"name": "Anchored"}).text = "true"
        ET.SubElement(gate_props, "bool", {"name": "CanCollide"}).text = "false"
        ET.SubElement(gate_props, "float", {"name": "Transparency"}).text = "0.88"
    coins, _ = item(course, "Folder", "Coins")
    for index, position in enumerate(((0, 1.5, -15), (65, 1.5, 10)), 1):
        coin, coin_props = item(coins, "Part", f"DemoCoin{index}")
        vector(coin_props, "Size", (0.3, 2, 2))
        frame(coin_props, position)
        ET.SubElement(coin_props, "bool", {"name": "Anchored"}).text = "true"
        ET.SubElement(coin_props, "bool", {"name": "CanCollide"}).text = "false"
        ET.SubElement(coin_props, "token", {"name": "shape"}).text = "2"
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
            if path.is_file() and path.suffix not in (".zip", ".blend1") and "__pycache__" not in path.parts:
                archive.write(path, Path("kart") / path.relative_to(ROOT))
    print(f"Built KartPackage.rbxmx and KartDemo.rbxlx; {len(SOURCES)} scripts round-tripped in each.")


if __name__ == "__main__":
    main()
