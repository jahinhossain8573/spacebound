"""Build the three spacecraft solar wings, folded at frame 0.

Run in Blender: blender -b --factory-startup --python art_source/parts/solar_wings.py
These are original game assets inspired by manufacturer photography. Each model represents
one wing; its root sits on the bus mounting face and its deployed span follows Blender +Z.
"""

from dataclasses import dataclass
import math
from pathlib import Path
import sys

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "tools"))
import sb_build as sb  # noqa: E402

MATERIALS = ["sb_solar_cell", "sb_black_anodised", "sb_aluminium"]
SOLAR, FRAME, METAL = range(len(MATERIALS))


@dataclass(frozen=True)
class Wing:
    id: str
    width: float
    leaf_span: float
    thickness: float
    hinge_lift: float
    root_height: float
    leaves: int
    columns: int
    rows: int
    ribs: int


WINGS = (
    # MMA Space HaWK family: shallow CubeSat panel stack with exposed hinge barrels.
    Wing("pwr_mma_ehawk_s", .19, .155, .0025, .0038, .010, 2, 4, 3, 0),
    # Spectrolab XTJ: rigid panel modules with a fine grid of triple-junction cells.
    Wing("pwr_spectrolab_m", .55, .275, .007, .009, .026, 3, 10, 4, 2),
    # Airbus: three stiffened leaves on a broad solar-array drive and support boom.
    Wing("pwr_airbus_l", 1.02, .73, .018, .021, .056, 3, 18, 10, 3),
)


def solid_box(bm, size, center, material, bevel=0.0):
    # Bevel can recreate a box face without returning it in the bevel output.
    original = set(bm.faces)
    sb.add_box(bm, size, center, material, bevel)
    for face in bm.faces:
        if face not in original:
            face.material_index = material


def mount(spec):
    bm = bmesh.new()
    height, width = spec.root_height, spec.width
    solid_box(bm, (width * .32, height * 1.6, height * .18), (0, 0, height * .09),
               METAL, bevel=height * .035)
    solid_box(bm, (width * .22, height, height * .69), (0, 0, height * .50),
               FRAME, bevel=height * .08)
    sb.add_cylinder(bm, height * .30, width * .32, (0, 0, height), "X", 16, METAL)
    for x in (-width * .14, width * .14):
        sb.add_cylinder(bm, height * .38, width * .045, (x, 0, height), "X", 16, FRAME)
    sb.box_uvs(bm)
    sb.to_object("array_drive", bm, MATERIALS)


def pivot(name, parent, location, folded_angle, start, end, action):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.empty_display_size = .025
    obj.parent = parent
    obj.location = location
    obj.rotation_mode = "XYZ"
    obj.animation_data_create().action = action
    for frame, angle in ((0, folded_angle), (start, folded_angle), (end, 0.0)):
        obj.rotation_euler.x = angle
        obj.keyframe_insert(data_path="rotation_euler", index=0, frame=frame)
    return obj


def panel(spec, index, parent, center_y):
    bm = bmesh.new()
    width, span, thickness = spec.width, spec.leaf_span, spec.thickness
    margin_x = width * .04
    margin_z = span * .065
    panel_span = span - margin_z
    solid_box(bm, (width, thickness, panel_span), (0, center_y, span / 2),
               FRAME, bevel=thickness * .22)

    cell_width, cell_span = width - 2 * margin_x, span - 2 * margin_z
    cell_thickness = thickness * .13
    solid_box(bm, (cell_width, cell_thickness, cell_span),
               (0, center_y + (thickness + cell_thickness) / 2, span / 2), SOLAR)
    for side in (-1, 1):
        rail_x = side * (width / 2 - margin_x * .48)
        solid_box(bm, (margin_x * .52, thickness * .26, panel_span * .96),
                   (rail_x, center_y + thickness * .55, span / 2), METAL)
        for z in (margin_z * .8, span - margin_z * .8):
            sb.add_cylinder(bm, margin_x * .22, thickness * .30,
                            (rail_x, center_y + thickness * .62, z), "Y", 12, METAL)

    for rib in range(spec.ribs):
        z = span * (rib + 1) / (spec.ribs + 1)
        solid_box(bm, (width * .91, thickness * .34, thickness * 1.65),
                   (0, center_y - thickness * .58, z), METAL, bevel=thickness * .08)
    if spec.ribs > 1:
        for side in (-1, 1):
            solid_box(bm, (thickness * 1.5, thickness * .33, panel_span * .9),
                       (side * width * .24, center_y - thickness * .58, span / 2), FRAME)

    for side in (-1, 1):
        x = side * width * (.10 if index == 0 else .30)
        solid_box(bm, (width * .09, thickness, margin_z * 1.15),
                  (x, center_y, margin_z * .49), METAL)
        if index > 0:
            solid_box(bm, (width * .09, abs(center_y) + thickness, thickness * 1.4),
                      (x, center_y * .5, thickness * .55), METAL)

    if index < spec.leaves - 1:
        hinge_y = center_y + (-1 if index % 2 == 0 else 1) * spec.hinge_lift
        for side in (-1, 1):
            x = side * width * .30
            solid_box(bm, (width * .105, thickness, margin_z * .9),
                       (x, center_y, span - margin_z * .55), METAL)
            sb.add_cylinder(bm, thickness * .68, width * .10,
                            (x, hinge_y, span), "X", 16, METAL)

    sb.box_uvs(bm)
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        if face.material_index == SOLAR and face.normal.y > .99:
            for loop in face.loops:
                u = (loop.vert.co.x / cell_width + .5) * spec.columns / 4
                v = ((loop.vert.co.z - span / 2) / cell_span + .5) * spec.rows / 4
                loop[uv].uv = (u, v)
    sb.to_object(f"panel_{index + 1}", bm, MATERIALS, parent)


def build(spec):
    scene = sb.reset_scene()
    mount(spec)
    action = bpy.data.actions.new("deploy")
    hinge = pivot("root_hinge", None, (0, 0, spec.root_height), -math.pi / 2,
                  0, 22 if spec.leaves == 2 else 16, action)
    center_y = 0.0
    for index in range(spec.leaves):
        panel(spec, index, hinge, center_y)
        if index == spec.leaves - 1:
            break
        side = -1 if index % 2 == 0 else 1
        hinge = pivot(f"hinge_{index + 2}", hinge,
                      (0, center_y + side * spec.hinge_lift, spec.leaf_span),
                      -side * math.pi, 22 if spec.leaves == 2 else (16, 39)[index],
                      60 if spec.leaves == 2 else (39, 60)[index], action)
        center_y = -side * spec.hinge_lift
    scene.frame_set(0)
    sb.save_and_export(str(HERE / f"{spec.id}.py"))


if __name__ == "__main__":
    for wing in WINGS:
        build(wing)
