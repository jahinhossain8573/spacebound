"""GomSpace P31u-style body-mounted solar panel tile (Linear 3D-8).

0.083 x 0.003 x 0.30 m in Godot (x, y, z): the origin is at the back centre, the cells face +Y
and the length runs along Z, so the tile lies along the bus on any long face.
    blender -b --factory-startup --python art_source/parts/pwr_gomspace_p31u.py
"""

import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import sb_build as sb  # noqa: E402

WIDTH, LENGTH, THICKNESS = 0.083, 0.30, 0.003
CELLS_WIDE, CELLS_LONG = 2, 7
CELL_AREA = (0.075, 0.29)
TEXTURE_CELLS = 4  # sb_solar_cell shows 4 x 4 cells per UV tile.


def build():
    sb.reset_scene()
    bm = bmesh.new()
    sb.add_box(bm, (WIDTH, LENGTH, THICKNESS - 0.0004), (0, 0, (THICKNESS - 0.0004) / 2), 1, bevel=0.0003)
    sb.add_box(bm, (CELL_AREA[0], CELL_AREA[1], 0.0004), (0, 0, THICKNESS - 0.0002), 0)
    sb.box_uvs(bm)
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        if face.material_index == 0 and face.normal.z > 0.99:
            for loop in face.loops:
                u = (loop.vert.co.x / CELL_AREA[0] + 0.5) * CELLS_WIDE / TEXTURE_CELLS
                v = (loop.vert.co.y / CELL_AREA[1] + 0.5) * CELLS_LONG / TEXTURE_CELLS
                loop[uv].uv = (u, v)
    sb.to_object("pwr_gomspace_p31u", bm, ["sb_solar_cell", "sb_black_anodised"])
    sb.reference_cube()
    sb.save_and_export(__file__)


if __name__ == "__main__":
    build()
