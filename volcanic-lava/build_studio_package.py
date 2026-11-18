"""Generate the Edit-mode installer and an isolated Roblox Studio demo place."""
from itertools import count
from math import cos, sin
from pathlib import Path
import random
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
MODULES = ROOT / "src/ReplicatedStorage/VolcanicLava"
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/VolcanicLavaClient.client.luau"
SOURCES = [(name, "ModuleScript", MODULES / f"{name}.luau") for name in (
    "Config", "Surface", "MoltenTexture", "Emissions",
)] + [("VolcanicLavaClient", "LocalScript", CLIENT)]

INSTALL_START = """-- Generated Studio installer for Volcanic Lava. Paste the entire file in Studio's Edit-mode Command Bar.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the Volcanic Lava installer before pressing Play.")

local entries = {
"""
INSTALL_END = """}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local owned = "VolcanicLavaPackage"
local folder = ReplicatedStorage:FindFirstChild("VolcanicLava")
if folder then
	assert(folder:IsA("Folder") and folder:GetAttribute(owned), "ReplicatedStorage.VolcanicLava already belongs to another installation.")
end
for _, entry in entries do
	local parent = if entry.kind == "ModuleScript" then folder else StarterPlayerScripts
	local existing = parent and parent:FindFirstChild(entry.name)
	if existing then
		assert(existing.ClassName == entry.kind and existing:GetAttribute(owned),
			"Cannot overwrite existing " .. existing:GetFullName())
	end
end
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "VolcanicLava"
	folder:SetAttribute(owned, true)
	folder.Parent = ReplicatedStorage
end
for _, entry in entries do
	local parent = if entry.kind == "ModuleScript" then folder else StarterPlayerScripts
	local existing = parent:FindFirstChild(entry.name)
	local object = existing or Instance.new(entry.kind)
	object.Name = entry.name
	-- Keep local defaults edited in Studio when tagging another pool.
	if not existing or entry.name ~= "Config" then
		object.Source = entry.code
	end
	object:SetAttribute(owned, true)
	if entry.kind == "LocalScript" then
		object.Enabled = true
	end
	object.Parent = parent
end

local selected = 0
for _, instance in game:GetService("Selection"):Get() do
	if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
		CollectionService:AddTag(instance, "VolcanicLava")
		selected += 1
	end
end
print(("Volcanic Lava installed. Selected pools tagged: %d. Press Play to see the effect."):format(selected))
if selected == 0 then
	print("To add a pool, select its Part and add the VolcanicLava tag in Properties, or select it and rerun this installer.")
end
"""


def literal(text):
    equals = ""
    while f"]{equals}]" in text:
        equals += "="
    return f"[{equals}[{text}]{equals}]"


def installer():
    content = [INSTALL_START]
    for name, kind, path in SOURCES:
        content.append(f'\t{{ name = "{name}", kind = "{kind}", code = {literal(path.read_text())} }},\n')
    content.append(INSTALL_END)
    (ROOT / "InstallVolcanicLava.command.luau").write_text("".join(content))


IDS = count(1)


def property(parent, kind, name, value):
    field = ET.SubElement(parent, kind, {"name": name})
    field.text = str(value)
    return field


def item(parent, cls, name):
    obj = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{next(IDS)}"})
    props = ET.SubElement(obj, "Properties")
    property(props, "string", "Name", name)
    return obj, props


def vector(parent, name, values):
    obj = ET.SubElement(parent, "Vector3", {"name": name})
    for axis, value in zip("XYZ", values):
        ET.SubElement(obj, axis).text = str(value)


def rgb(parent, name, values):
    obj = ET.SubElement(parent, "Color3", {"name": name})
    for axis, value in zip("RGB", values):
        ET.SubElement(obj, axis).text = str(value / 255)


def frame(parent, xyz, yaw=0.):
    obj = ET.SubElement(parent, "CoordinateFrame", {"name": "CFrame"})
    for axis, value in zip("XYZ", xyz):
        ET.SubElement(obj, axis).text = str(value)
    values = (cos(yaw), 0., sin(yaw), 0., 1., 0., -sin(yaw), 0., cos(yaw))
    for index, value in enumerate(values):
        ET.SubElement(obj, f"R{index // 3}{index % 3}").text = str(value)


def part(parent, name, pos, size, color, material, *, yaw=0., cls="Part"):
    obj, props = item(parent, cls, name)
    vector(props, "size", size)
    frame(props, pos, yaw)
    red, green, blue = color
    argb = 0xFF000000 | red << 16 | green << 8 | blue
    property(props, "Color3uint8", "Color3uint8", argb)
    property(props, "token", "Material", material)
    property(props, "bool", "Anchored", "true")
    return props


def source(parent, cls, name, path):
    _, props = item(parent, cls, name)
    property(props, "ProtectedString", "Source", path.read_text())


def demo():
    doc = ET.Element("roblox", {"version": "4"})
    world, _ = item(doc, "Workspace", "Workspace")
    model, _ = item(world, "Model", "VolcanicLavaDemo")
    basalt, cracked = 788, 804
    part(model, "Volcanic floor", (0, -1, 0), (250, 1, 250), (21, 19, 24), basalt)
    part(model, "MainPool", (0, -.29, 0), (61, .6, 34), (55, 25, 19), cracked)
    part(model, "SidePool", (38.1, -.27, -6), (11.5, .56, 18), (45, 16, 14), cracked)
    part(model, "Basalt walkway", (0, -.36, 25), (69, .65, 12), (34, 30, 32), basalt)
    spawn = part(world, "SpawnLocation", (0, .1, 33), (9, .22, 8), (40, 34, 34), basalt, cls="SpawnLocation")
    property(spawn, "float", "Transparency", "1")
    property(spawn, "int", "Duration", "0")

    edge, _ = item(model, "Folder", "Cooling basalt shoreline")
    palette = ((26, 22, 25), (32, 27, 30), (37, 29, 30), (22, 21, 25), (39, 32, 34))
    rng = random.Random(22719)
    for center, count_along, direction in (
        ((0, 17.8), 19, (1, 0)), ((0, -17.9), 19, (1, 0)),
        ((-31.1, 0), 10, (0, 1)), ((30.9, 0), 10, (0, 1)),
    ):
        for index in range(count_along):
            step = (index - (count_along - 1) * .5) * 3.30
            x, z = (c + d * step + rng.uniform(-.39, .39) for c, d in zip(center, direction))
            h = rng.uniform(.45, 1.10)
            dims = ((rng.uniform(2.9, 4.6), h, rng.uniform(1.6, 3.3)) if direction[0]
                    else (rng.uniform(1.5, 3.1), h, rng.uniform(2.6, 4.4)))
            part(edge, f"Slumped shore {len(edge)}", (x, h * .28 - .31, z), dims, rng.choice(palette), basalt,
                 yaw=rng.uniform(-.4, .4), cls=rng.choice(("WedgePart", "Part", "Part")))
    for index in range(19):
        x = -55 + index * 6.6 + rng.uniform(-2, 2)
        z = rng.uniform(-46, -31)
        height = rng.uniform(4, 12) + (4 if abs(x) > 24 else 0)
        part(edge, f"Basalt spire {index + 1}", (x, height * .48 - .7, z), (rng.uniform(4, 9), height, rng.uniform(5, 10)),
             rng.choice(palette), basalt, yaw=rng.uniform(-1.1, .8), cls=rng.choice(("WedgePart", "CornerWedgePart")))

    lighting, light = item(doc, "Lighting", "Lighting")
    property(light, "string", "TimeOfDay", "18:51:00")
    property(light, "float", "Brightness", "1.35")
    property(light, "float", "EnvironmentDiffuseScale", ".48")
    property(light, "float", "EnvironmentSpecularScale", ".50")
    property(light, "float", "ExposureCompensation", ".02")
    rgb(light, "Ambient", (31, 29, 38))
    rgb(light, "OutdoorAmbient", (58, 51, 59))
    _, atmosphere = item(lighting, "Atmosphere", "Caldera Atmosphere")
    property(atmosphere, "float", "Density", ".27")
    property(atmosphere, "float", "Haze", "1.18")
    rgb(atmosphere, "Color", (150, 124, 113))
    rgb(atmosphere, "Decay", (72, 53, 57))

    storage, _ = item(doc, "ReplicatedStorage", "ReplicatedStorage")
    modules, _ = item(storage, "Folder", "VolcanicLava")
    server, _ = item(doc, "ServerScriptService", "ServerScriptService")
    starters, _ = item(doc, "StarterPlayer", "StarterPlayer")
    scripts, _ = item(starters, "StarterPlayerScripts", "StarterPlayerScripts")
    for name, cls, path in SOURCES:
        source(modules if cls == "ModuleScript" else scripts, cls, name, path)
    source(server, "Script", "DemoTag", ROOT/"demo/DemoTag.server.luau")
    source(scripts, "LocalScript", "DemoCamera", ROOT/"demo/DemoCamera.client.luau")
    ET.indent(doc)
    path = ROOT / "VolcanicLavaDemo.rbxlx"
    ET.ElementTree(doc).write(path, encoding="utf-8", xml_declaration=True)
    embedded = {field.text for field in ET.parse(path).findall(".//ProtectedString[@name='Source']")}
    assert len(embedded) == len(SOURCES) + 2
    assert all(path.read_text() in embedded for _, _, path in SOURCES)


if __name__ == "__main__":
    installer()
    demo()
