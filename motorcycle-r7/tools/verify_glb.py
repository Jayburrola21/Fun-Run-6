"""Check the motorbike GLB's geometry and embedded material maps without Blender."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


EXPECTED_ASSEMBLIES = {
    "Body", "FrontFairing", "FuelTank", "Seats", "FrontWheel", "RearWheel",
    "FrontForks", "Engine", "Frame", "Swingarm", "Chain", "Exhaust",
    "Handlebars", "Cockpit", "Lights", "Details",
}


def load_glb(path):
    content = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", content)
    assert (magic, version, length) == (b"glTF", 2, len(content)), "Invalid GLB header"
    json_size, json_tag = struct.unpack_from("<I4s", content, 12)
    assert json_tag == b"JSON" and json_size % 4 == 0
    binary_offset = 20 + json_size
    binary_size, binary_tag = struct.unpack_from("<I4s", content, binary_offset)
    assert binary_tag == b"BIN\0" and binary_offset + 8 + binary_size == length
    document = json.loads(content[20:binary_offset])
    binary = memoryview(content)[binary_offset + 8:]
    [buffer] = document["buffers"]
    assert "uri" not in buffer and 0 <= len(binary) - buffer["byteLength"] <= 3
    return document, binary


def slice_view(document, binary, index):
    view = document["bufferViews"][index]
    assert view["buffer"] == 0
    start = view.get("byteOffset", 0)
    end = start + view["byteLength"]
    assert 0 <= start < end <= document["buffers"][0]["byteLength"]
    return binary[start:end]


def accessor_values(document, binary, index, shape, component_codes):
    accessor = document["accessors"][index]
    assert accessor["type"] == shape
    code = component_codes[accessor["componentType"]]
    length = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[shape]
    row = struct.Struct("<" + code * length)
    view = accessor["bufferView"]
    stride = document["bufferViews"][view].get("byteStride", row.size)
    start = accessor.get("byteOffset", 0)
    data = slice_view(document, binary, view)
    count = accessor["count"]
    assert count > 0 and stride >= row.size and start + (count - 1) * stride + row.size <= len(data)
    return (row.unpack_from(data, start + i * stride) for i in range(count))


def read_png(data):
    """Read the unfiltered RGB/RGBA PNGs emitted by the embedded-map writer."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    cursor = 8
    payload = []
    width = height = channels = 0
    while cursor < len(data):
        length, kind = struct.unpack_from(">I4s", data, cursor)
        start = cursor + 8
        end = start + length
        checksum, = struct.unpack_from(">I", data, end)
        chunk = data[start:end]
        assert zlib.crc32(chunk, zlib.crc32(kind)) == checksum
        cursor = end + 4
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">2I5B", chunk)
            assert width > 0 and height > 0 and depth == 8 and compression == filtering == interlace == 0
            channels = {2: 3, 6: 4}[color]
        elif kind == b"IDAT":
            payload.append(chunk)
        elif kind == b"IEND":
            assert cursor == len(data)
            break
    assert width and height and channels and payload and kind == b"IEND"
    rows = zlib.decompress(b"".join(payload))
    stride = width * channels + 1
    assert len(rows) == stride * height
    assert all(rows[y * stride] == 0 for y in range(height)), "Expected unfiltered texture rows"
    return [tuple(rows[i:i + channels]) for y in range(height)
            for i in range(y * stride + 1, (y + 1) * stride, channels)]


def verify_materials(document, binary):
    images = []
    for image in document["images"]:
        assert "uri" not in image and image["mimeType"] == "image/png", image
        images.append(read_png(slice_view(document, binary, image["bufferView"])))

    def map_pixels(info):
        assert info.get("texCoord", 0) == 0
        texture = document["textures"][info["index"]]
        return images[texture["source"]]

    materials = {}
    for material in document["materials"]:
        pbr = material["pbrMetallicRoughness"]
        base = map_pixels(pbr["baseColorTexture"])
        finish = map_pixels(pbr["metallicRoughnessTexture"])
        materials[material["name"]] = (material, base, finish)

    assert len(materials) == len(document["materials"]) == 24
    _, paint, paint_finish = materials["paint"]
    _, rotor, rotor_finish = materials["rotor"]
    smoke_material, smoke, _ = materials["smoke"]
    assert max(max(pixel[:3]) for pixel in paint) < 65, "Paint image is not black"
    assert min(min(pixel[:3]) for pixel in rotor) > 145, "Rotor image is not silver"
    assert rotor_finish[0][2] > paint_finish[0][2], "Expected more metallic rotor finish"
    assert smoke_material["alphaMode"] == "BLEND"
    assert len(smoke[0]) == 4 and 55 <= smoke[0][3] < 210, "Windscreen is missing its alpha texture"
    for label in ("rubber", "seat"):
        material, color, finish = materials[label]
        normal = map_pixels(material["normalTexture"])
        assert len(set(normal)) > 10, f"{label} normal texture is flat"
        assert len(set(color)) > 4, f"{label} color texture is flat"
        assert finish[0][1] > paint_finish[0][1], f"{label} is insufficiently rough"
    return len(materials), len(images)


def node_position(node):
    matrix = node.get("matrix")
    return matrix[12:15] if matrix else node.get("translation", (0, 0, 0))


def node_transform(node):
    """Return the world transform for a single root-level glTF mesh."""
    position = node_position(node)
    matrix = node.get("matrix")
    if matrix:
        axes = [matrix[i:i + 3] for i in range(0, 12, 4)]
    else:
        x, y, z, w = node.get("rotation", (0, 0, 0, 1))
        axes = [
            (1 - 2 * (y*y + z*z), 2 * (x*y + w*z), 2 * (x*z - w*y)),
            (2 * (x*y - w*z), 1 - 2 * (x*x + z*z), 2 * (y*z + w*x)),
            (2 * (x*z + w*y), 2 * (y*z - w*x), 1 - 2 * (x*x + y*y)),
        ]
        axes = [tuple(value * scale for value in axis)
                for axis, scale in zip(axes, node.get("scale", (1, 1, 1)))]

    def transform(point):
        return tuple(position[i] + sum(point[j] * axes[j][i] for j in range(3))
                     for i in range(3))

    return transform


def verify_geometry(document, binary):
    nodes = document["nodes"]
    roots = document["scenes"][document.get("scene", 0)]["nodes"]
    assert sorted(roots) == list(range(len(nodes))), "Expected flat, separately named mesh nodes"
    assert len(nodes) == len(document["meshes"])
    assert {node["mesh"] for node in nodes} == set(range(len(nodes)))
    assert len({node["name"] for node in nodes}) == len(nodes)
    lowest = [math.inf] * 3
    highest = [-math.inf] * 3
    triangle_counts = []
    wheel_z = {}
    assemblies = set()
    for node in nodes:
        name = node["name"]
        assert name.startswith("R7_") and "__" in name, name
        assemblies.add(name.split("__", 1)[0].removeprefix("R7_"))
        [primitive] = document["meshes"][node["mesh"]]["primitives"]
        material = document["materials"][primitive["material"]]
        assert name.split("__")[1] == material["name"], (name, material["name"])
        assert primitive.get("mode", 4) == 4
        attributes = primitive["attributes"]
        positions = accessor_values(document, binary, attributes["POSITION"], "VEC3", {5126: "f"})
        indices = list(accessor_values(
            document, binary, primitive["indices"], "SCALAR", {5121: "B", 5123: "H", 5125: "I"},
        ))
        assert len(indices) % 3 == 0 and 0 < len(indices) <= 9_500 * 3
        triangle_counts.append(len(indices) // 3)
        count = document["accessors"][attributes["POSITION"]]["count"]
        assert 0 <= min(indices)[0] <= max(indices)[0] < count
        required_attributes = ("NORMAL", "TEXCOORD_0")
        if "normalTexture" in material:
            required_attributes += ("TANGENT",)
        for attribute in required_attributes:
            assert document["accessors"][attributes[attribute]]["count"] == count, (name, attribute)
        transform = node_transform(node)
        for point in positions:
            for axis, value in enumerate(transform(point)):
                assert math.isfinite(value), name
                lowest[axis] = min(lowest[axis], value)
                highest[axis] = max(highest[axis], value)
        if name in ("R7_FrontWheel__rubber", "R7_RearWheel__rubber"):
            wheel_z[name] = node_position(node)[2]
    assert EXPECTED_ASSEMBLIES <= assemblies, f"Missing assemblies: {EXPECTED_ASSEMBLIES - assemblies}"
    triangles = sum(triangle_counts)
    assert -.002 < lowest[1] < .002, "Expected tires on the Y=0 ground plane"
    assert abs(wheel_z["R7_FrontWheel__rubber"] + .6975) < .0001
    assert abs(wheel_z["R7_RearWheel__rubber"] - .6975) < .0001
    width, height, length = (high - low for low, high in zip(lowest, highest))
    for actual, expected in zip((width, height, length), (.704, 1.16, 2.056)):
        assert abs(actual - expected) < .012, (actual, expected)
    return {
        "mesh_parts": len(nodes),
        "triangles": triangles,
        "largest_mesh_triangles": max(triangle_counts),
        "width_height_length_m": [round(value, 4) for value in (width, height, length)],
        "wheelbase_m": round(wheel_z["R7_RearWheel__rubber"] - wheel_z["R7_FrontWheel__rubber"], 4),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    default = Path(__file__).resolve().parents[1] / "dist" / "Yamaha_R7_Roblox.glb"
    parser.add_argument("glb", type=Path, nargs="?", default=default)
    args = parser.parse_args()
    document, binary = load_glb(args.glb)
    info = verify_geometry(document, binary)
    info["materials"], info["embedded_pngs"] = verify_materials(document, binary)
    info["sha256"] = hashlib.sha256(args.glb.read_bytes()).hexdigest()
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()
