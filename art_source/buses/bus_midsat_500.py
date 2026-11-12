"""Original configurable midsat inspired by Blue Canyon's Saturn-class platform."""

from pathlib import Path
import sys

import bmesh

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import sb_build as sb  # noqa: E402


def build():
    sb.reset_scene()
    mesh = bmesh.new()
    paint, frame, dark = range(3)
    sb.add_box(mesh, (0.94, 0.94, 0.93), (0, 0, 0), paint, bevel=0.025)
    for z in (-1, 1):
        sb.add_box(mesh, (1.0, 1.0, 0.035), (0, 0, z * 0.4825), frame, bevel=0.02)
        sb.add_cylinder(mesh, 0.30, 0.027, (0, 0, z * 0.483), material_index=dark, segments=32)
        for x in (-0.416, 0.416):
            for y in (-0.416, 0.416):
                sb.add_cylinder(mesh, 0.013, 0.008, (x, y, z * 0.497), segments=8, material_index=dark)
    for sign in (-1, 1):
        for offset in (-0.34, 0.34):
            sb.add_box(mesh, (0.019, 0.10, 0.91), (sign * 0.472, offset, 0), frame, bevel=0.005)
            sb.add_box(mesh, (0.10, 0.019, 0.91), (offset, sign * 0.472, 0), frame, bevel=0.005)
            for z in (-0.35, -0.19, 0.19, 0.35):
                sb.add_cylinder(mesh, 0.008, 0.007, (sign * 0.482, offset, z), "X", 8, dark)
                sb.add_cylinder(mesh, 0.008, 0.007, (offset, sign * 0.482, z), "Y", 8, dark)
        for z in (-0.29, 0.29):
            sb.add_box(mesh, (0.025, 0.36, 0.16), (sign * 0.474, 0, z), dark, bevel=0.012)
            for y in (-0.13, -0.065, 0.0, 0.065, 0.13):
                sb.add_box(mesh, (0.008, 0.021, 0.12), (sign * 0.488, y, z), frame, bevel=0.002)
        sb.add_box(mesh, (0.36, 0.021, 0.18), (0, sign * 0.472, -0.24), frame, bevel=0.006)
        for x in (-0.118, 0, 0.118):
            sb.add_cylinder(mesh, 0.024, 0.018, (x, sign * 0.480, -0.24), "Y", 12, dark)
    sb.box_uvs(mesh)
    sb.to_object("service_bus", mesh, ["sb_white_paint", "sb_aluminium", "sb_black_anodised"])
    for name, axis in (
        ("mount_top", (0, 0, 1)), ("mount_bottom", (0, 0, -1)),
        ("mount_front", (0, 1, 0)), ("mount_back", (0, -1, 0)),
        ("mount_left", (-1, 0, 0)), ("mount_right", (1, 0, 0)),
        ("array_hinge_left", (-1, 0, 0)), ("array_hinge_right", (1, 0, 0)),
        ("engine_mount", (0, 0, -1)),
    ):
        sb.add_empty(name, tuple(0.5 * value for value in axis), axis)
    sb.save_and_export(__file__)


if __name__ == "__main__":
    build()
