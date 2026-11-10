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

## Metallic materials look black with nothing to reflect; a sky lights reflections while the
## background stays a flat colour.
static func use_sky_reflections(environment: Environment) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6f86a6")
	sky_material.sky_horizon_color = Color("b8c4d4")
	sky_material.ground_horizon_color = Color("6d7480")
	sky_material.ground_bottom_color = Color("1b1f26")
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
