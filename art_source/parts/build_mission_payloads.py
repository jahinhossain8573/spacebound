"""Build original low-poly flight hardware for Missions 1–5.

Run in Blender with --background --factory-startup --python. The sources
depict the exposed optics, antennas and propulsion hardware of each installed
part. Internal avionics remain inside the spacecraft bus.
"""

import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "tools"))
import sb_build as sb

OPTICS = ["sb_aluminium", "sb_black_anodised", "sb_glass_lens"]
RF = ["sb_aluminium", "sb_black_anodised", "sb_mli_gold"]
PROP = ["sb_aluminium", "sb_black_anodised", "sb_nozzle"]


def finish(name, mesh, materials):
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    sb.box_uvs(mesh)
    return sb.to_object(name, mesh, materials, smooth_angle=35)


def lens(mesh, x, y, base, radius, height):
    """A stepped barrel with a recessed glass element and an open bezel."""
    profile = [
        (0.0, base), (radius * 0.85, base), (radius * 0.85, base + height * 0.72),
        (radius, base + height * 0.72), (radius, base + height),
        (radius * 0.76, base + height), (radius * 0.76, base + height * 0.74),
        (0.0, base + height * 0.74),
    ]
    faces = sb.add_lathe(mesh, profile, 24, span_materials=[1, 1, 0, 1, 1, 1, 2])
    for v in {v for f in faces for v in f.verts}:
        v.co.x += x
        v.co.y += y


def corner_fasteners(mesh, width, depth, height, radius=0.002):
    for x in (-width * 0.40, width * 0.40):
        for y in (-depth * 0.40, depth * 0.40):
            sb.add_cylinder(mesh, radius, radius * 0.5, (x, y, height + radius * 0.25), segments=8)


def nanocam():
    # GomSpace NanoCam C1U, 96 x 90 mm card envelope; C-mount 35 mm lens option.
    mesh = bmesh.new()
    sb.add_box(mesh, (0.096, 0.09, 0.005), (0, 0, 0.0025), 0, bevel=0.001)
    sb.add_box(mesh, (0.061, 0.057, 0.008), (0, 0, 0.009), 1, bevel=0.001)
    sb.add_cylinder(mesh, 0.021, 0.004, (0, 0, 0.015), segments=24)
    lens(mesh, 0, 0, 0.016, 0.0175, 0.0347)
    corner_fasteners(mesh, 0.096, 0.09, 0.005)
    finish("c_mount_camera", mesh, OPTICS)


def hyperscout():
    # Cosine HyperScout 2: distinct VNIR and thermal optical channels.
    mesh = bmesh.new()
    sb.add_box(mesh, (0.23, 0.15, 0.013), (0, 0, 0.0065), 0, bevel=0.002)
    sb.add_box(mesh, (0.206, 0.132, 0.092), (0, 0, 0.059), 0, bevel=0.006)
    sb.add_box(mesh, (0.197, 0.124, 0.012), (0, 0, 0.109), 1, bevel=0.003)
    lens(mesh, -0.048, 0, 0.115, 0.037, 0.024)
    lens(mesh, 0.051, 0, 0.115, 0.025, 0.015)
    for y in (-0.042, -0.021, 0, 0.021, 0.042):
        sb.add_box(mesh, (0.008, 0.012, 0.052), (0.106, y, 0.061), 0, bevel=0.001)
    corner_fasteners(mesh, 0.23, 0.15, 0.013, radius=0.004)
    finish("vnir_tir_imager", mesh, OPTICS)


def lroc():
    # LROC WAC, with separate visible and UV optical paths and short hoods.
    mesh = bmesh.new()
    sb.add_box(mesh, (0.147, 0.117, 0.008), (0, 0, 0.004), 0, bevel=0.002)
    sb.add_box(mesh, (0.128, 0.091, 0.052), (0, 0, 0.033), 0, bevel=0.004)
    sb.add_box(mesh, (0.112, 0.078, 0.008), (0, 0, 0.062), 1, bevel=0.002)
    lens(mesh, -0.027, 0.004, 0.066, 0.023, 0.017)
    lens(mesh, 0.026, 0.004, 0.066, 0.016, 0.013)
    corner_fasteners(mesh, 0.147, 0.117, 0.008)
    finish("visible_uv_camera", mesh, OPTICS)


def sun_sensor():
    mesh = bmesh.new()
    sb.add_box(mesh, (0.034, 0.04, 0.003), (0, 0, 0.0015), 0, bevel=0.0007)
    sb.add_box(mesh, (0.025, 0.029, 0.015), (0, 0, 0.0105), 1, bevel=0.0017)
    sb.add_box(mesh, (0.015, 0.015, 0.002), (0, 0, 0.0185), 0, bevel=0.0005)
    sb.add_box(mesh, (0.008, 0.008, 0.001), (0, 0, 0.0195), 2)
    corner_fasteners(mesh, 0.034, 0.04, 0.003, radius=0.001)
    finish("sun_angle_sensor", mesh, OPTICS)


def star_tracker():
    mesh = bmesh.new()
    sb.add_box(mesh, (0.082, 0.077, 0.005), (0, 0, 0.0025), 0, bevel=0.001)
    sb.add_box(mesh, (0.072, 0.065, 0.032), (0, 0, 0.020), 1, bevel=0.002)
    lens(mesh, 0.004, -0.001, 0.036, 0.023, 0.052)
    corner_fasteners(mesh, 0.082, 0.077, 0.005)
    finish("baffled_star_tracker", mesh, OPTICS)


def crater():
    mesh = bmesh.new()
    sb.add_box(mesh, (0.28, 0.168, 0.008), (0, 0, 0.004), 0, bevel=0.002)
    sb.add_box(mesh, (0.137, 0.147, 0.10), (-0.057, 0, 0.056), 2, bevel=0.005)
    for y in (-0.057, 0.057):
        sb.add_box(mesh, (0.114, 0.009, 0.091), (0.068, y, 0.054), 2, bevel=0.002)
    sb.add_cylinder(mesh, 0.037, 0.118, (0.075, 0, 0.068), axis="Y", segments=20, material_index=1)
    for y in (-0.050, 0.050):
        sb.add_cylinder(mesh, 0.041, 0.012, (0.075, y, 0.068), axis="Y", segments=20)
    finish("cosmic_ray_telescope", mesh, RF)


def fluxgate():
    # ESA's SMILE fluxgate head uses a low-profile housing and an alignment cube.
    mesh = bmesh.new()
    sb.add_box(mesh, (0.056, 0.042, 0.004), (0, 0, 0.002), 0, bevel=0.0008)
    sb.add_box(mesh, (0.047, 0.033, 0.027), (0, 0, 0.0175), 1, bevel=0.0025)
    sb.add_box(mesh, (0.043, 0.029, 0.0015), (0, 0, 0.0315), 2, bevel=0.0004)
    sb.add_box(mesh, (0.008, 0.008, 0.008), (-0.016, -0.009, 0.036), 0, bevel=0.0005)
    sb.add_cylinder(mesh, 0.004, 0.008, (0.024, 0, 0.012), axis="X", segments=16)
    corner_fasteners(mesh, 0.056, 0.042, 0.004, radius=0.0013)
    finish("fluxgate_sensor_head", mesh, RF)


def patch(size, elements):
    # The transceiver itself is internal; show the antenna patch fitted outside.
    mesh = bmesh.new()
    sb.add_box(mesh, (size, size, 0.004), (0, 0, 0.002), 0, bevel=0.001)
    sb.add_box(mesh, (size * 0.84, size * 0.84, 0.0025), (0, 0, 0.00475), 1, bevel=0.0006)
    span = size * 0.58
    gap = span / elements
    for i in range(elements):
        for j in range(elements):
            x, y = (i + 0.5) * gap - span / 2, (j + 0.5) * gap - span / 2
            sb.add_box(mesh, (gap * 0.83, gap * 0.83, 0.0012), (x, y, 0.0065), 2, bevel=0.0003)
    corner_fasteners(mesh, size, size, 0.004)
    finish("external_patch_antenna", mesh, RF)


def stay(mesh, start, end, radius):
    a, b = Vector(start), Vector(end)
    direction = b - a
    rotation = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    for v in sb.add_cylinder(mesh, radius, direction.length, (0, 0, 0), segments=8):
        v.co = rotation @ v.co + (a + b) * 0.5


def reflector(mesh, x, radius, depth, base):
    """A hollow parabolic reflector with a central feed and support struts."""
    back = [(radius * i / 6, base + depth * (i / 6) ** 2) for i in range(7)]
    shell = back + [(r, z + radius * 0.033) for r, z in reversed(back)]
    faces = sb.add_lathe(mesh, shell, 32, span_materials=[0] * 7 + [2] * 6)
    for v in {v for f in faces for v in f.verts}:
        v.co.x += x
    sb.add_cylinder(mesh, radius * 0.14, base, (x, 0, base / 2), segments=16, material_index=1)
    focus = base + depth + radius * 0.19
    sb.add_cylinder(mesh, radius * 0.12, radius * 0.22, (x, 0, focus), segments=16, material_index=1)
    for i in range(3):
        theta = math.tau * i / 3
        edge = (x + radius * 0.91 * math.cos(theta), radius * 0.91 * math.sin(theta), base + depth * 0.87)
        stay(mesh, edge, (x, 0, focus), radius * 0.016)


def deep_space_dish():
    mesh = bmesh.new()
    sb.add_box(mesh, (0.105, 0.105, 0.008), (0, 0, 0.004), 0, bevel=0.002)
    reflector(mesh, 0, 0.15, 0.038, 0.021)
    finish("cassegrain_antenna", mesh, RF)


def geo_payload():
    # Spacebus-style multi-reflector payload; game transponders remain inside.
    mesh = bmesh.new()
    sb.add_box(mesh, (1.33, 0.51, 0.035), (0, 0, 0.0175), 0, bevel=0.008)
    reflector(mesh, -0.34, 0.31, 0.098, 0.118)
    reflector(mesh, 0.34, 0.28, 0.083, 0.115)
    corner_fasteners(mesh, 1.33, 0.51, 0.035, radius=0.013)
    finish("dual_communications_reflectors", mesh, RF)


def thruster(radius, length, flange, bell_factor):
    mesh = bmesh.new()
    sb.add_cylinder(mesh, flange, length * 0.075, (0, 0, length * 0.0375), segments=24)
    sb.add_cylinder(mesh, flange * 0.67, length * 0.23, (0, 0, length * 0.175), segments=16, material_index=1)
    for x in (-flange * 0.46, flange * 0.46):
        sb.add_cylinder(mesh, flange * 0.16, length * 0.17, (x, 0, length * 0.17), segments=12)
    finish("mount_and_valves", mesh, PROP[:2])
    bell = bmesh.new()
    throat = radius * bell_factor
    sb.add_lathe(bell, [
        (throat * 1.18, length * 0.25), (throat * 1.12, length * 0.41),
        (radius * 0.67, length * 0.63), (radius * 0.91, length * 0.84), (radius, length),
        (radius * 0.95, length), (radius * 0.86, length * 0.85), (radius * 0.62, length * 0.64),
        (throat, length * 0.41), (throat * 1.02, length * 0.25),
    ], 32, closed=True, uv=lambda fraction, _r, z, _i: (fraction, (z - length * 0.25) / (length * 0.75)))
    sb.to_object("nozzle_bell", bell, PROP[2:], smooth_angle=35)


def mips():
    mesh = bmesh.new()
    sb.add_box(mesh, (0.09, 0.09, 0.027), (0, 0, 0.0135), 0, bevel=0.004)
    sb.add_box(mesh, (0.080, 0.080, 0.004), (0, 0, 0.028), 0, bevel=0.002)
    corner_fasteners(mesh, 0.09, 0.09, 0.030)
    sb.add_cylinder(mesh, 0.005, 0.002, (0, 0, 0.031), segments=12, material_index=1)
    for axis in ("X", "Y"):
        for sign in (-1, 1):
            center = (0.044 * sign, 0, 0.016) if axis == "X" else (0, 0.044 * sign, 0.016)
            sb.add_cylinder(mesh, 0.005, 0.004, center, axis=axis, segments=12, material_index=1)
    finish("cold_gas_thruster_pack", mesh, PROP[:2])


MODELS = {
    "inst_nanocam_c1u": nanocam,
    "inst_hyperscout2": hyperscout,
    "inst_lroc_wac": lroc,
    "adcs_fine_sun_sensor": sun_sensor,
    "adcs_st16": star_tracker,
    "inst_crater": crater,
    "inst_fluxgate_mag": fluxgate,
    "com_syrlinks_ewc27": lambda: patch(0.098, 1),
    "com_syrlinks_ewc30": lambda: patch(0.14, 4),
    "com_gd_sdst": deep_space_dish,
    "inst_kuka_transponder_suite": geo_payload,
    "prop_aerojet_r4d15": lambda: thruster(0.147, 0.49, 0.088, 0.18),
    "prop_mr103g": lambda: thruster(0.012, 0.085, 0.021, 0.35),
    "prop_vacco_mips": mips,
}


def main():
    for model_id, build in MODELS.items():
        scene = sb.reset_scene()
        build()
        scene.frame_set(0)
        # Keep the source viewport centred on the hardware at a useful scale.
        meshes = [obj for obj in scene.objects if obj.type == "MESH"]
        span = max(v.co.length for obj in meshes for v in obj.data.vertices)
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == "VIEW_3D":
                    area.spaces.active.region_3d.view_distance = span * 3.5
                    area.spaces.active.region_3d.view_location = (0, 0, span * 0.2)
        sb.save_and_export(str(HERE / f"{model_id}.py"))


if __name__ == "__main__":
    main()
