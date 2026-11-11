"""Helpers for the scripted models in art_source/<category>/<id>.py.

Each model script builds its scene with these helpers, saves art_source/<category>/<id>.blend
next to itself and exports it with sb_export. Coordinates are Blender's: +Z is up, +Y is front.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sb_export  # noqa: E402

LIBRARY = os.path.normpath(os.path.join(HERE, "..", "materials", "sb_materials.blend"))
_materials = {}


def reset_scene(fps=30, frame_end=60):
    for collection in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.actions, bpy.data.images):
        for block in list(collection):
            collection.remove(block)
    _materials.clear()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = fps
    scene.frame_start, scene.frame_end = 0, frame_end
    return scene


def material(name):
    if name not in _materials:
        with bpy.data.libraries.load(LIBRARY, link=False) as (_, target):
            target.materials = [name]
        _materials[name] = target.materials[0]
    return _materials[name]


def box_uvs(bm, tile=0.1):
    """Project each face onto the plane facing its dominant normal; one UV unit per tile metres."""
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        u_axis, v_axis = [i for i in range(3) if i != axis]
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co[u_axis] / tile, loop.vert.co[v_axis] / tile)


def to_object(name, bm, materials, parent=None, smooth_angle=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    if smooth_angle is not None:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    return obj


def add_box(bm, size, center, material_index=0, bevel=0.0):
    """Append an axis-aligned box to bm. size and center are (x, y, z) in metres."""
    result = bmesh.ops.create_cube(bm, size=1.0)
    verts = result["verts"]
    for vert in verts:
        vert.co = Vector((vert.co.x * size[0] + center[0], vert.co.y * size[1] + center[1], vert.co.z * size[2] + center[2]))
    faces = {face for vert in verts for face in vert.link_faces}
    if bevel > 0:
        edges = list({edge for vert in verts for edge in vert.link_edges})
        new = bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
        faces |= set(new["faces"])
        faces = {face for face in faces if face.is_valid}
    for face in faces:
        face.material_index = material_index
    return verts


def add_cylinder(bm, radius, depth, center, axis="Z", segments=12, material_index=0):
    """Append a closed cylinder whose axis runs along X, Y or Z."""
    result = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
    verts = result["verts"]
    for vert in verts:
        x, y, z = vert.co
        if axis == "X":
            x, y, z = z, y, x
        elif axis == "Y":
            x, y, z = x, z, y
        vert.co = Vector((x + center[0], y + center[1], z + center[2]))
    for face in {face for vert in verts for face in vert.link_faces}:
        face.material_index = material_index
    return verts


def add_lathe(bm, profile, segments, material_index=0, uv=None, closed=False, arc=(0.0, 360.0), span_materials=None):
    """Revolve a (radius, z) profile around the Z axis.

    uv(fraction, radius, z, index) returns the (u, v) for a profile point, where fraction is
    the position around the arc (0 to 1). closed joins the last profile point to the first.
    arc is the swept range in degrees, measured from +X; a partial arc of a closed profile is
    capped at both ends. span_materials gives a material index per profile span.
    """
    uv_layer = bm.loops.layers.uv.verify()
    full = abs(arc[1] - arc[0] - 360.0) < 1e-6
    count = segments if full else segments + 1
    angles = [math.radians(arc[0] + (arc[1] - arc[0]) * i / segments) for i in range(count)]
    rings = []
    for radius, z in profile:
        if radius <= 1e-6:
            rings.append([bm.verts.new((0.0, 0.0, z))] * count)
        else:
            rings.append([bm.verts.new((radius * math.cos(a), radius * math.sin(a), z)) for a in angles])
    pairs = list(range(len(profile) - 1)) + ([len(profile) - 1] if closed else [])
    faces = []
    for p in pairs:
        q = (p + 1) % len(profile)
        index = span_materials[p] if span_materials else material_index
        for i in range(segments):
            j = (i + 1) % count
            corners = [(rings[p][i], i, p), (rings[p][j], i + 1, p), (rings[q][j], i + 1, q), (rings[q][i], i, q)]
            unique = []
            for corner in corners:
                if corner[0] not in [c[0] for c in unique]:
                    unique.append(corner)
            if len(unique) < 3:
                continue
            face = bm.faces.new([c[0] for c in unique])
            face.material_index = index
            for loop, (_, k, point) in zip(face.loops, unique):
                radius, z = profile[point]
                loop[uv_layer].uv = uv(k / segments, radius, z, point) if uv else (k / segments, point / max(1, len(profile) - 1))
            faces.append(face)
    if closed and not full:
        for end in (0, count - 1):
            verts = []
            for ring in rings:
                if ring[end] not in verts:
                    verts.append(ring[end])
            face = bm.faces.new(verts)
            face.material_index = material_index
            for loop in face.loops:
                loop[uv_layer].uv = (loop.vert.co.x, loop.vert.co.z)
            faces.append(face)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def add_empty(name, location, direction, parent=None, size=0.05):
    """A Single Arrow empty whose arrow (local +Z, Godot +Y) points along direction.

    location is in world space; a parent must be unrotated and unscaled.
    """
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "SINGLE_ARROW"
    empty.empty_display_size = size
    bpy.context.scene.collection.objects.link(empty)
    direction = Vector(direction).normalized()
    if direction.z < -0.9999:
        # rotation_difference picks an arbitrary axis for a half turn; roll about X keeps Y.
        empty.rotation_euler = (math.pi, 0, 0)
    else:
        empty.rotation_euler = Vector((0, 0, 1)).rotation_difference(direction).to_euler()
    empty.parent = parent
    empty.location = Vector(location) - (parent.location if parent else Vector())
    return empty


def translate(bm, offset):
    for vert in bm.verts:
        vert.co -= Vector(offset)


def reference_cube(location=(1.5, 0, 0.5)):
    bm = bmesh.new()
    add_box(bm, (1, 1, 1), (0, 0, 0))
    obj = to_object("reference_cube_1m", bm, ["sb_white_paint"])
    obj.location = location
    obj.hide_render = True
    return obj


def save_and_export(script_file):
    blend = os.path.splitext(os.path.abspath(script_file))[0] + ".blend"
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    backup = blend + "1"
    if os.path.exists(backup):
        os.remove(backup)
    try:
        sb_export.run(blend)
    except sb_export.ExportError as error:
        print("ERROR: %s" % error)
        sys.exit(1)
