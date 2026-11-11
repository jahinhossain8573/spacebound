extends RefCounted

## Rules from docs/art/3d-asset-spec.md that can be checked on an imported model.

const LIBRARY_MATERIALS := ["sb_white_paint", "sb_black_composite", "sb_mli_gold", "sb_mli_silver", "sb_solar_cell", "sb_aluminium", "sb_nozzle", "sb_black_anodised", "sb_glass_lens"]
const TRIANGLES := {"parts": Vector2i(200, 4000), "buses": Vector2i(1000, 6000), "launchers": Vector2i(8000, 25000), "environment": Vector2i(0, 15000), "vehicles": Vector2i(0, 12000)}
const MAX_TEXTURE := {"parts": 512, "buses": 1024, "launchers": 2048, "environment": 2048, "vehicles": 1024}
const BUS_EMPTIES := {"mount_top": Vector3.UP, "mount_bottom": Vector3.DOWN, "mount_front": Vector3.FORWARD, "mount_back": Vector3.BACK, "mount_left": Vector3.LEFT, "mount_right": Vector3.RIGHT, "array_hinge_left": Vector3.LEFT, "array_hinge_right": Vector3.RIGHT, "engine_mount": Vector3.DOWN}
const ROCKET_NODES := ["stage_1", "payload_mount", "exhaust_stage_1", "fairing_left", "fairing_right"]
const SIZE_TOLERANCE := 0.1
const AXIS_TOLERANCE := 0.98

## Checks an instantiated model. record is its game data entry, or {} when it has none.
## Returns errors (spec violations), warnings (worth a look) and measured triangles and size.
static func check(category: String, root: Node3D, record: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var meshes := _meshes(root)
	var result := {"errors": errors, "warnings": warnings, "triangles": 0, "size": Vector3.ZERO}
	if meshes.is_empty():
		errors.append("contains no meshes")
		return result
	var bounds := _bounds(root, meshes)
	result.size = bounds.size
	result.triangles = _triangles(meshes)
	var budget: Vector2i = TRIANGLES[category]
	if result.triangles > budget.y:
		errors.append("%d triangles; the %s budget is %d" % [result.triangles, category, budget.y])
	elif result.triangles < budget.x:
		warnings.append("%d triangles, below the usual %d for %s" % [result.triangles, budget.x, category])
	_check_materials(category, meshes, errors, warnings)
	_check_animation(root, record, errors, warnings)
	match category:
		"buses": _check_bus(root, bounds, record, errors)
		"parts": _check_part(bounds, errors)
		"launchers": _check_launcher(root, bounds, record, errors)
	return result

static func _check_materials(category: String, meshes: Array[MeshInstance3D], errors: Array[String], warnings: Array[String]) -> void:
	var materials := {}
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material:
				materials[material] = true
	if materials.size() > 3:
		errors.append("%d materials; the limit is 3" % materials.size())
	var limit: int = MAX_TEXTURE[category]
	for material: Material in materials:
		var label := material.resource_name if not material.resource_name.is_empty() else "unnamed"
		if not material is BaseMaterial3D:
			errors.append("material '%s' is a %s; use Principled BSDF only" % [label, material.get_class()])
			continue
		if label not in LIBRARY_MATERIALS:
			warnings.append("material '%s' is not in the shared library" % label)
		for param in BaseMaterial3D.TEXTURE_MAX:
			var texture: Texture2D = material.get_texture(param)
			if not texture:
				continue
			var width := texture.get_width()
			var height := texture.get_height()
			if width & (width - 1) or height & (height - 1):
				errors.append("material '%s' has a %d × %d texture; sizes must be powers of two" % [label, width, height])
			elif maxi(width, height) > limit:
				errors.append("material '%s' has a %d px texture; the %s limit is %d" % [label, maxi(width, height), category, limit])

static func _check_animation(root: Node3D, record: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	var deploy: Animation = null
	for player: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
		for animation_name in player.get_animation_list():
			if animation_name == "deploy":
				deploy = player.get_animation(animation_name)
			else:
				warnings.append("animation '%s' is not used by the game" % animation_name)
	if deploy == null:
		if record.get("deployable", false):
			errors.append("deployable part has no 'deploy' animation")
		return
	if deploy.loop_mode != Animation.LOOP_NONE:
		errors.append("'deploy' animation loops; it must play once")
	if deploy.length < 1.0 or deploy.length > 4.0:
		warnings.append("'deploy' animation lasts %.2f s; aim for about 2 s" % deploy.length)

static func _check_bus(root: Node3D, bounds: AABB, record: Dictionary, errors: Array[String]) -> void:
	if record.has("dimensionsMeters"):
		var dims: Array = record.dimensionsMeters
		var expected := Vector3(dims[0], dims[1], dims[2])
		for axis in 3:
			if absf(bounds.size[axis] - expected[axis]) > expected[axis] * SIZE_TOLERANCE:
				errors.append("size is %s m; the game data says %s m (x, y, z)" % [_format(bounds.size), _format(expected)])
				break
	if bounds.get_center().length() > bounds.size[bounds.get_longest_axis_index()] * 0.05:
		errors.append("origin is not at the geometric centre (centre is at %s)" % _format(bounds.get_center()))
	for empty_name: String in BUS_EMPTIES:
		var node := root.find_child(empty_name, true, false) as Node3D
		if node == null:
			errors.append("missing empty '%s'" % empty_name)
			continue
		var direction: Vector3 = BUS_EMPTIES[empty_name]
		var transform := _relative(root, node)
		if transform.basis.y.normalized().dot(direction) < AXIS_TOLERANCE:
			errors.append("'%s' +Y points %s; it must point %s" % [empty_name, _format(transform.basis.y.normalized()), _format(direction)])
		elif empty_name in ["mount_front", "mount_back"]:
			if absf(transform.basis.x.normalized().x) < AXIS_TOLERANCE:
				errors.append("'%s' is rolled; its X axis must stay along the bus X axis" % empty_name)
		elif absf(transform.basis.z.normalized().z) < AXIS_TOLERANCE:
			errors.append("'%s' is rolled; its Z axis must stay along the bus Z axis" % empty_name)
		var face := maxf(bounds.end.dot(direction), bounds.position.dot(direction))
		var along := transform.origin.dot(direction)
		if empty_name.begins_with("array_hinge"):
			if along <= 0.0:
				errors.append("'%s' is on the wrong side of the bus" % empty_name)
		elif absf(along - face) > bounds.size.length() * 0.05 or (transform.origin - direction * along).length() > bounds.size.length() * 0.05:
			errors.append("'%s' is at %s, not the centre of its face" % [empty_name, _format(transform.origin)])

static func _check_part(bounds: AABB, errors: Array[String]) -> void:
	if bounds.position.y < -maxf(0.002, bounds.size.y * 0.02):
		errors.append("geometry reaches %.3f m below the origin; a part sits on its origin and extends along +Y" % -bounds.position.y)

static func _check_launcher(root: Node3D, bounds: AABB, record: Dictionary, errors: Array[String]) -> void:
	if absf(bounds.position.y) > 0.05:
		errors.append("base is at y = %.2f m; the origin must be at the base, on the ground" % bounds.position.y)
	var center := bounds.get_center()
	if Vector2(center.x, center.z).length() > maxf(bounds.size.x, bounds.size.z) * 0.05:
		errors.append("origin is not on the rocket's centre line")
	for node_name in ROCKET_NODES:
		if root.find_child(node_name, true, false) == null:
			errors.append("missing '%s'" % node_name)
	for stage in range(1, 10):
		var has_stage := root.find_child("stage_%d" % stage, true, false) != null
		var exhaust := root.find_child("exhaust_stage_%d" % stage, true, false) as Node3D
		if has_stage != (exhaust != null):
			errors.append("stage_%d and exhaust_stage_%d must come as a pair" % [stage, stage])
		if exhaust and _relative(root, exhaust).basis.y.normalized().dot(Vector3.UP) < AXIS_TOLERANCE:
			errors.append("'exhaust_stage_%d' -Y must point down the plume" % stage)
	var fairing: Array[MeshInstance3D] = []
	for side in ["fairing_left", "fairing_right"]:
		var node := root.find_child(side, true, false)
		if node:
			fairing.append_array(_meshes(node))
	if fairing.is_empty() or not record.has("fairingDiameterMeters"):
		return
	var shell := _bounds(root, fairing)
	var diameter := maxf(shell.size.x, shell.size.z)
	if absf(diameter - record.fairingDiameterMeters) > record.fairingDiameterMeters * SIZE_TOLERANCE:
		errors.append("fairing is %.2f m wide; the game data says %.2f m" % [diameter, record.fairingDiameterMeters])
	if absf(shell.size.y - record.fairingHeightMeters) > record.fairingHeightMeters * SIZE_TOLERANCE:
		errors.append("fairing is %.2f m tall; the game data says %.2f m" % [shell.size.y, record.fairingHeightMeters])
	var payload := root.find_child("payload_mount", true, false) as Node3D
	if payload and not shell.grow(0.01).has_point(_relative(root, payload).origin):
		errors.append("'payload_mount' is outside the fairing")

static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh:
		found.append(node)
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		if child.mesh:
			found.append(child)
	return found

static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current and current != root:
		if current is Node3D:
			transform = current.transform * transform
		current = current.get_parent()
	return transform

static func _bounds(root: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var bounds := _relative(root, meshes[0]) * meshes[0].mesh.get_aabb()
	for mesh in meshes.slice(1):
		bounds = bounds.merge(_relative(root, mesh) * mesh.mesh.get_aabb())
	return bounds

static func _triangles(meshes: Array[MeshInstance3D]) -> int:
	var total := 0
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			total += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return total

static func _format(value: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]
