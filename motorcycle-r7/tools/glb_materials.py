"""Embed portable PBR texture maps in the R7 GLB for texture-based importers."""

import json
import math
import random
import struct
import zlib


def read_glb(path):
    raw = path.read_bytes()
    if struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
        raise ValueError("Expected a glTF 2.0 binary file")
    json_size, tag = struct.unpack_from("<I4s", raw, 12)
    if tag != b"JSON":
        raise ValueError("Missing GLB JSON chunk")
    end = 20 + json_size
    bin_size, tag = struct.unpack_from("<I4s", raw, end)
    if tag != b"BIN\0" or end + 8 + bin_size != len(raw):
        raise ValueError("Missing or invalid GLB binary chunk")
    return json.loads(raw[20:end]), bytearray(raw[end + 8:])


def png(width, height, channels, pixels):
    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload)))
    stride = width * channels
    scanlines = b"".join(b"\0" + pixels[i:i + stride] for i in range(0, len(pixels), stride))
    header = struct.pack(">IIBBBBB", width, height, 8, 6 if channels == 4 else 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(scanlines, 9)) + chunk(b"IEND", b""))


def byte(value):
    return round(255 * max(0, min(value, 1)))


def srgb(linear):
    return 12.92 * linear if linear < .0031308 else 1.055 * linear ** (1 / 2.4) - .055


def material_pixels(name, color):
    if name not in ("rubber", "seat"):
        return 4, bytes([*(byte(srgb(value)) for value in color[:3]), byte(color[3])]) * 16, None

    # Periodic relief for the molded rubber and fine-grained vinyl upholstery.
    size = 128
    noise = random.Random(7 if name == "rubber" else 27)
    height = [[noise.uniform(-1, 1) for _ in range(size)] for _ in range(size)]
    albedo, normal_map = bytearray(), bytearray()
    strength = .072 if name == "rubber" else .115
    for y in range(size):
        for x in range(size):
            brightness = 1 + .10 * height[y][x]
            albedo.extend([*(byte(srgb(value * brightness)) for value in color[:3]), 255])
            nx = strength * (height[y][(x-1) % size] - height[y][(x+1) % size])
            ny = strength * (height[(y+1) % size][x] - height[(y-1) % size][x])
            length = math.sqrt(nx * nx + ny * ny + 1)
            normal_map.extend(byte(.5 + .5 * axis / length) for axis in (nx, ny, 1))
    return size, albedo, normal_map


def keep_required_tangents(document, binary):
    """Keep the Blender tangent basis on primitives that receive a normal map."""
    primitives = [part for mesh in document["meshes"] for part in mesh["primitives"]]
    accessors = document["accessors"]
    used = set()
    for part in primitives:
        name = document["materials"][part["material"]]["name"]
        if name not in ("rubber", "seat"):
            part["attributes"].pop("TANGENT", None)
        used.add(part["indices"])
        used.update(part["attributes"].values())

    order = sorted(used)
    accessor_map = {old: new for new, old in enumerate(order)}
    document["accessors"] = [accessors[index] for index in order]
    for part in primitives:
        part["indices"] = accessor_map[part["indices"]]
        part["attributes"] = {key: accessor_map[index] for key, index in part["attributes"].items()}

    references = document["accessors"] + document.get("images", [])
    views = document["bufferViews"]
    view_map = {}
    compact = bytearray()
    new_views = []
    for item in references:
        old = item.get("bufferView")
        if old is None:
            continue
        if old not in view_map:
            view_map[old] = len(new_views)
            view = views[old]
            offset = view.get("byteOffset", 0)
            compact.extend(b"\0" * (-len(compact) % 4))
            new_views.append({**view, "byteOffset": len(compact)})
            compact.extend(binary[offset:offset + view["byteLength"]])
        item["bufferView"] = view_map[old]
    document["bufferViews"] = new_views
    return compact


def write_material_glb(source, destination):
    document, binary = read_glb(source)
    binary = keep_required_tangents(document, binary)
    images = document.setdefault("images", [])
    textures = document.setdefault("textures", [])
    views = document["bufferViews"]

    def add_map(name, payload):
        binary.extend(b"\0" * (-len(binary) % 4))
        views.append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload)})
        images.append({"name": name, "mimeType": "image/png", "bufferView": len(views) - 1})
        textures.append({"name": name, "source": len(images) - 1})
        binary.extend(payload)
        return {"index": len(textures) - 1}

    for material in document["materials"]:
        name = material["name"]
        pbr = material.setdefault("pbrMetallicRoughness", {})
        color = pbr.pop("baseColorFactor", [1, 1, 1, 1])
        size, albedo, normals = material_pixels(name, color)
        pbr["baseColorTexture"] = add_map(f"{name}_color", png(size, size, 4, albedo))
        packed = bytes([255, byte(pbr.pop("roughnessFactor", 1)), byte(pbr.pop("metallicFactor", 1))])
        pbr["metallicRoughnessTexture"] = add_map(f"{name}_metal_rough", png(4, 4, 3, packed * 16))
        if normals is not None:
            material["normalTexture"] = add_map(f"{name}_grain", png(size, size, 3, normals))
        if color[3] < 1:
            material["alphaMode"] = "BLEND"
            material.pop("alphaCutoff", None)

    binary.extend(b"\0" * (-len(binary) % 4))
    document["buffers"][0]["byteLength"] = len(binary)
    metadata = json.dumps(document, separators=(",", ":")).encode("utf-8")
    metadata += b" " * (-len(metadata) % 4)
    with destination.open("wb") as stream:
        stream.write(struct.pack("<4sII", b"glTF", 2, 28 + len(metadata) + len(binary)))
        stream.write(struct.pack("<I4s", len(metadata), b"JSON"))
        stream.write(metadata)
        stream.write(struct.pack("<I4s", len(binary), b"BIN\0"))
        stream.write(binary)
