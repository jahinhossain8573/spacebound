extends Node

signal queue_finished
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var random_enabled := true
var flight: Control
var blocking := false
var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _popup: Control
var _remaining_s := 0.0

func _ready() -> void:
	rng.randomize()
	load_events("res://data/events.json")
	GameManager.mission_skip_started.connect(_on_skip)
	GameManager.burn_executed.connect(_on_burn)

func load_events(path: String) -> void:
	events.clear()
	if not FileAccess.file_exists(path):
		push_error("Cannot read event catalog: " + path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		push_error("Invalid event catalog: " + path)
		return
	var ids := {}
	for item in parsed:
		if not item is Dictionary or not item.get("id") is String or item.id.is_empty() or ids.has(item.id) or not item.get("title") is String or item.get("severity") not in ["Minor", "Major", "Critical", "Positive"] or item.get("trigger") not in ["arrival", "skip", "burn"] or not (item.get("probability") is float or item.get("probability") is int) or item.probability < 0 or item.probability > 1 or not item.get("conditions") is Dictionary or not item.get("choices") is Array or item.choices.size() > 2 or not item.get("description") is String or not item.get("precedent") is String:
			push_error("Invalid event record: " + path)
			events.clear()
			return
		for choice in item.choices:
			if not choice is Dictionary or not choice.get("label") is String or not choice.get("outcome") is String:
				push_error("Invalid event choice: " + path)
				events.clear()
				return
		ids[item.id] = true
		events.append(item)

func get_event(id: String) -> Dictionary:
	for item in events:
		if item.id == id: return item
	return {}

func register_flight(value: Control) -> void:
	flight = value
	_queue.clear()
	_active = {}
	blocking = false
	_remaining_s = 0.0

func unregister_flight(value: Control) -> void:
	if flight != value: return
	flight = null
	_queue.clear()
	_active = {}
	blocking = false
	if is_instance_valid(_popup): _popup.queue_free()
	_popup = null

func probability_multiplier() -> float:
	if "L6" in GameManager.owned_tech_nodes: return 0.5
	if "L5" in GameManager.owned_tech_nodes: return 0.7
	return 1.0

func _has_part_flag(flag: String) -> bool:
	for part in GameManager.current_build.get("installed_components", []):
		if part.get(flag, false): return true
	return false

func eligible(item: Dictionary) -> bool:
	if not is_instance_valid(flight) or GameManager.attempt_id.is_empty() or GameManager.last_result.is_empty(): return false
	if item.id in GameManager.last_result.get("events_fired", []): return false
	var conditions: Dictionary = item.conditions
	if conditions.has("requiresPartFlag") and not _has_part_flag(conditions.requiresPartFlag): return false
	if conditions.has("targetOrbits") and flight.mission.get("targetOrbit", "") not in conditions.targetOrbits: return false
	if conditions.get("requiresSurvival", false) and (flight._skip_result.is_empty() or not flight._skip_result.survived): return false
	if conditions.has("minimumBatteryPct") and flight.battery_lowest_pct <= conditions.minimumBatteryPct: return false
	return true

func roll_trigger(trigger: String) -> void:
	if not random_enabled or not is_instance_valid(flight): return
	for item in events:
		if item.trigger != trigger or item.id == "E18" or not eligible(item): continue
		var probability: float = item.probability
		if item.id == "E7" and flight.mission.get("targetOrbit", "") not in ["LEO", "SSO"]: probability = 0.20
		if item.id == "E9" and int(flight.mission.get("missionNumber", 0)) == 3: probability = 1.0
		if probability < 1.0: probability *= probability_multiplier()
		if rng.randf() < probability: _enqueue(item)

func roll_extension() -> void:
	var item := get_event("E18")
	if random_enabled and not item.is_empty() and eligible(item) and rng.randf() < float(item.probability) * probability_multiplier(): _enqueue(item)

func force_event(id: String) -> bool:
	if not OS.is_debug_build() or not is_instance_valid(flight) or GameManager.last_result.is_empty(): return false
	var item := get_event(id.to_upper())
	if item.is_empty() or item.id in GameManager.last_result.get("events_fired", []): return false
	_enqueue(item)
	return true

func _on_skip(remaining: float) -> void:
	_remaining_s = remaining
	roll_trigger("skip")

func _on_burn(_dv: float) -> void:
	roll_trigger("burn")

func _enqueue(item: Dictionary) -> void:
	if item.id in GameManager.last_result.get("events_fired", []): return
	for queued in _queue:
		if queued.id == item.id: return
	_queue.append(item)
	if not blocking: _show_next()

func _show_next() -> void:
	if not is_instance_valid(flight):
		blocking = false
		return
	if _queue.is_empty():
		blocking = false
		_active = {}
		queue_finished.emit()
		return
	blocking = true
	_active = _queue.pop_front()
	if not GameManager.last_result.has("events_fired"): GameManager.last_result.events_fired = []
	GameManager.last_result.events_fired.append(_active.id)
	GameManager.last_result.flight_log.append("T+%.1fs %s: %s" % [flight.mission_elapsed_s, _active.id, _active.title])
	_popup = load("res://scenes/ui/EventPopup.tscn").instantiate()
	flight.add_child(_popup)
	_popup.setup(_active, _can_avoid())
	_popup.choice_selected.connect(_choose)
	_popup.closed.connect(_close_popup)

func _can_avoid() -> bool:
	return is_instance_valid(flight) and is_instance_valid(flight._burn_panel) and not flight._burn_panel.engine.is_empty() and flight._burn_panel.remaining_dv() >= 10.0

func _has_radiation_obc() -> bool:
	for part in GameManager.current_build.get("installed_components", []):
		if part.get("subsystem", "") == "avionics" and part.get("radiationHardened", false): return true
	return false

func _choose(choice: String) -> void:
	if _active.is_empty() or not is_instance_valid(flight): return
	var message := ""
	match _active.id:
		"E3":
			var loss := 0.0
			for part in GameManager.current_build.get("installed_components", []):
				if part.get("deployable", false): loss += float(part.get("powerGenWatts", 0.0)) * 0.5
			flight.generation_w = maxf(0.0, flight.generation_w - loss)
			message = "Deployable solar generation reduced by 50%."
		"E7":
			if _has_radiation_obc(): message = "Radiation-hardened computer prevented latch-up. No damage."
			elif rng.randf() < 0.4:
				message = "Computer permanently damaged. Spacecraft lost."
				flight._power_failure("SPACECRAFT LOST: COMPUTER BURNOUT")
			else: message = "Computer rebooted successfully. No permanent damage."
		"E8":
			if choice == "avoid" and _can_avoid():
				flight._burn_panel.spend_avoidance_fuel(10.0)
				message = "Avoidance maneuver used 10 m/s of delta-v."
			elif choice == "risk" and rng.randf() < 0.05:
				message = "Debris impact. Spacecraft lost."
				flight._power_failure("SPACECRAFT LOST: DEBRIS IMPACT")
			else: message = "Conjunction passed without damage."
		"E9":
			if _remaining_s < 7.0 * 86400.0:
				GameManager.last_result["optical_objective_blocked"] = true
				message = "Clouds persist beyond the mission. The imaging objective cannot be completed."
			else:
				GameManager.last_result["optical_science_penalty"] = true
				message = "Imaging is delayed seven days; bonus science is reduced."
		"E11":
			if not flight._burn_panel.apply_underperformance(): message = "No burn is available to correct."
			else: message = "The engine delivered 90% of the planned delta-v."
		"E18": message = "+20% of base Science Points awarded for the extension."
	if not message.is_empty():
		GameManager.last_result.flight_log.append("T+%.1fs %s" % [flight.mission_elapsed_s, message])
	_popup.show_outcome(message)

func _close_popup() -> void:
	if is_instance_valid(flight) and flight.power_failed: _queue.clear()
	if is_instance_valid(_popup): _popup.queue_free()
	_popup = null
	_show_next()
