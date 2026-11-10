extends SceneTree

const MODEL_CHECKS = preload("res://tests/model_checks.gd")
const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")
const FIXTURE := "res://tests/fixtures/models/buses/bus_spec_fixture.glb"
const MODELS_DIR := "res://assets/models"
const MAX_TOTAL_BYTES := 25 * 1024 * 1024

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func has_error(result: Dictionary, fragment: String) -> bool:
	for message: String in result.errors:
		if fragment in message:
			return true
	return false

func run_tests() -> void:
	var data := root.get_node("GlobalData")
	check(MODEL_LIBRARY.path_for("parts", "com_endurosat_uhf") == "res://assets/models/parts/com_endurosat_uhf.glb", "model path follows the data id")
	check(MODEL_LIBRARY.instantiate("parts", "no_such_part") == null, "missing model falls back to null")
	check_fixture(data)
	check_rule_violations(data)
	check_delivered_models(data)
	print("Model failures: ", failures)
	quit(1 if failures else 0)

func check_fixture(data: Node) -> void:
	var fixture: Node3D = (load(FIXTURE) as PackedScene).instantiate()
	var result := MODEL_CHECKS.check("buses", fixture, data.get_bus("bus_cubesat_1u_3u"))
	check(result.errors.is_empty(), "fixture meets the spec %s" % [result.errors])
	check((result.size - Vector3(0.1, 0.1, 0.34)).length() < 0.002, "Blender +Y exports as Godot -Z at real scale %s" % [result.size])
	var front := fixture.find_child("mount_front", true, false) as Node3D
	check(front.position.z < 0.0 and front.basis.y.dot(Vector3.FORWARD) > 0.99, "Blender Z-outward empties arrive with +Y outward")
	var player := fixture.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(player != null and player.has_animation("deploy"), "action 'deploy' imports as animation 'deploy'")
	fixture.free()

func check_rule_violations(data: Node) -> void:
	var bus: Node3D = (load(FIXTURE) as PackedScene).instantiate()
	(bus.find_child("body", true, false) as Node3D).scale.x = 2.0
	(bus.find_child("mount_front", true, false) as Node3D).rotation = Vector3.ZERO
	bus.find_child("engine_mount", true, false).free()
	(bus.find_child("mount_bottom", true, false) as Node3D).rotate_object_local(Vector3.UP, PI / 2)
	var rails := bus.find_children("rail_*", "MeshInstance3D", true, false)
	for i in 2:
		var extra := StandardMaterial3D.new()
		extra.resource_name = "extra_%d" % i
		(rails[i] as MeshInstance3D).material_override = extra
	var player := bus.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.get_animation("deploy").loop_mode = Animation.LOOP_LINEAR
	var result := MODEL_CHECKS.check("buses", bus, data.get_bus("bus_cubesat_1u_3u"))
	check(has_error(result, "the game data says"), "oversized bus rejected")
	check(has_error(result, "'mount_front' +Y points"), "misaligned mount rejected")
	check(has_error(result, "missing empty 'engine_mount'"), "missing empty rejected")
	check(has_error(result, "'mount_bottom' is rolled"), "rolled mount rejected")
	check(has_error(result, "materials; the limit is 3"), "fourth material rejected")
	check(has_error(result, "animation loops"), "looping deploy rejected")
	bus.free()
	var part := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	part.add_child(mesh)
	result = MODEL_CHECKS.check("parts", part, data.get_part("pwr_airbus_l"))
	check(has_error(result, "below the origin"), "part centred on its origin rejected")
	check(has_error(result, "no 'deploy' animation"), "deployable part without animation rejected")
	part.free()

func check_delivered_models(data: Node) -> void:
	var total_bytes := 0
	var count := 0
	for folder in DirAccess.get_directories_at(MODELS_DIR):
		check(folder in MODEL_LIBRARY.CATEGORIES, "assets/models/%s is a known category" % folder)
	for category: String in MODEL_LIBRARY.CATEGORIES:
		var folder := MODELS_DIR.path_join(category)
		var files := DirAccess.get_files_at(folder)
		for file in files:
			if file.ends_with(".import") or file.begins_with("."):
				continue
			var label := "%s/%s" % [category, file]
			if file.get_extension() in ["png", "jpg"] and _extracted_from_model(file, files):
				total_bytes += FileAccess.get_file_as_bytes(folder.path_join(file)).size()
				continue
			if file.get_extension() != "glb" or not file.get_basename().is_valid_identifier() or file.get_basename() != file.get_basename().to_lower():
				check(false, "%s must be a .glb named after a snake_case id" % label)
				continue
			var id := file.get_basename()
			var record: Dictionary = {}
			match category:
				"launchers": record = data.get_launcher(id)
				"buses": record = data.get_bus(id)
				"parts": record = data.get_part(id)
			if category in ["launchers", "buses", "parts"] and record.is_empty():
				print("WARN: %s has no %s entry in the game data, so the game will not load it" % [label, category])
			total_bytes += FileAccess.get_file_as_bytes(folder.path_join(file)).size()
			count += 1
			var model := MODEL_LIBRARY.instantiate(category, id)
			if model == null:
				check(false, "%s imports as a 3D scene" % label)
				continue
			var result := MODEL_CHECKS.check(category, model, record)
			for message: String in result.warnings:
				print("WARN: %s: %s" % [label, message])
			check(result.errors.is_empty(), "%s meets the spec (%d triangles, %s m) %s" % [label, result.triangles, result.size, result.errors])
			model.free()
	check(total_bytes <= MAX_TOTAL_BYTES, "%d models use %.1f of %d MB" % [count, total_bytes / 1048576.0, MAX_TOTAL_BYTES / 1048576])

## Godot's glTF importer extracts embedded textures next to the model as <id>_<image>.
func _extracted_from_model(file: String, files: PackedStringArray) -> bool:
	for other in files:
		if other.get_extension() == "glb" and file.begins_with(other.get_basename() + "_"):
			return true
	return false
