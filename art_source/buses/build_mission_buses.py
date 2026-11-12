"""Build the original 12U, disaster-monitoring and Spacebus-inspired mission platforms.

    blender -b --factory-startup --python art_source/buses/build_mission_buses.py

Each platform keeps its electronics, instruments, propulsion and solar wings modular.
The in-game dimensions are taken from data/buses.json, not the reference spacecraft.
"""

import json
from pathlib import Path
import sys

import bmesh

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "tools"))
import sb_build as sb  # noqa: E402

FRAME, PANEL, DETAIL = range(3)


def plate(mesh, half, axis, sign, width, height, thickness, center, material, recess=0.0, bevel=0.0):
    """Add a plate with its outer face inset from the bus envelope by recess."""
    tangents = [i for i in range(3) if i != axis]
    size = [0.0, 0.0, 0.0]
    location = [0.0, 0.0, 0.0]
    size[axis] = thickness
    location[axis] = sign * (half[axis] - recess - thickness * 0.5)
    for i, tangent in enumerate(tangents):
        size[tangent] = (width, height)[i]
        location[tangent] = center[i]
    sb.add_box(mesh, size, location, material, bevel)


def bolt(mesh, half, axis, sign, radius, center, inset):
    tangents = [i for i in range(3) if i != axis]
    position = [0.0, 0.0, 0.0]
    position[axis] = sign * (half[axis] - inset - radius * 0.2)
    for i, tangent in enumerate(tangents):
        position[tangent] = center[i]
    sb.add_cylinder(mesh, radius, radius * 0.4, position, "XYZ"[axis], 6, FRAME)


def mounts(half, deck_recess=0.0):
    x, y, z = half
    for name, location, direction in (
        ("mount_top", (0, 0, z - deck_recess), (0, 0, 1)),
        ("mount_bottom", (0, 0, -z + deck_recess), (0, 0, -1)),
        ("mount_front", (0, y - deck_recess, 0), (0, 1, 0)),
        ("mount_back", (0, -y + deck_recess, 0), (0, -1, 0)),
        ("mount_left", (-x + deck_recess, 0, 0), (-1, 0, 0)),
        ("mount_right", (x - deck_recess, 0, 0), (1, 0, 0)),
        ("array_hinge_left", (-x, 0, 0), (-1, 0, 0)),
        ("array_hinge_right", (x, 0, 0), (1, 0, 0)),
        ("engine_mount", (0, 0, -z + deck_recess), (0, 0, -1)),
    ):
        sb.add_empty(name, location, direction, size=x * 0.3)


def cubesat(half):
    """Rail and flight-deck details inspired by NASA/Tyvak CAPSTONE integration photos."""
    x, y, z = half
    mesh = bmesh.new()
    sb.add_box(mesh, (2 * x - 0.012, 2 * y - 0.022, 2 * z - 0.012), (0, 0, 0), PANEL, 0.004)
    rail = 0.009
    for sx in (-1, 1):
        for sz in (-1, 1):
            sb.add_box(mesh, (rail, 2 * y, rail), (sx * (x - rail / 2), 0, sz * (z - rail / 2)), FRAME, 0.0012)

    for axis, half_width in ((0, z), (2, x)):
        for sign in (-1, 1):
            for station in (-0.11, 0.0, 0.11):
                center = (station, 0) if axis == 0 else (0, station)
                size = (0.009, 2 * half_width - 2 * rail) if axis == 0 else (2 * half_width - 2 * rail, 0.009)
                plate(mesh, half, axis, sign, *size, 0.003, center, FRAME, 0.002, 0.0007)
            for longitudinal in (-0.139, 0.139):
                center = (longitudinal, 0) if axis == 0 else (0, longitudinal)
                size = (0.019, 2 * half_width - 2 * rail - 0.012) if axis == 0 else (2 * half_width - 2 * rail - 0.012, 0.019)
                plate(mesh, half, axis, sign, *size, 0.002, center, DETAIL, 0.004, 0.0005)
                for edge in (-half_width + 0.017, half_width - 0.017):
                    center = (longitudinal, edge) if axis == 0 else (edge, longitudinal)
                    bolt(mesh, half, axis, sign, 0.0027, center, 0.003)

    for sign in (-1, 1):
        plate(mesh, half, 1, sign, 2 * x - 0.01, 2 * z - 0.01, 0.014, (0, 0), FRAME, 0.001, 0.003)
        plate(mesh, half, 1, sign, 2 * x - 0.028, 2 * z - 0.028, 0.002, (0, 0), PANEL, 0.0005, 0.001)
        for side in (-1, 1):
            for height in (-z + 0.018, z - 0.018):
                bolt(mesh, half, 1, sign, 0.0035, (side * (x - 0.018), height), 0.0)
            # An inset connector near each corner leaves the central mount clear.
            plate(mesh, half, 1, sign, 0.026, 0.019, 0.004, (side * 0.059, -sign * 0.068), DETAIL, 0.00025, 0.0015)
            plate(mesh, half, 1, sign, 0.019, 0.012, 0.001, (side * 0.059, -sign * 0.068), PANEL, 0.0)

    sb.box_uvs(mesh, tile=0.12)
    sb.to_object("cubesat_rail_chassis", mesh, ["sb_aluminium", "sb_black_anodised", "sb_mli_gold"])
    mounts(half)


def microsat(half):
    """Modular instrument decks and access panels inspired by SSTL's early EO buses."""
    x, y, z = half
    mesh = bmesh.new()
    sb.add_box(mesh, (2 * x - 0.026, 2 * y - 0.026, 2 * z - 0.026), (0, 0, 0), PANEL, 0.016)
    for axis in range(3):
        for sign in (-1, 1):
            for side in (-1, 1):
                plate(mesh, half, axis, sign, 0.545, 0.035, 0.022, (0, side * 0.263), FRAME, 0.0, 0.003)
                plate(mesh, half, axis, sign, 0.035, 0.488, 0.022, (side * 0.255, 0), FRAME, 0.0, 0.003)
                for station in (-0.215, 0.0, 0.215):
                    bolt(mesh, half, axis, sign, 0.0075, (station, side * 0.263), 0.0)
            plate(mesh, half, axis, sign, 0.455, 0.48, 0.013, (0, 0), DETAIL, 0.007, 0.006)
            if axis == 1:
                # Instrument deck with a dark mount receiver and paired service covers.
                plate(mesh, half, axis, sign, 0.205, 0.205, 0.016, (0, 0), PANEL, 0.002, 0.012)
                for side in (-1, 1):
                    plate(mesh, half, axis, sign, 0.073, 0.22, 0.014, (side * 0.16, 0.015), FRAME, 0.004, 0.006)
            else:
                # Access seams and connector bays give the side panels a modular layout.
                for side in (-1, 1):
                    plate(mesh, half, axis, sign, 0.405, 0.012, 0.007, (0, side * 0.174), PANEL, 0.006, 0.002)
                    plate(mesh, half, axis, sign, 0.076, 0.057, 0.013, (side * 0.145, -0.113), PANEL, 0.003, 0.004)
                    for x_offset in (-0.022, 0.022):
                        bolt(mesh, half, axis, sign, 0.0075, (side * 0.145 + x_offset, -0.113), 0.002)
    sb.box_uvs(mesh)
    sb.to_object("microsat_modular_decks", mesh, ["sb_aluminium", "sb_black_anodised", "sb_white_paint"])
    mounts(half)


def spacebus(half):
    """Gold thermal blankets and split radiator panels inspired by Bangabandhu Satellite-1."""
    x, y, z = half
    mesh = bmesh.new()
    sb.add_box(mesh, (2 * x - 0.09, 2 * y - 0.09, 2 * z - 0.09), (0, 0, 0), DETAIL, 0.045)
    for axis in range(3):
        tangents = [half[i] for i in range(3) if i != axis]
        u, v = tangents
        for sign in (-1, 1):
            # Blanket seams and four tie-down corners surround a clear mount at face centre.
            for side in (-1, 1):
                plate(mesh, half, axis, sign, 2 * u - 0.15, 0.075, 0.055, (0, side * (v - 0.095)), FRAME, 0.012, 0.008)
                plate(mesh, half, axis, sign, 0.075, 2 * v - 0.28, 0.055, (side * (u - 0.09), 0), FRAME, 0.012, 0.008)
                for station in (-0.60, -0.3, 0.3, 0.60):
                    bolt(mesh, half, axis, sign, 0.022, (station, side * (v - 0.095)), 0.006)
                for height in (-1, 1):
                    plate(mesh, half, axis, sign, 0.15, 0.15, 0.07, (side * (u - 0.095), height * (v - 0.095)), PANEL, 0.0, 0.017)
            if axis == 1:
                # Cap plates, reinforced around the modular communications deck.
                plate(mesh, half, axis, sign, 0.54, 0.54, 0.06, (0, 0), FRAME, 0.004, 0.02)
                plate(mesh, half, axis, sign, 0.37, 0.37, 0.06, (0, 0), PANEL, 0.0, 0.018)
                for side in (-1, 1):
                    plate(mesh, half, axis, sign, 0.23, 2 * v - 0.46, 0.045, (side * (u - 0.31), 0), DETAIL, 0.012, 0.023)
            else:
                for side in (-1, 1):
                    plate(mesh, half, axis, sign, 0.49, 2 * v - 0.52, 0.035, (side * (u - 0.37), 0), PANEL, 0.009, 0.024)
                    for n in (-4, -3, -2, -1, 0, 1, 2, 3, 4):
                        plate(mesh, half, axis, sign, 0.44, 0.012, 0.013, (side * (u - 0.37), n * 0.10), FRAME, 0.007)
                plate(mesh, half, axis, sign, 0.225, 0.26, 0.047, (0, 0), FRAME, 0.0, 0.023)
    sb.box_uvs(mesh, tile=0.3)
    sb.to_object("spacebus_blanket_and_radiators", mesh, ["sb_aluminium", "sb_white_paint", "sb_mli_gold"])
    mounts(half)


def build():
    records = json.loads((HERE.parents[1] / "data" / "buses.json").read_text())
    dimensions = {entry["id"]: entry["dimensionsMeters"] for entry in records}
    for bus_id, model in (
        ("bus_cubesat_12u", cubesat),
        ("bus_microsat_50", microsat),
        ("bus_heavy_geo_lunar", spacebus),
    ):
        x, y, z = dimensions[bus_id]
        sb.reset_scene()
        model((x / 2, z / 2, y / 2))
        sb.save_and_export(str(HERE / (bus_id + ".py")))


if __name__ == "__main__":
    build()
