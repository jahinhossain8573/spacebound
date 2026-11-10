"""Rebuild tests/fixtures/models/buses/bus_spec_fixture.glb, the pipeline test asset.

It is a 3U CubeSat-sized bus built the way the spec asks: library materials,
Single Arrow empties whose Z axis points outward, and a 'deploy' animation.
tests/test_models.gd checks that it arrives in Godot with the right size and axes.
    blender -b --factory-startup --python art_source/tools/build_fixture.py
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sb_export  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
LIBRARY = os.path.join(ROOT, "art_source", "materials", "sb_materials.blend")
OUTPUT = os.path.join(ROOT, "tests", "fixtures", "models", "buses", "bus_spec_fixture.glb")

# Blender axes: +Z is Godot +Y (up); +Y is Godot -Z (front).
WIDTH, LENGTH, HEIGHT = 0.10, 0.34, 0.10
EMPTIES = {
    "mount_top": ((0, 0, HEIGHT / 2), (0, 0, 0)),
    "mount_bottom": ((0, 0, -HEIGHT / 2), (180, 0, 0)),
    "mount_front": ((0, LENGTH / 2, 0), (-90, 0, 0)),
    "mount_back": ((0, -LENGTH / 2, 0), (90, 0, 0)),
    "mount_left": ((-WIDTH / 2, 0, 0), (0, -90, 0)),
    "mount_right": ((WIDTH / 2, 0, 0), (0, 90, 0)),
    "array_hinge_left": ((-WIDTH / 2, 0, 0.03), (0, -90, 0)),
    "array_hinge_right": ((WIDTH / 2, 0, 0.03), (0, 90, 0)),
    "engine_mount": ((0, 0, -HEIGHT / 2), (180, 0, 0)),
}


def library_material(name):
    with bpy.data.libraries.load(LIBRARY, link=False) as (source, target):
        target.materials = [name]
    return target.materials[0]


def box(name, size, location, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def build():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.frame_start, scene.frame_end = 0, 60
    paint = library_material("sb_white_paint")
    aluminium = library_material("sb_aluminium")
    box("body", (WIDTH * 0.92, LENGTH, HEIGHT * 0.92), (0, 0, 0), paint)
    for index, (x, z) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        box("rail_%d" % index, (0.008, LENGTH, 0.008), (x * (WIDTH / 2 - 0.004), 0, z * (HEIGHT / 2 - 0.004)), aluminium)
    for name, (location, rotation) in EMPTIES.items():
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "SINGLE_ARROW"
        empty.empty_display_size = 0.05
        empty.location = location
        empty.rotation_euler = [math.radians(a) for a in rotation]
        scene.collection.objects.link(empty)
    flap = box("antenna_flap", (0.08, 0.002, 0.06), (0, 0, 0.03), aluminium)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    flap.location = (0, LENGTH / 2 - 0.02, HEIGHT / 2)
    flap.animation_data_create().action = bpy.data.actions.new("deploy")
    for frame, angle in ((0, 90), (60, 0)):
        flap.rotation_euler = (math.radians(angle), 0, 0)
        flap.keyframe_insert("rotation_euler", frame=frame)
    reference = box("reference_cube", (1, 1, 1), (2, 0, 0.5), paint)
    reference.hide_render = True
    errors, warnings, triangles = sb_export.check(scene, "buses")
    for message in warnings + errors:
        print(message)
    if errors:
        sys.exit(1)
    sb_export.export(OUTPUT)
    print("Exported fixture (%d triangles) to %s" % (triangles, OUTPUT))


if __name__ == "__main__":
    build()
