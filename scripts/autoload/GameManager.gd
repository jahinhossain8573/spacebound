extends Node

signal mission_skip_started(remaining_s: float)
signal burn_executed(dv_mps: float)
signal campaign_changed

enum State { MAIN_MENU, MISSION_SELECT, WORKSHOP, LAUNCH, FLIGHT_OPS, DEBRIEF, TECH_TREE }

var state: State = State.MAIN_MENU
var funds_millions: float = 0.0
var science_points: int = 0
var unlocked_part_ids: Array[String] = []
var owned_tech_nodes: Array[String] = []
var completed_missions: Array[int] = []
var current_mission: Dictionary = {}
var current_build: Dictionary = {}
var initial_orbit: OrbitState
var unlocked_tier: int = 0
var last_result: Dictionary = {}
var last_receipt: Dictionary = {}
var attempt_id: String = ""
var attempt_is_replay: bool = false
var attempt_is_archive := false
var save_path := "user://save.json"
var has_launched_once := false
var flight_elapsed_s := 0.0
var debug_force_launch_failure := false
var debug_disable_reliability := false
var debug_unlock_missions := false
var _debug_panel: Control

func _ready() -> void:
	if OS.is_debug_build():
		_create_debug_panel()

func new_campaign() -> Error:
	funds_millions = 0.0
	science_points = 0
	unlocked_tier = 0
	unlocked_part_ids.clear()
	owned_tech_nodes.clear()
	completed_missions.clear()
	current_mission = {}
	current_build = {}
	initial_orbit = null
	last_result = {}
	last_receipt = {}
	attempt_id = ""
	attempt_is_replay = false
	attempt_is_archive = false
	debug_disable_reliability = false
	debug_force_launch_failure = false
	has_launched_once = false
	flight_elapsed_s = 0.0
	debug_unlock_missions = false
	for catalog in [GlobalData.launchers, GlobalData.buses, GlobalData.components]:
		for item in catalog:
			if item.tier == 0:
				unlocked_part_ids.append(item.id)
	campaign_changed.emit()
	return save_campaign()

func save_campaign() -> Error:
	var data := {"version": 1, "funds_millions": funds_millions, "science_points": science_points, "unlocked_part_ids": unlocked_part_ids, "owned_tech_nodes": owned_tech_nodes, "completed_missions": completed_missions, "unlocked_tier": unlocked_tier, "last_receipt": last_receipt, "has_launched_once": has_launched_once}
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(save_path))

func load_campaign() -> Error:
	if not FileAccess.file_exists(save_path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version") != 1:
		return ERR_FILE_CORRUPT
	for key in ["funds_millions", "science_points", "unlocked_tier"]:
		if not (data.get(key) is int or data.get(key) is float) or data[key] < 0:
			return ERR_FILE_CORRUPT
	if data.unlocked_tier > 4 or data.science_points != floor(data.science_points) or data.unlocked_tier != floor(data.unlocked_tier):
		return ERR_FILE_CORRUPT
	for key in ["unlocked_part_ids", "owned_tech_nodes", "completed_missions"]:
		if not data.get(key) is Array:
			return ERR_FILE_CORRUPT
	for key in ["unlocked_part_ids", "owned_tech_nodes"]:
		for item in data[key]:
			if not item is String:
				return ERR_FILE_CORRUPT
	for item in data.completed_missions:
		if not (item is int or item is float) or item != floor(item) or GlobalData.get_mission(int(item)).is_empty():
			return ERR_FILE_CORRUPT
	if not data.get("has_launched_once", false) is bool:
		return ERR_FILE_CORRUPT
	if not data.get("last_receipt") is Dictionary:
		return ERR_FILE_CORRUPT
	funds_millions = data.funds_millions
	science_points = int(data.science_points)
	unlocked_tier = int(data.unlocked_tier)
	unlocked_part_ids.assign(data.unlocked_part_ids)
	owned_tech_nodes.assign(data.owned_tech_nodes)
	completed_missions.clear()
	for item in data.completed_missions:
		completed_missions.append(int(item))
	has_launched_once = data.get("has_launched_once", false)
	flight_elapsed_s = 0.0
	last_receipt = data.last_receipt
	current_mission = {}
	current_build = {}
	initial_orbit = null
	last_result = {}
	attempt_id = ""
	attempt_is_replay = false
	attempt_is_archive = false
	campaign_changed.emit()
	return OK

func is_mission_unlocked(number: int) -> bool:
	if OS.is_debug_build() and debug_unlock_missions:
		return not GlobalData.get_mission(number).is_empty()
	var previous := -1
	for mission in GlobalData.missions:
		if int(mission.missionNumber) == number:
			return previous == -1 or previous in completed_missions
		previous = int(mission.missionNumber)
	return false

func start_mission(number: int) -> bool:
	if not is_mission_unlocked(number):
		return false
	_begin_attempt(number)
	return true

func start_lunar_archive() -> bool:
	var mission := GlobalData.get_mission(5)
	if mission.is_empty():
		return false
	var parts: Array[Dictionary] = []
	for id in ["com_gd_sdst", "inst_lroc_wac", "av_bae_rad750", "prop_mr103g", "pwr_mma_ehawk_s", "pwr_mma_ehawk_s", "pwr_mma_ehawk_s", "pwr_gomspace_bp4"]:
		parts.append(GlobalData.get_part(id))
	var build := {
		"launcher": GlobalData.get_launcher(mission.requiredLauncher),
		"bus": GlobalData.get_bus(mission.requiredBus),
		"installed_components": parts,
		"propellant_mass_kg": 0.85
	}
	var helper = load("res://scripts/BuildStats.gd").new()
	for check: Dictionary in helper.run_readiness_review(build, mission):
		if check.status == "FAIL":
			return false
	build.stats = helper.calculate_stats(build, mission)
	_begin_attempt(5)
	attempt_is_archive = true
	current_build = build
	return true

func _begin_attempt(number: int) -> void:
	flight_elapsed_s = 0.0
	current_mission = GlobalData.get_mission(number)
	current_build = {}
	initial_orbit = null
	attempt_id = Crypto.new().generate_random_bytes(16).hex_encode()
	attempt_is_replay = number in completed_missions
	attempt_is_archive = false
	last_result = {}
	state = State.WORKSHOP

func compute_score(result: Dictionary) -> Dictionary:
	var mission := GlobalData.get_mission(int(result.get("mission_number", 0)))
	if mission.is_empty():
		return {}
	var objectives: Array = result.get("objectives", [])
	var completed := 0
	if result.get("launched", true):
		for objective in objectives:
			if objective is Dictionary and objective.get("done", false) == true:
				completed += 1
	var total := objectives.size()
	var fraction := float(completed) / total if total > 0 else 0.0
	var primary := 60.0 * fraction
	var bonus := 0
	var budget: float = mission.budgetCapMillions
	if result.has("total_cost_m") and result.total_cost_m <= budget:
		bonus += 1
	if result.has("mass_margin_pct") and result.mass_margin_pct >= 20.0:
		bonus += 1
	if result.has("battery_lowest_pct") and result.battery_lowest_pct >= 30.0:
		bonus += 1
	if (result.has("dv_reserve_pct") and result.dv_reserve_pct >= 10.0) or "E18" in result.get("events_fired", []):
		bonus += 1
	var science_bonus := maxi(0, bonus - 1) if result.get("optical_science_penalty", false) else bonus
	var efficiency := 0.0
	if result.has("total_cost_m") and budget > 0:
		efficiency = 10.0 * clampf((budget - float(result.total_cost_m)) / (budget * 0.3), 0.0, 1.0)
	var margin := 0.0
	if result.has("mass_margin_pct"):
		if result.mass_margin_pct >= 10.0:
			margin = 10.0
		elif result.mass_margin_pct >= 0.0:
			margin = 6.0
	var score := clampf(primary + bonus * 5.0 + efficiency + margin, 0.0, 100.0)
	var stars := 0
	var outcome := "Mission Loss"
	var sp_rate := 0.4
	if completed > 0 and completed < total:
		outcome = "Partial Success"
		sp_rate = 0.6
	elif total > 0 and completed == total:
		outcome = "Success"
		stars = 3 if score >= 85.0 else (2 if score >= 70.0 else 1)
		sp_rate = [0.0, 0.7, 0.85, 1.0][stars]
	var sp: int = floori(float(mission.rewardSciencePoints) * (0.25 if result.get("is_replay", false) else sp_rate + science_bonus * 0.05 + (0.20 if "E18" in result.get("events_fired", []) else 0.0)))
	return {"outcome": outcome, "stars": stars, "score": score, "primary": primary, "bonus": bonus * 5.0, "efficiency": efficiency, "mass_margin": margin, "science_points": sp, "funds_millions": float(mission.rewardFundsMillions) * fraction, "mission_number": int(mission.missionNumber)}

func finalize_mission(result: Dictionary) -> Dictionary:
	var id: String = result.get("attempt_id", attempt_id)
	if id.is_empty() or current_mission.is_empty() or int(result.get("mission_number", 0)) != int(current_mission.missionNumber) or id != attempt_id:
		return {}
	if last_receipt.get("attempt_id", "") == id:
		return last_receipt
	var evaluated := result.duplicate(true)
	evaluated["is_replay"] = attempt_is_replay
	var receipt := compute_score(evaluated)
	if receipt.is_empty():
		return {}
	receipt["attempt_id"] = id
	receipt["flight_log"] = result.get("flight_log", []).duplicate()
	receipt["events_fired"] = result.get("events_fired", []).duplicate()
	if result.has("images_captured"): receipt["images_captured"] = result.images_captured
	if result.has("clear_observation_s"): receipt["clear_observation_s"] = result.clear_observation_s
	receipt["unlocks"] = []
	if attempt_is_archive:
		receipt["science_points"] = 0
		receipt["funds_millions"] = 0.0
		return receipt
	funds_millions += receipt.funds_millions
	science_points += receipt.science_points
	var number := int(current_mission.missionNumber)
	if receipt.outcome == "Success" and not number in completed_missions:
		completed_missions.append(number)
		if current_mission.has("unlocksTier"):
			unlocked_tier = maxi(unlocked_tier, int(current_mission.unlocksTier))
			receipt.unlocks.append("Tier %d" % unlocked_tier)
		if number == 3:
			if not "L11" in owned_tech_nodes: owned_tech_nodes.append("L11")
			if not "launcher_falcon_9" in unlocked_part_ids: unlocked_part_ids.append("launcher_falcon_9")
			receipt.unlocks.append("SpaceX Falcon 9")
	last_result = result.duplicate(true)
	last_receipt = receipt
	state = State.DEBRIEF
	campaign_changed.emit()
	return receipt

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_debug_panel.visible = not _debug_panel.visible

func _create_debug_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 80)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101214")
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_debug_panel = panel
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.text = "DEBUG (F9)"
	box.add_child(label)
	var toggle := CheckButton.new()
	toggle.text = "Disable reliability roll"
	toggle.toggled.connect(func(value: bool): debug_disable_reliability = value)
	box.add_child(toggle)
	var force_failure := CheckButton.new()
	force_failure.text = "Force launch failure"
	box.add_child(force_failure)
	toggle.toggled.connect(func(value: bool):
		if value: force_failure.button_pressed = false
	)
	force_failure.toggled.connect(func(value: bool):
		debug_force_launch_failure = value
		if value: toggle.button_pressed = false
	)
	var event_id := LineEdit.new()
	event_id.placeholder_text = "Event ID (E3, E7, E8, E9, E11, E18)"
	box.add_child(event_id)
	var event_feedback := Label.new()
	box.add_child(event_feedback)
	var force_event := Button.new()
	force_event.text = "Force event"
	force_event.pressed.connect(func():
		event_feedback.text = "" if EventManager.force_event(event_id.text.strip_edges()) else "Enter an unused event ID during a flight."
	)
	box.add_child(force_event)
	var seed_input := SpinBox.new()
	seed_input.max_value = 2147483647
	seed_input.step = 1
	seed_input.prefix = "Event seed: "
	box.add_child(seed_input)
	var apply_seed := Button.new()
	apply_seed.text = "Set event seed"
	apply_seed.pressed.connect(func(): EventManager.rng.seed = int(seed_input.value))
	box.add_child(apply_seed)
	for entry in ["+100 SP", "Unlock all missions", "Unlock all parts", "Unlock all nodes"]:
		var button := Button.new()
		button.text = entry
		button.pressed.connect(_debug_action.bind(entry))
		box.add_child(button)

func _debug_action(action: String) -> void:
	match action:
		"+100 SP": science_points += 100
		"Unlock all missions": debug_unlock_missions = true
		"Unlock all nodes":
			for node in GlobalData.tech_nodes:
				if node.hackathonEnabled:
					if not node.id in owned_tech_nodes: owned_tech_nodes.append(node.id)
					for id in node.unlocksParts:
						if not id in unlocked_part_ids: unlocked_part_ids.append(id)
			unlocked_tier = 4
		"Unlock all parts":
			for catalog in [GlobalData.components, GlobalData.buses, GlobalData.launchers]:
				for part in catalog:
					if not part.id in unlocked_part_ids: unlocked_part_ids.append(part.id)
	campaign_changed.emit()

func is_part_unlocked(id: String) -> bool:
	for catalog in [GlobalData.components, GlobalData.buses, GlobalData.launchers]:
		for item in catalog:
			if item.id == id:
				if item.tier == 0 or id in unlocked_part_ids: return true
				for node in GlobalData.tech_nodes:
					if node.id in owned_tech_nodes and id in node.unlocksParts: return true
				return false
	return false

func research_status(id: String) -> String:
	var node: Dictionary = GlobalData.get_tech_node(id)
	if node.is_empty(): return "Unknown"
	if id in owned_tech_nodes: return "Owned"
	if not node.hackathonEnabled: return "Post-hackathon"
	if id == "L11": return "Granted after Mission 3"
	if node.tier > unlocked_tier: return "Locked by tier"
	if node.prereqMission != null and int(node.prereqMission) not in completed_missions: return "Locked by prerequisite"
	for prerequisite in node.prereqNodes:
		if prerequisite not in owned_tech_nodes: return "Locked by prerequisite"
	if science_points < node.cost: return "Not enough SP"
	return "Available"

func research_node(id: String) -> Error:
	if research_status(id) != "Available": return ERR_UNAUTHORIZED
	var node: Dictionary = GlobalData.get_tech_node(id)
	var original_parts := unlocked_part_ids.duplicate()
	science_points -= int(node.cost)
	owned_tech_nodes.append(id)
	for part_id in node.unlocksParts:
		if part_id not in unlocked_part_ids: unlocked_part_ids.append(part_id)
	var result := save_campaign()
	if result != OK:
		science_points += int(node.cost)
		owned_tech_nodes.erase(id)
		unlocked_part_ids.assign(original_parts)
		return result
	campaign_changed.emit()
	return OK
