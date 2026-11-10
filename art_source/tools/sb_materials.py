"""Build the shared Spacebounds material library (art_source/materials/sb_materials.blend).

Run headless from the repository root:
    blender -b --factory-startup --python art_source/tools/sb_materials.py

The materials are marked as assets. Add art_source/materials to
Preferences > File Paths > Asset Libraries, then drag materials from the
Asset Browser with the "Append (Reuse Data)" import method.
"""

import os

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
LIBRARY_DIR = os.path.normpath(os.path.join(HERE, "..", "materials"))
TEXTURE_DIR = os.path.join(LIBRARY_DIR, "textures")
LIBRARY_PATH = os.path.join(LIBRARY_DIR, "sb_materials.blend")


def linear(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]


def save_image(name, pixels, colorspace, file_format):
    height, width, _ = pixels.shape
    image = bpy.data.images.new(name, width, height, alpha=False)
    rgba = np.ones((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = pixels
    image.pixels.foreach_set(rgba.ravel())
    extension = "jpg" if file_format == "JPEG" else "png"
    path = os.path.join(TEXTURE_DIR, "%s.%s" % (name, extension))
    image.file_format = file_format
    image.save(filepath=path, quality=92)
    image.filepath = path
    image.colorspace_settings.name = colorspace
    image.pack()
    return image


def srgb_pixels(hex_color):
    return np.array([int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def solar_cell_texture(size=512, cells=4):
    """Deep blue cells with silver finger lines, busbars and gaps. One tile is 4 x 4 cells."""
    rng = np.random.default_rng(7)
    cell = size // cells
    image = np.empty((size, size, 3), dtype=np.float32)
    image[:] = srgb_pixels("c3c8ce")
    blue = srgb_pixels("132a5c")
    finger = srgb_pixels("4b5f86")
    busbar = srgb_pixels("b4bac2")
    for row in range(cells):
        for col in range(cells):
            y0, x0 = row * cell + 3, col * cell + 3
            y1, x1 = (row + 1) * cell - 3, (col + 1) * cell - 3
            image[y0:y1, x0:x1] = blue * rng.uniform(0.9, 1.08)
            image[y0:y1:8, x0:x1] = finger
            for fraction in (1 / 3, 2 / 3):
                x = col * cell + int(cell * fraction)
                image[y0:y1, x - 1:x + 1] = busbar
    return image


def crinkle_normal_texture(size=512):
    """Tileable faceted normal map: two layers of randomly tilted Voronoi facets."""
    rng = np.random.default_rng(11)
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    normal = np.zeros((size, size, 3), dtype=np.float32)
    for count, tilt, weight in ((70, 0.35, 0.6), (380, 0.25, 0.4)):
        points = rng.uniform(0, size, (count, 2)).astype(np.float32)
        angle = rng.uniform(0, 2 * np.pi, count)
        amount = rng.uniform(0, tilt, count)
        facets = np.stack([np.cos(angle) * amount, np.sin(angle) * amount, np.ones(count)], axis=1)
        nearest = np.empty((size, size), dtype=np.int32)
        for start in range(0, size, 8):
            dy = np.abs(ys[start:start + 8, :, None] - points[None, None, :, 1])
            dx = np.abs(xs[start:start + 8, :, None] - points[None, None, :, 0])
            dy = np.minimum(dy, size - dy)
            dx = np.minimum(dx, size - dx)
            nearest[start:start + 8] = np.argmin(dx * dx + dy * dy, axis=2)
        normal += facets[nearest] * weight
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    return normal * 0.5 + 0.5


def nozzle_texture(size=256):
    """Dark metal that warms to a burnt bronze rim. V = 0 at the throat, V = 1 at the exit rim."""
    v = np.linspace(0.0, 1.0, size, dtype=np.float32)[:, None, None]
    metal = srgb_pixels("3b3d42")
    burnt = srgb_pixels("6e4a32")
    heat = np.clip((v - 0.72) / 0.28, 0.0, 1.0) ** 1.5
    column = metal * (1 - heat) + burnt * heat
    column = np.where(v > 0.975, srgb_pixels("8a8f96"), column)
    return np.broadcast_to(column, (size, size, 3)).copy()


def principled(name, color=None, metallic=0.0, roughness=0.5, color_image=None, normal_image=None, normal_strength=1.0):
    material = bpy.data.materials.new(name)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if color:
        bsdf.inputs["Base Color"].default_value = linear(color) + [1.0]
    if color_image:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = color_image
        texture.location = (-420, 260)
        links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    if normal_image:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = normal_image
        texture.location = (-620, -260)
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = normal_strength
        normal_map.location = (-300, -260)
        links.new(texture.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    material.use_fake_user = True
    material.asset_mark()
    return material


def build():
    os.makedirs(TEXTURE_DIR, exist_ok=True)
    for datablocks in (bpy.data.materials, bpy.data.images, bpy.data.meshes, bpy.data.objects):
        for block in list(datablocks):
            datablocks.remove(block)
    solar = save_image("sb_solar_cell_color", solar_cell_texture(), "sRGB", "JPEG")
    crinkle = save_image("sb_mli_normal", crinkle_normal_texture(), "Non-Color", "PNG")
    nozzle = save_image("sb_nozzle_color", nozzle_texture(), "sRGB", "JPEG")
    principled("sb_white_paint", "e9e7e1", roughness=0.6)
    principled("sb_black_composite", "1c1d20", roughness=0.5)
    principled("sb_mli_gold", "c9a23a", metallic=1.0, roughness=0.35, normal_image=crinkle)
    principled("sb_mli_silver", "c8ccd0", metallic=1.0, roughness=0.35, normal_image=crinkle)
    principled("sb_solar_cell", roughness=0.25, color_image=solar)
    principled("sb_aluminium", "b9bdc2", metallic=1.0, roughness=0.4)
    principled("sb_nozzle", metallic=1.0, roughness=0.45, color_image=nozzle)
    principled("sb_black_anodised", "141518", roughness=0.7)
    principled("sb_glass_lens", "05070a", roughness=0.05)
    bpy.ops.wm.save_as_mainfile(filepath=LIBRARY_PATH, compress=True)
    print("Saved %s with %d materials" % (LIBRARY_PATH, len(bpy.data.materials)))


if __name__ == "__main__":
    build()
