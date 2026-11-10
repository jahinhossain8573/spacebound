"""EnduroSat-style UHF turnstile antenna module (Linear 3D-9).

A 1U face plate (0.10 x 0.10 x 0.007 m) with four 0.17 m tape-spring monopoles. In the stowed
rest pose each tape is curled in its quarter of the plate; 'deploy' springs them straight into a
pinwheel cross. Adjacent tapes sit at different heights so their coils never touch.
    blender -b --factory-startup --python art_source/parts/com_endurosat_uhf.py
"""

import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import sb_build as sb  # noqa: E402

import bpy  # noqa: E402

PLATE, PLATE_T = 0.10, 0.007
TAPE_LENGTH, SEGMENTS = 0.17, 8
TAPE_WIDTH, TAPE_T = 0.003, 0.0008
LAYERS = (PLATE_T + 0.0016, PLATE_T + 0.0052)
SEGMENT = TAPE_LENGTH / SEGMENTS
BEND = 360.0 / SEGMENTS


def plate():
    bm = bmesh.new()
    sb.add_box(bm, (PLATE, PLATE, PLATE_T), (0, 0, PLATE_T / 2), 0, bevel=0.0008)
    sb.add_cylinder(bm, 0.0045, 0.003, (0, 0, PLATE_T + 0.0015), "Z", 16, 1)
    for i in range(4):
        angle = math.radians(90 * i)
        x, y = 0.044, 0.025
        cx, cy = x * math.cos(angle) - y * math.sin(angle), x * math.sin(angle) + y * math.cos(angle)
        size = (0.008, 0.012, 0.009) if i % 2 == 0 else (0.012, 0.008, 0.009)
        sb.add_box(bm, size, (cx, cy, PLATE_T + 0.0045), 2, bevel=0.0006)
    sb.box_uvs(bm, tile=0.05)
    return sb.to_object("plate", bm, ["sb_black_anodised", "sb_aluminium", "sb_white_paint"])


def segment_mesh():
    bm = bmesh.new()
    sb.add_box(bm, (SEGMENT, TAPE_T, TAPE_WIDTH), (SEGMENT / 2, 0, 0), 0)
    sb.box_uvs(bm, tile=0.05)
    mesh = bpy.data.meshes.new("tape_segment")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(sb.material("sb_aluminium"))
    return mesh


def tape(index, mesh, action):
    quarter = math.radians(90 * index)
    rx, ry = 0.0505, 0.025
    root = (rx * math.cos(quarter) - ry * math.sin(quarter), rx * math.sin(quarter) + ry * math.cos(quarter), LAYERS[index % 2])
    stowed = quarter + math.radians(90 + BEND / 2)
    deployed = quarter
    start, end = index * 4, 44 + index * 4
    parent = None
    for k in range(SEGMENTS):
        obj = bpy.data.objects.new("tape_%d_%d" % (index, k), mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = root if parent is None else (SEGMENT, 0, 0)
        obj.animation_data_create().action = action
        for frame, angle in ((start, stowed if k == 0 else math.radians(BEND)), (end, deployed if k == 0 else 0.0)):
            obj.rotation_euler = (0, 0, angle)
            obj.keyframe_insert("rotation_euler", index=2, frame=frame)
        parent = obj


def build():
    sb.reset_scene(frame_end=60)
    plate()
    mesh = segment_mesh()
    action = bpy.data.actions.new("deploy")
    for index in range(4):
        tape(index, mesh, action)
    sb.reference_cube()
    sb.save_and_export(__file__)


if __name__ == "__main__":
    build()
