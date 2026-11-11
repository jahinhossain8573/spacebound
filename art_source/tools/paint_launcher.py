"""Paint the Electron or Falcon 9 game GLB using cylindrical 4K livery maps.

Usage: python3 paint_launcher.py electron|falcon9 input.glb output.glb
Requires Pillow. The input is a clean geometry export.
"""
import argparse
from copy import deepcopy
import io
import json
import math
from pathlib import Path
import random
import struct

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 2048, 4096
DECALS = Path(__file__).resolve().parents[1] / "launchers" / "decals"
FONT = Path(__file__).resolve().parents[2] / "assets/fonts/share_tech_mono/ShareTechMono-Regular.ttf"


def star(x, y, radius):
    return [
        (x + math.sin(i * math.pi / 5) * radius * (1 if i % 2 == 0 else 0.4),
         y - math.cos(i * math.pi / 5) * radius * (1 if i % 2 == 0 else 0.4))
        for i in range(10)
    ]


def flag(us):
    image = Image.new("RGB", (360, 190 if us else 180), "#012169")
    draw = ImageDraw.Draw(image)
    if us:
        for i in range(13):
            draw.rectangle((0, round(i * 190 / 13), 360, round((i + 1) * 190 / 13)),
                           "#b22234" if i % 2 == 0 else "#f8f7f4")
        draw.rectangle((0, 0, 144, 102), "#3c3b6e")
        for row in range(9):
            for column in range(6 - row % 2):
                draw.polygon(star(12 + 24 * column + 12 * (row % 2), 10 + 10.4 * row, 3.4), "#faf9f6")
    else:
        jack = Image.new("RGB", (180, 90), "#012169")
        union = ImageDraw.Draw(jack)
        for line in [(0, 0, 180, 90), (0, 90, 180, 0)]:
            union.line(line, "#ffffff", 16)
            union.line(line, "#c8102e", 6)
        union.line((0, 45, 180, 45), "#ffffff", 27)
        union.line((90, 0, 90, 90), "#ffffff", 27)
        union.line((0, 45, 180, 45), "#c8102e", 15)
        union.line((90, 0, 90, 90), "#c8102e", 15)
        image.paste(jack)
        for x, y, radius in [(274, 42, 12), (240, 82, 11), (305, 73, 9), (274, 139, 13)]:
            draw.polygon(star(x, y, radius), "#ffffff")
            draw.polygon(star(x, y, radius * 0.73), "#cc142b")
    return image


def label(text, color, stacked=False):
    font = ImageFont.truetype(str(FONT), 100)
    if not stacked:
        left, top, right, bottom = font.getbbox(text)
        image = Image.new("RGBA", (right - left, bottom - top))
        ImageDraw.Draw(image).text((-left, -top), text, fill=color, font=font)
        return image
    letters = [label(letter, color) for letter in text]
    width = max(letter.width for letter in letters)
    image = Image.new("RGBA", (width, (len(letters) - 1) * 125 + max(letter.height for letter in letters)))
    for index, letter in enumerate(letters):
        image.paste(letter, ((width - letter.width) // 2, index * 125))
    return image


def atom_mark():
    image = Image.new("RGBA", (320, 320))
    for angle in (0, 60, 120):
        orbit = Image.new("RGBA", image.size)
        draw = ImageDraw.Draw(orbit)
        draw.ellipse((36, 112, 284, 208), outline="#d0d4d7", width=8)
        draw.ellipse((239, 116, 258, 135), fill="#d0d4d7")
        image.alpha_composite(orbit.rotate(angle, Image.Resampling.BICUBIC))
    ImageDraw.Draw(image).ellipse((145, 145, 175, 175), fill="#d0d4d7")
    return image.crop(image.getbbox())


def paint(electron):
    length = 18.0 if electron else 70.0
    rng = random.Random(51 if electron else 19)
    image = Image.new("RGB", (WIDTH, HEIGHT), "#21262b" if electron else "#e4e5e4")
    draw = ImageDraw.Draw(image)

    def y(meters):
        return round((1 - meters / length) * (HEIGHT - 1))

    def band(low, high, color):
        draw.rectangle((0, y(high), WIDTH, y(low)), color)

    def line(u, bottom, top, color, width):
        x = round(WIDTH * u)
        draw.line((x, y(bottom), x, y(top)), fill=color, width=width)

    def mark(decal, u, altitude, arc, meters):
        decal = decal.convert("RGBA")
        decal = decal.resize((round(arc * WIDTH), round(meters / length * HEIGHT)), Image.Resampling.LANCZOS)
        x, row = round(u * WIDTH - decal.width / 2), y(altitude) - decal.height // 2
        for offset in (-WIDTH, 0, WIDTH):
            image.paste(decal, (x + offset, row), decal)

    if electron:
        # Visible thermal treatment, black composite and bright separation collars.
        band(0.95, 1.31, "#b9bfc2")
        band(4.48, 10.36, "#d2d6d9")
        for center in (0.25, 0.75):
            draw.rectangle((round(WIDTH * (center - 0.017)), y(10.36),
                            round(WIDTH * (center + 0.017)), y(4.48)), "#292d30")
        band(11.92, 12.06, "#8f232b")
        band(12.81, 13.02, "#c2c6c8")
        band(14.02, 15.36, "#d6d7d7")
        band(15.42, 15.58, "#b8bcbe")
        band(15.58, 15.73, "#96232b")
        for seam in (1.31, 4.48, 7.44, 10.36, 12.08, 14.02, 15.36):
            band(seam - 0.009, seam, "#5f6569")
        logo = Image.open(DECALS / "rocket_lab.png").convert("RGBA")
        light_logo = Image.new("RGBA", logo.size, "#e2e3e3")
        light_logo.putalpha(logo.getchannel("A"))
        red = logo.getchannel("R").point(lambda value: 255 if value > 185 else 0)
        logo = Image.composite(logo, light_logo, red)
        for center in (0.5, 0.0):
            mark(label("ELECTRON", "#e5e6e5", stacked=True), center, 2.9, 0.055, 2.45)
            mark(atom_mark(), center, 11.15, 0.19, 0.73)
            mark(flag(False), center + 0.085, 14.67, 0.125, 0.235)
            mark(logo, center + 0.055, 16.39, 0.23, 0.32)
            mark(label("RL • 01", "#b8bdbf"), center + 0.12, 1.55, 0.079, 0.084)
    else:
        band(0.0, 1.8, "#3b3e41")
        band(41.17, 47.71, "#242a31")
        for seam in (1.80, 8.33, 19.7, 32.6, 40.93, 47.72, 55.64, 56.9, 62.15):
            band(seam - 0.034, seam + 0.032, "#a5aaad")
            band(seam + 0.033, seam + 0.055, "#f6f6f1")
        for center in (0.25, 0.75):
            line(center, 1.7, 40.7, "#a5aaad", 3)
            for altitude in (10.0, 29.1, 37.1, 52.1, 58.6):
                x = round(center * WIDTH)
                draw.rounded_rectangle((x - 14, y(altitude + 0.21), x + 14, y(altitude - 0.21)),
                                       radius=4, fill="#c5c9cc", outline="#8b9196", width=2)
        logo = Image.open(DECALS / "spacex.png").convert("RGBA")
        dark_logo = Image.new("RGBA", logo.size, "#253349")
        dark_logo.putalpha(logo.getchannel("A"))
        for center in (0.5, 0.0):
            mark(dark_logo.rotate(90, expand=True), center, 22.0, 0.117, 11.9)
            mark(flag(True), center, 52.1, 0.169, 1.03)
            mark(label("FALCON 9", "#3f4850"), center + 0.062, 62.65, 0.184, 0.36)
            mark(label("B10 / 1", "#5f6266"), center + 0.105, 36.9, 0.064, 0.38)
            mark(label("LIFT", "#52565a"), center + 0.105, 8.7, 0.052, 0.24)

        # A reflown booster has light, vertically streaked deposits on the aft barrel.
        soot = Image.new("L", image.size)
        deposits = ImageDraw.Draw(soot)
        for _ in range(240):
            x, width = rng.randrange(WIDTH), rng.randrange(2, 25)
            top = y(rng.uniform(2.8, 13.5))
            opacity = rng.randrange(9, 64)
            for offset in (-WIDTH, 0, WIDTH):
                deposits.polygon(((x + offset, top), (x + offset + width, y(1.75)),
                                  (x + offset - width, y(1.75))), fill=opacity)
        image = Image.composite(Image.new("RGB", image.size, "#68645e"), image,
                                soot.filter(ImageFilter.GaussianBlur(6)))

    # Layer fine paint grain over lower-frequency panel variation.
    coarse = Image.frombytes("L", (160, 260), rng.randbytes(160 * 260)).resize(
        image.size, Image.Resampling.BICUBIC).point(lambda value: 123 + value * 10 // 255)
    fine = Image.frombytes("L", image.size, rng.randbytes(WIDTH * HEIGHT)).point(
        lambda value: 125 + value * 6 // 255)
    grain = ImageChops.add(coarse, fine, offset=-128)
    if electron:
        tile = Image.new("L", (16, 16))
        tile.putdata([128 + (3 if (x // 4 + y // 4) % 2 else -2)
                      + (1 if (x + y) % 4 == 0 else 0) for y in range(16) for x in range(16)])
        weave = Image.new("L", image.size)
        for y in range(0, HEIGHT, 16):
            for x in range(0, WIDTH, 16):
                weave.paste(tile, (x, y))
        composite = image.convert("L").point(lambda value: 255 if 12 < value < 55 else 0)
        grain = Image.composite(ImageChops.add(grain, weave, offset=-128), grain, composite)
    image = ImageChops.add(image, Image.merge("RGB", (grain,) * 3), offset=-128)
    return image


def add_view(model, binary, payload, target=None):
    binary.extend(b"\0" * (-len(binary) % 4))
    view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload)}
    if target:
        view["target"] = target
    binary.extend(payload)
    model["bufferViews"].append(view)
    return len(model["bufferViews"]) - 1


def read_accessor(model, binary, index):
    entry = model["accessors"][index]
    view = model["bufferViews"][entry["bufferView"]]
    size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[entry["type"]]
    kind = {5123: "H", 5125: "I", 5126: "f"}[entry["componentType"]]
    unpack = struct.Struct("<" + kind * size)
    offset = view.get("byteOffset", 0) + entry.get("byteOffset", 0)
    stride = view.get("byteStride", unpack.size)
    return [unpack.unpack_from(binary, offset + i * stride) for i in range(entry["count"])]


def write_accessor(model, binary, values, kind, shape, component, target, bounds=False):
    pack = struct.Struct("<" + kind * len(values[0]))
    payload = b"".join(pack.pack(*row) for row in values)
    entry = {"bufferView": add_view(model, binary, payload, target), "componentType": component,
             "count": len(values), "type": shape}
    if bounds:
        axes = list(zip(*values))
        entry.update(min=[min(axis) for axis in axes], max=[max(axis) for axis in axes])
    model["accessors"].append(entry)
    return len(model["accessors"]) - 1


def unwrap(model, binary, primitive, offset, length):
    old = primitive["attributes"]
    positions = read_accessor(model, binary, old["POSITION"])
    normals = read_accessor(model, binary, old["NORMAL"])
    indices = read_accessor(model, binary, primitive["indices"])
    coords = [(0.5 + math.atan2(x + offset[0], z + offset[2]) / math.tau,
               1 - (y + offset[1]) / length) for x, y, z in positions]
    vertices, output, remap = [], [], {}
    for corner in range(0, len(indices), 3):
        triangle = [index for index, in indices[corner:corner + 3]]
        us = [coords[index][0] for index in triangle]
        if max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        for index, u in zip(triangle, us):
            key = (index, u)
            if key not in remap:
                remap[key] = len(vertices)
                vertices.append((positions[index], normals[index], (u, coords[index][1])))
            output.append((remap[key],))
    new_positions, new_normals, uvs = zip(*vertices)
    primitive["attributes"] = {
        "POSITION": write_accessor(model, binary, new_positions, "f", "VEC3", 5126, 34962, True),
        "NORMAL": write_accessor(model, binary, new_normals, "f", "VEC3", 5126, 34962),
        "TEXCOORD_0": write_accessor(model, binary, uvs, "f", "VEC2", 5126, 34962),
    }
    primitive["indices"] = write_accessor(model, binary, output, "I", "SCALAR", 5125, 34963)


def paint_glb(source, output, electron):
    raw = source.read_bytes()
    magic, version, _ = struct.unpack_from("<4sII", raw)
    if (magic, version) != (b"glTF", 2):
        raise ValueError("Expected a GLB v2 geometry export")
    size = struct.unpack_from("<I", raw, 12)[0]
    model = json.loads(raw[20:20 + size])
    binary = bytearray(raw[28 + size:])
    if any(image.get("name", "").endswith("_livery") for image in model.get("images", [])):
        raise ValueError("Use a clean geometry export without the baked livery")
    image = io.BytesIO()
    paint(electron).save(image, "JPEG", quality=94, optimize=True, subsampling=0)
    view = add_view(model, binary, image.getvalue())
    name = "electron_livery" if electron else "falcon_9_livery"
    model.setdefault("images", []).append({"name": name, "mimeType": "image/jpeg", "bufferView": view})
    textures = model.setdefault("textures", [])
    textures.append({"source": len(model["images"]) - 1})
    material_indices = {}

    def visit(node_index, parent_offset):
        node = model["nodes"][node_index]
        offset = tuple(a + b for a, b in zip(parent_offset, node.get("translation", (0, 0, 0))))
        name = node.get("name", "")
        # The unchanged hardware retains its original materials and UVs.
        outer = name in {"stage_1", "stage_2", "interstage", "fairing_left", "fairing_right"} if electron else (
            name.startswith("Payload fairing |") or name in {"Booster | painted barrel",
                "Upper stage | barrel", "Upper stage | payload adapter"})
        if outer and "mesh" in node:
            mesh = model["meshes"][node["mesh"]]
            for primitive in mesh["primitives"]:
                original = primitive["material"]
                if electron and original not in (0, 1):
                    continue
                if original not in material_indices:
                    materials = model["materials"]
                    livery = deepcopy(materials[original])
                    livery["name"] += "_livery"
                    livery.pop("normalTexture", None)
                    pbr = livery["pbrMetallicRoughness"]
                    pbr.pop("baseColorFactor", None)
                    pbr["baseColorTexture"] = {"index": len(textures) - 1}
                    material_indices[original] = len(materials)
                    materials.append(livery)
                primitive["material"] = material_indices[original]
                unwrap(model, binary, primitive, offset, 18.0 if electron else 70.0)
        for child in node.get("children", []):
            visit(child, offset)

    scene = model["scenes"][model.get("scene", 0)]
    for root in scene["nodes"]:
        visit(root, (0, 0, 0))
    # The Falcon source has an identity wrapper. Godot staging looks up sections at the root.
    if not electron and len(scene["nodes"]) == 1:
        wrapper = model["nodes"][scene["nodes"][0]]
        if set(wrapper) == {"name", "children"} and wrapper["name"] == "launcher_falcon_9":
            scene["nodes"] = wrapper.pop("children")
    binary.extend(b"\0" * (-len(binary) % 4))
    model["buffers"][0]["byteLength"] = len(binary)
    document = json.dumps(model, separators=(",", ":")).encode()
    document += b" " * (-len(document) % 4)
    output.write_bytes(struct.pack("<4sII", b"glTF", 2, 28 + len(document) + len(binary))
                       + struct.pack("<I4s", len(document), b"JSON") + document
                       + struct.pack("<I4s", len(binary), b"BIN\0") + binary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rocket", choices=("electron", "falcon9"))
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("Choose a separate output path to preserve the source geometry")
    paint_glb(args.input, args.output, args.rocket == "electron")
