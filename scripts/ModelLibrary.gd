extends RefCounted

const CATEGORIES := ["launchers", "buses", "parts", "environment", "vehicles"]

static func path_for(category: String, id: String) -> String:
	return "res://assets/models/%s/%s.glb" % [category, id]

static func has_model(category: String, id: String) -> bool:
	return ResourceLoader.exists(path_for(category, id))

## Returns null when no model has been delivered yet, so callers can keep their primitive stand-in.
static func instantiate(category: String, id: String) -> Node3D:
	if not has_model(category, id):
		return null
	var scene := load(path_for(category, id)) as PackedScene
	return scene.instantiate() as Node3D if scene else null
