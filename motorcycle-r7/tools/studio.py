"""Studio lighting and orthographic design views for the finished motorcycle."""

import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

import bpy
from mathutils import Matrix, Vector


VIEWS = {
    "three-quarter": ((3.35, -3.60, 1.45), (1200, 900)),
    "front": ((0, -4, .09), (900, 1040)),
    "rear": ((0, 4, .11), (900, 1040)),
    "left": ((4, 0, .04), (1200, 760)),
    "right": ((-4, 0, .04), (1200, 760)),
    "top": ((0, 0, 4), (1200, 720)),
}


def studio():
    scene = bpy.context.scene
    group = bpy.data.collections.new("Studio Preview")
    scene.collection.children.link(group)

    world = bpy.data.worlds.new("Studio ambient")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.31, .40, .53, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .27
    scene.world = world

    from common import material, mesh
    floor = material("Studio cyclorama", (.055, .067, .085), 0, .66)
    mesh("Ground", [(-200, -200, -.003), (200, -200, -.003),
                    (200, 200, -.003), (-200, 200, -.003)],
         [(0, 1, 2, 3)], floor, group)

    def softbox(name, location, target, energy, size, color, width=None):
        light = bpy.data.lights.new(name, 'AREA')
        light.energy = energy
        light.color = color
        light.shape = 'RECTANGLE' if width else 'DISK'
        light.size = size
        if width:
            light.size_y = width
        obj = bpy.data.objects.new(name, light)
        group.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

    softbox("Overhead strip", (0, -.15, 2.7), (0, 0, .46), 330, 3.6,
            (.92, .96, 1), 1.03)
    softbox("Left key", (-2.0, -.45, 1.75), (0, -.12, .45), 240, 2.6,
            (.88, .94, 1), 1.36)
    softbox("Right rim", (1.75, .52, 1.52), (0, 0, .66), 210, 2.9,
            (.78, .88, 1), .64)
    softbox("Warm front bounce", (.55, -2.6, 1.18), (0, -.30, .52), 100, 1.5,
            (1, .90, .77), .85)
    softbox("Rear edge", (-.32, 2.5, 1.45), (0, .37, .59), 145, 1.5,
            (1, .89, .80), .56)

    camera = bpy.data.objects.new("Preview Camera", bpy.data.cameras.new("Preview Lens"))
    group.objects.link(camera)
    scene.camera = camera
    camera.data.type = 'ORTHO'
    camera.data.clip_end = 350

    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 80
    scene.cycles.adaptive_threshold = .026
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 6
    scene.cycles.transparent_max_bounces = 6
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.view_settings.exposure = -.45
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGB'
    scene.render.film_transparent = False
    return camera


def aim(camera, name, bounds, percent=100):
    offset, (width, height) = VIEWS[name]
    backward = Vector(offset).normalized()
    approx_up = Vector((1, 0, 0) if name == "top" else (0, 0, 1))
    right = approx_up.cross(backward).normalized()
    up = backward.cross(right)
    local_x = [right.dot(point) for point in bounds]
    local_y = [up.dot(point) for point in bounds]
    center = (right * ((max(local_x) + min(local_x)) / 2)
              + up * ((max(local_y) + min(local_y)) / 2))
    camera.location = center + backward * 78
    camera.rotation_euler = Matrix((right, up, backward)).transposed().to_euler()
    aspect = width / height
    span_x = max(local_x) - min(local_x)
    span_y = max(local_y) - min(local_y)
    # Blender's orthographic scale is the span of the larger image axis.
    span = max(span_x, span_y * aspect) if aspect >= 1 else max(span_x / aspect, span_y)
    camera.data.ortho_scale = 1.21 * span
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = percent


def denoised_render(scene, destination, executable):
    """Preserve scene-linear HDR values through the optional external RT denoiser."""
    import numpy as np

    with TemporaryDirectory(prefix="r7-render-") as temp:
        scratch = Path(temp)
        scene.render.image_settings.file_format = 'OPEN_EXR'
        scene.render.image_settings.color_mode = 'RGB'
        scene.render.image_settings.color_depth = '32'
        scene.render.filepath = str(scratch / "source.exr")
        bpy.ops.render.render(write_still=True)
        source = bpy.data.images.load(scene.render.filepath, check_existing=False)
        width, height = source.size
        pixels = np.empty(width * height * 4, dtype=np.float32)
        source.pixels.foreach_get(pixels)
        records = pixels.reshape(height, width, 4)
        with (scratch / "source.pfm").open("wb") as stream:
            stream.write(f"PF\n{width} {height}\n-1.0\n".encode("ascii"))
            records[:, :, :3].astype("<f4").tofile(stream)
        bpy.data.images.remove(source)
        subprocess.run([
            str(executable), "--device", "cpu", "--threads", "4", "--hdr",
            str(scratch / "source.pfm"), "-o", str(scratch / "filtered.pfm"),
        ], check=True)
        with (scratch / "filtered.pfm").open("rb") as stream:
            if stream.readline().strip() != b"PF" or tuple(map(int, stream.readline().split())) != (width, height):
                raise ValueError("Unexpected RGB dimensions from denoiser")
            endian = "<" if float(stream.readline()) < 0 else ">"
            records[:, :, :3] = np.fromfile(stream, dtype=endian + "f4").reshape(height, width, 3)
        records[:, :, 3] = 1
        output = bpy.data.images.new("Denoised preview", width, height, float_buffer=True)
        output.pixels.foreach_set(pixels)
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_depth = '8'
        output.save_render(str(destination), scene=scene)
        bpy.data.images.remove(output)


def render_views(camera, views, points, destination, draft=False, denoiser=None):
    destination.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    if draft:
        scene.cycles.samples = 16
    elif denoiser:
        scene.cycles.samples = 36
        scene.cycles.adaptive_threshold = .045
    for name in views:
        aim(camera, name, points, 55 if draft else 100)
        path = destination / f"R7_{name}.png"
        if denoiser:
            denoised_render(scene, path, denoiser)
        else:
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
