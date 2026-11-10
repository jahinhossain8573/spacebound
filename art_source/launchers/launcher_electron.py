"""Rocket Lab Electron-style launcher (Linear 3D-3). 18 m tall, 1.2 m diameter, no logos.

Each section's origin is at its base. The fairing halves have their origins at their outer
base edge, so the game can either slide them sideways or hinge them open.
    blender -b --factory-startup --python art_source/launchers/launcher_electron.py
"""

import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import sb_build as sb  # noqa: E402

RADIUS = 0.6
WEAVE_TILE = 0.25
STAGE_1_TOP, INTERSTAGE_TOP, STAGE_2_TOP = 12.0, 13.0, 15.4
FAIRING_BASE, FAIRING_TOP = 15.5, 18.0
PAYLOAD_MOUNT = 15.55
VACUUM_EXIT = 12.1
BLACK, WHITE, NOZZLE = 0, 1, 2
MATERIALS = ["sb_black_composite", "sb_white_paint", "sb_nozzle"]

SEA_LEVEL_BELL = [
    (0.105, 0.0), (0.095, 0.08), (0.08, 0.17), (0.062, 0.26), (0.047, 0.32), (0.04, 0.35),
    (0.055, 0.38), (0.055, 0.48), (0.03, 0.52), (0.0, 0.52),
    (0.0, 0.33), (0.035, 0.33), (0.042, 0.31), (0.057, 0.25), (0.075, 0.16), (0.09, 0.08), (0.1, 0.0),
]
VACUUM_BELL = [
    (0.32, 0.0), (0.29, 0.12), (0.24, 0.28), (0.18, 0.44), (0.12, 0.6), (0.07, 0.74), (0.05, 0.8),
    (0.07, 0.83), (0.07, 0.93), (0.0, 0.95),
    (0.0, 0.78), (0.045, 0.78), (0.065, 0.72), (0.115, 0.59), (0.175, 0.43), (0.235, 0.27), (0.285, 0.115), (0.312, 0.0),
]
FAIRING = [
    (RADIUS, 15.5), (RADIUS, 15.6), (RADIUS, 16.6), (0.59, 16.8), (0.56, 17.0), (0.51, 17.2), (0.44, 17.4),
    (0.35, 17.6), (0.24, 17.78), (0.13, 17.92), (0.05, 17.99), (0.0, 18.0),
    (0.0, 17.95), (0.04, 17.94), (0.11, 17.87), (0.21, 17.74), (0.32, 17.57), (0.41, 17.38), (0.48, 17.19),
    (0.53, 17.0), (0.56, 16.8), (0.57, 16.6), (0.57, 15.5),
]


def composite_uv(fraction, radius, z, _index):
    return (fraction * 2 * math.pi * RADIUS / WEAVE_TILE, z / WEAVE_TILE)


def bell_uv(length):
    def uv(fraction, radius, z, _index):
        return (fraction, min(1.0, max(0.0, 1.0 - z / length)))
    return uv


def bell(bm, profile, segments, offset, length):
    """length is the exit-to-throat height, which spans the nozzle texture's V range."""
    faces = sb.add_lathe(bm, profile, segments, NOZZLE, uv=bell_uv(length), closed=True)
    for vert in {v for face in faces for v in face.verts}:
        vert.co.x += offset[0]
        vert.co.y += offset[1]
        vert.co.z += offset[2]


def stage_1():
    bm = bmesh.new()
    profile = [(0.0, 0.5), (RADIUS, 0.5), (RADIUS, 0.85), (RADIUS, 0.95), (RADIUS, 11.55), (RADIUS, 11.7), (RADIUS, STAGE_1_TOP), (0.0, STAGE_1_TOP)]
    sb.add_lathe(bm, profile, 64, uv=composite_uv, span_materials=[BLACK, BLACK, WHITE, BLACK, WHITE, BLACK, BLACK])
    bell(bm, SEA_LEVEL_BELL, 24, (0, 0, 0), 0.35)
    for i in range(8):
        angle = 2 * math.pi * (i + 0.5) / 8
        bell(bm, SEA_LEVEL_BELL, 24, (0.4 * math.cos(angle), 0.4 * math.sin(angle), 0), 0.35)
    before = set(bm.faces)
    sb.add_box(bm, (0.05, 0.09, 10.4), (RADIUS + 0.015, 0, 6.1), BLACK, bevel=0.01)
    uv = bm.loops.layers.uv.verify()
    for face in set(bm.faces) - before:
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co.y / WEAVE_TILE, loop.vert.co.z / WEAVE_TILE)
    return sb.to_object("stage_1", bm, MATERIALS, smooth_angle=40)


def interstage():
    bm = bmesh.new()
    profile = [(RADIUS, STAGE_1_TOP), (RADIUS, INTERSTAGE_TOP), (RADIUS - 0.02, INTERSTAGE_TOP), (RADIUS - 0.02, STAGE_1_TOP)]
    sb.add_lathe(bm, profile, 64, BLACK, uv=composite_uv, closed=True)
    sb.translate(bm, (0, 0, STAGE_1_TOP))
    obj = sb.to_object("interstage", bm, MATERIALS[:2], smooth_angle=40)
    obj.location = (0, 0, STAGE_1_TOP)
    return obj


def stage_2():
    bm = bmesh.new()
    profile = [(0.0, INTERSTAGE_TOP), (RADIUS, INTERSTAGE_TOP), (RADIUS, 15.2), (RADIUS, 15.35), (RADIUS, STAGE_2_TOP), (0.0, STAGE_2_TOP)]
    sb.add_lathe(bm, profile, 64, uv=composite_uv, span_materials=[BLACK, BLACK, WHITE, BLACK, BLACK])
    adapter = [(0.0, STAGE_2_TOP), (0.25, STAGE_2_TOP), (0.18, PAYLOAD_MOUNT), (0.0, PAYLOAD_MOUNT)]
    sb.add_lathe(bm, adapter, 32, WHITE, uv=composite_uv)
    bell(bm, VACUUM_BELL, 48, (0, 0, VACUUM_EXIT), 0.8)
    sb.translate(bm, (0, 0, VACUUM_EXIT))
    obj = sb.to_object("stage_2", bm, MATERIALS, smooth_angle=40)
    obj.location = (0, 0, VACUUM_EXIT)
    return obj


def fairing_half(name, arc, edge_x):
    bm = bmesh.new()
    spans = [WHITE] + [BLACK] * (len(FAIRING) - 1)
    sb.add_lathe(bm, FAIRING, 32, BLACK, uv=composite_uv, closed=True, arc=arc, span_materials=spans)
    sb.translate(bm, (edge_x, 0, FAIRING_BASE))
    obj = sb.to_object(name, bm, MATERIALS[:2], smooth_angle=40)
    obj.location = (edge_x, 0, FAIRING_BASE)
    return obj


def build():
    sb.reset_scene()
    first = stage_1()
    interstage()
    second = stage_2()
    fairing_half("fairing_left", (90.0, 270.0), -RADIUS)
    fairing_half("fairing_right", (-90.0, 90.0), RADIUS)
    sb.add_empty("exhaust_stage_1", (0, 0, 0), (0, 0, 1), first, size=0.5)
    sb.add_empty("exhaust_stage_2", (0, 0, VACUUM_EXIT), (0, 0, 1), second, size=0.5)
    sb.add_empty("payload_mount", (0, 0, PAYLOAD_MOUNT), (0, 0, 1), second, size=0.3)
    sb.reference_cube((3, 0, 0.5))
    sb.save_and_export(__file__)


if __name__ == "__main__":
    build()
