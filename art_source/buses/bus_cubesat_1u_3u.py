"""3U CubeSat bus, BRAC Onnesha style (Linear 3D-6). 0.10 x 0.10 x 0.34 m in Godot (x, y, z).

    blender -b --factory-startup --python art_source/buses/bus_cubesat_1u_3u.py
"""

import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import sb_build as sb  # noqa: E402

HALF_W = 0.05          # Half width over the rails.
HALF_L = 0.17          # Half length over the rails.
RAIL = 0.0085          # CubeSat rail width.
PANEL = 0.047          # Recessed side panel surface; a 3 mm P31u tile sits flush with the rails.
END = 0.163            # End plates sit 7 mm inside the rail tips.
INNER = HALF_W - RAIL  # Rail inner faces.
UNIT_CENTRES = (-0.1087, 0.0, 0.1087)
ALUMINIUM, ANODISED = 0, 1


def frame_and_panels():
    bm = bmesh.new()
    for x in (-1, 1):
        for z in (-1, 1):
            sb.add_box(bm, (RAIL, 2 * HALF_L, RAIL), (x * (HALF_W - RAIL / 2), 0, z * (HALF_W - RAIL / 2)), ALUMINIUM, bevel=0.0008)
    span = 2 * INNER
    for sign in (-1, 1):
        sb.add_box(bm, (span, 2 * END, 0.002), (0, 0, sign * (PANEL - 0.001)), ANODISED)
        sb.add_box(bm, (0.002, 2 * END, span), (sign * (PANEL - 0.001), 0, 0), ANODISED)
        sb.add_box(bm, (span, 0.002, span), (0, sign * (END - 0.001), 0), ANODISED)
    # Unit divisions: thin separation frames across each long face.
    for y in (-0.0544, 0.0544):
        for sign in (-1, 1):
            sb.add_box(bm, (span, 0.004, 0.0012), (0, y, sign * (PANEL + 0.0006)), ALUMINIUM)
            sb.add_box(bm, (0.0012, 0.004, span), (sign * (PANEL + 0.0006), y, 0), ALUMINIUM)
    # Four screw heads per unit on each long face.
    for y0 in UNIT_CENTRES:
        for dy in (-0.042, 0.042):
            for d in (-0.034, 0.034):
                for sign in (-1, 1):
                    sb.add_cylinder(bm, 0.0015, 0.0008, (d, y0 + dy, sign * (PANEL + 0.0004)), "Z", 6, ALUMINIUM)
                    sb.add_cylinder(bm, 0.0015, 0.0008, (sign * (PANEL + 0.0004), y0 + dy, d), "X", 6, ALUMINIUM)
    # Back end: access port and remove-before-flight pin socket.
    sb.add_box(bm, (0.024, 0.0012, 0.018), (-0.014, -(END + 0.0006), 0.012), ALUMINIUM, bevel=0.0004)
    sb.add_box(bm, (0.018, 0.0016, 0.012), (-0.014, -(END + 0.0008), 0.012), ANODISED)
    sb.add_cylinder(bm, 0.0035, 0.004, (0.018, -(END + 0.002), -0.014), "Y", 16, ALUMINIUM)
    sb.add_cylinder(bm, 0.002, 0.0045, (0.018, -(END + 0.00225), -0.014), "Y", 12, ANODISED)
    sb.box_uvs(bm)
    return sb.to_object("bus_frame", bm, ["sb_aluminium", "sb_black_anodised"])


def mli_tape():
    bm = bmesh.new()
    for y in (-0.157, 0.157):
        for sign in (-1, 1):
            sb.add_box(bm, (2 * INNER, 0.006, 0.0004), (0, y, sign * (PANEL + 0.0002)))
            sb.add_box(bm, (0.0004, 0.006, 2 * INNER), (sign * (PANEL + 0.0002), y, 0))
    sb.box_uvs(bm, tile=0.05)
    return sb.to_object("mli_blanket", bm, ["sb_mli_gold"])


def attachment_points():
    for name, location, direction in (
        ("mount_top", (0, 0, PANEL), (0, 0, 1)),
        ("mount_bottom", (0, 0, -PANEL), (0, 0, -1)),
        ("mount_front", (0, HALF_L, 0), (0, 1, 0)),
        ("mount_back", (0, -HALF_L, 0), (0, -1, 0)),
        ("mount_left", (-PANEL, 0, 0), (-1, 0, 0)),
        ("mount_right", (PANEL, 0, 0), (1, 0, 0)),
        ("array_hinge_left", (-HALF_W, 0, 0), (-1, 0, 0)),
        ("array_hinge_right", (HALF_W, 0, 0), (1, 0, 0)),
        ("engine_mount", (0, 0, -PANEL), (0, 0, -1)),
    ):
        sb.add_empty(name, location, direction, size=0.03)


def build():
    sb.reset_scene()
    frame_and_panels()
    mli_tape()
    attachment_points()
    sb.reference_cube()
    sb.save_and_export(__file__)


if __name__ == "__main__":
    build()
