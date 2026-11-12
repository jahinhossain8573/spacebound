extends RefCounted

## Places part models on a bus's attachment points. Comms go on top, instruments on the front,
## engines and landing gear underneath, and solar wings at the hinges (SPA-9); each part takes the
## first free mount in its list.

const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")
const MOUNTS := ["mount_top", "mount_bottom", "mount_front", "mount_back", "mount_left", "mount_right", "array_hinge_left", "array_hinge_right", "engine_mount"]
const LONG_FACES := ["mount_left", "mount_right", "mount_top", "mount_bottom"]
const END_PLATES := ["com_endurosat_uhf"]
const P31U := "pwr_gomspace_p31u"
const EHAWK := "pwr_mma_ehawk_s"
const P31U_FIT := Vector2(0.017, 0.04)

## The spacecraft built from models, in metres with the bus centred on the origin, or null when
## the bus has no model yet.
static func build(bus: Dictionary, parts: Array) -> Node3D:
	var root := MODEL_LIBRARY.instantiate("buses", bus.id)
	if root == null:
		return null
	var mounts := mounts_of(root)
	var occupied := {}
	for part: Dictionary in parts:
		for instance in place_part(part, mounts, occupied, dimensions_of(bus)):
			root.add_child(instance)
	return root

## Preview the deployed configuration without starting a flight animation.
static func show_deployed(root: Node3D) -> void:
	for player: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation("deploy"):
			player.play("deploy")
			player.seek(player.get_animation("deploy").length, true)
			player.pause()

static func mounts_of(bus_root: Node3D) -> Dictionary:
	var mounts := {}
	for mount_name in MOUNTS:
		var node := bus_root.get_node_or_null(mount_name) as Node3D
		if node:
			mounts[mount_name] = node
	return mounts

static func dimensions_of(bus: Dictionary) -> Vector3:
	var dims: Array = bus.dimensionsMeters
	return Vector3(dims[0], dims[1], dims[2])

## Returns the part's model instances positioned in the mounts' parent space, and marks the mounts
## they use in occupied. Returns an empty array when the part has no model or no mount is free.
static func place_part(part: Dictionary, mounts: Dictionary, occupied: Dictionary, dimensions: Vector3) -> Array[Node3D]:
	var placed: Array[Node3D] = []
	if not MODEL_LIBRARY.has_model("parts", part.id):
		return placed
	var wanted := 2 if part.id == P31U or (_is_wing(part) and part.id != EHAWK) else 1
	for mount_name in _preferred_mounts(part):
		if placed.size() == wanted:
			break
		if occupied.has(mount_name) or not mounts.has(mount_name):
			continue
		var instance := MODEL_LIBRARY.instantiate("parts", part.id)
		instance.transform = (mounts[mount_name] as Node3D).transform
		if part.id == P31U:
			var width := dimensions.x if mount_name in ["mount_top", "mount_bottom"] else dimensions.y
			instance.transform = instance.transform.scaled_local(Vector3((width - P31U_FIT.x) / 0.083, 1.0, (dimensions.z - P31U_FIT.y) / 0.30))
		occupied[mount_name] = true
		placed.append(instance)
	return placed

static func _is_wing(part: Dictionary) -> bool:
	return part.subsystem == "power" and part.powerGenWatts > 0 and part.isExternal

static func _preferred_mounts(part: Dictionary) -> Array:
	if part.id == P31U:
		return LONG_FACES
	if part.id in END_PLATES:
		return ["mount_front", "mount_back"]
	if part.get("thrustNewtons", 0.0) > 0.0:
		return ["engine_mount"]
	if part.id == EHAWK:
		return ["array_hinge_left", "array_hinge_right", "mount_back", "mount_top"]
	if _is_wing(part):
		return ["array_hinge_left", "array_hinge_right"]
	match part.subsystem:
		"comms": return ["mount_top", "mount_front", "mount_back"]
		"instrument": return ["mount_front", "mount_back", "mount_bottom"]
		"landing": return ["mount_bottom"]
	return ["mount_top", "mount_front", "mount_back", "mount_bottom"]
