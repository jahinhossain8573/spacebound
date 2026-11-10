"""Check the open .blend against docs/art/3d-asset-spec.md and export it to the game.

The file must be saved as art_source/<category>/<id>.blend; it exports to
assets/models/<category>/<id>.glb. Run it from Blender's Scripting workspace,
or headless from the repository root:
    blender -b art_source/<category>/<id>.blend --python art_source/tools/sb_export.py

Objects disabled for rendering (camera icon) are not exported; use that for
reference cubes, photo planes and the like.
"""

import os
import re
import sys

import bpy

CATEGORIES = ("launchers", "buses", "parts", "environment", "vehicles")
MAX_TRIANGLES = {"parts": 4000, "buses": 6000, "launchers": 25000, "environment": 15000, "vehicles": 12000}
LIBRARY_MATERIALS = {
    "sb_white_paint", "sb_black_composite", "sb_mli_gold", "sb_mli_silver", "sb_solar_cell",
    "sb_aluminium", "sb_nozzle", "sb_black_anodised", "sb_glass_lens",
}
ALLOWED_NODES = {"BSDF_PRINCIPLED", "OUTPUT_MATERIAL", "TEX_IMAGE", "NORMAL_MAP", "TEX_COORD", "MAPPING", "UVMAP"}
GODOT_SUFFIXES = re.compile(r"(-|_)(col|convcol|colonly|convcolonly|rigid|vehicle|wheel|navmesh|occ|occonly|noimp|loop|cycle)$", re.IGNORECASE)


class ExportError(Exception):
    pass


def destination(blend_path):
    source_dir = os.path.dirname(os.path.abspath(blend_path))
    category = os.path.basename(source_dir)
    asset_id = os.path.splitext(os.path.basename(blend_path))[0]
    root = os.path.dirname(os.path.dirname(source_dir))
    if os.path.basename(os.path.dirname(source_dir)) != "art_source" or category not in CATEGORIES:
        raise ExportError("Save the file as art_source/<category>/<id>.blend, with category one of %s" % ", ".join(CATEGORIES))
    if not re.fullmatch(r"[a-z0-9_]+", asset_id):
        raise ExportError("File name '%s' must be a snake_case game data id" % asset_id)
    return category, asset_id, os.path.join(root, "assets", "models", category, asset_id + ".glb")


def is_animated(obj):
    while obj:
        if obj.animation_data and (obj.animation_data.action or obj.animation_data.nla_tracks):
            return True
        obj = obj.parent
    return False


def check(scene, category):
    errors, warnings = [], []
    units = scene.unit_settings
    if units.system != "METRIC" or abs(units.scale_length - 1.0) > 1e-6:
        errors.append("Scene units must be Metric with unit scale 1.0 (1 unit = 1 m)")
    objects = [obj for obj in scene.objects if not obj.hide_render]
    materials = set()
    triangles = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if re.search(r"\.\d{3}$", obj.name):
            warnings.append("'%s' has a Blender duplicate suffix; Godot will import it as '%s'" % (obj.name, obj.name.replace(".", "_")))
        if GODOT_SUFFIXES.search(obj.name):
            errors.append("'%s' ends in a Godot import hint suffix; rename it" % obj.name)
        if obj.type != "MESH":
            continue
        if any(abs(abs(s) - 1.0) > 1e-4 for s in obj.scale) or any(s < 0 for s in obj.scale):
            errors.append("'%s' has scale %s; apply scale (Ctrl+A > Scale)" % (obj.name, tuple(round(s, 4) for s in obj.scale)))
        if not is_animated(obj) and obj.parent is None and any(abs(r) > 1e-4 for r in obj.rotation_euler):
            warnings.append("'%s' is static but rotated; apply rotation unless it is intentional" % obj.name)
        mesh = obj.evaluated_get(depsgraph).to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        obj.evaluated_get(depsgraph).to_mesh_clear()
        for slot in obj.material_slots:
            if slot.material:
                materials.add(slot.material)
    if len(materials) > 3:
        errors.append("%d materials (%s); the limit is 3" % (len(materials), ", ".join(sorted(m.name for m in materials))))
    for material in materials:
        if material.name not in LIBRARY_MATERIALS:
            warnings.append("Material '%s' is not in the shared library" % material.name)
        if not material.node_tree:
            errors.append("Material '%s' has no node tree" % material.name)
            continue
        extra = sorted({node.type for node in material.node_tree.nodes} - ALLOWED_NODES)
        if extra:
            errors.append("Material '%s' uses unsupported nodes: %s" % (material.name, ", ".join(extra)))
    if triangles > MAX_TRIANGLES[category]:
        errors.append("%d triangles; the %s budget is %d" % (triangles, category, MAX_TRIANGLES[category]))
    for action in bpy.data.actions:
        if action.users and action.name != "deploy":
            warnings.append("Action '%s' will be exported; only 'deploy' is used by the game" % action.name)
    return errors, warnings, triangles


def export(filepath):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    # The rest pose the game shows before 'deploy' plays is whatever frame 0 holds: folded.
    bpy.context.scene.frame_set(0)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        use_renderable=True,
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_extras=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_merge_animation="ACTION",
    )


def run(blend_path=None):
    blend_path = blend_path or bpy.data.filepath
    if not blend_path:
        raise ExportError("Save the .blend first")
    category, asset_id, filepath = destination(blend_path)
    errors, warnings, triangles = check(bpy.context.scene, category)
    for message in warnings:
        print("WARN: " + message)
    for message in errors:
        print("ERROR: " + message)
    if errors:
        raise ExportError("%s: %d error(s); nothing exported" % (asset_id, len(errors)))
    export(filepath)
    print("Exported %s (%d triangles) to %s" % (asset_id, triangles, filepath))
    return filepath


if __name__ == "__main__":
    try:
        run()
    except ExportError as error:
        print("ERROR: %s" % error)
        if bpy.app.background:
            sys.exit(1)
