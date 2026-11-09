extends Control

@export_enum("MainMenu", "MissionSelect", "Debrief") var screen := "MainMenu"
var _body: VBoxContainer
var _details: VBoxContainer
var _selected: Dictionary = {}
var _error_label: Label
var _retry: Button
var _retry_action: Callable
var _balance_label: Label
var _mission_buttons: Dictionary = {}
var _start_button: Button

func _ready() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 48)
	outer.add_theme_constant_override("margin_right", 48)
	outer.add_theme_constant_override("margin_top", 32)
	outer.add_theme_constant_override("margin_bottom", 32)
	add_child(outer)
	var scroll := ScrollContainer.new()
	outer.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color("ff4d4d"))
	_body.add_child(_error_label)
	_retry = Button.new()
	_retry.text = "Retry save"
	_retry.visible = false
	_retry.pressed.connect(func(): _retry_action.call())
	_body.add_child(_retry)
	match screen:
		"MainMenu": _main_menu()
		"MissionSelect": _mission_select()
		"Debrief": _debrief()

func _label(text: String, parent: Node = null, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else _body).add_child(label)
	return label

func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	(parent if parent != null else _body).add_child(button)
	return button

func _show_save_error(action: Callable) -> void:
	_error_label.text = "Could not save campaign. Please retry."
	_retry_action = action
	_retry.visible = true

func _main_menu() -> void:
	GameManager.state = GameManager.State.MAIN_MENU
	_label("SPACEBOUNDS", null, Color("00e5ff")).add_theme_font_size_override("font_size", 48)
	_label("Build a spacecraft. Explore our world and beyond.")
	_button("New Campaign", _new_campaign)
	if FileAccess.file_exists(GameManager.save_path):
		_button("Continue", _continue_campaign)
	_button("Credits", _credits)

func _new_campaign() -> void:
	if FileAccess.file_exists(GameManager.save_path):
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Start a new campaign and replace your saved progress?"
		add_child(dialog)
		dialog.confirmed.connect(_start_new)
		dialog.popup_centered()
	else:
		_start_new()

func _start_new() -> void:
	var error: Error = GameManager.new_campaign()
	if error != OK:
		_show_save_error(_retry_new)
		return
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _retry_new() -> void:
	if GameManager.save_campaign() == OK:
		get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
	else:
		_show_save_error(_retry_new)

func _continue_campaign() -> void:
	if GameManager.load_campaign() != OK:
		_error_label.text = "The saved campaign could not be read. Your save was not changed."
		return
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _credits() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Credits"
	dialog.dialog_text = "Built with Godot Engine.\nRoboto © The Roboto Project Authors, SIL Open Font License 1.1 (assets/fonts/OFL.txt).\nSpace science references: NASA Small Spacecraft Technology, NASA NSSDCA and NASA mission documentation."
	add_child(dialog)
	dialog.popup_centered()

func _mission_select() -> void:
	GameManager.state = GameManager.State.MISSION_SELECT
	_label("MISSION SELECT", null, Color("00e5ff")).add_theme_font_size_override("font_size", 36)
	_balance_label = _label("")
	GameManager.campaign_changed.connect(_refresh_campaign_ui)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	_body.add_child(columns)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 360
	columns.add_child(list)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_details)
	for mission in GlobalData.missions:
		var number := int(mission.missionNumber)
		if number == 5 and not ResourceLoader.exists("res://scenes/LunarFlyby.tscn"): continue
		if number == 7 and not ResourceLoader.exists("res://scenes/LandingMinigame.tscn"): continue
		var b := _button("%d. %s" % [number, mission.title], _select_mission.bind(mission), list)
		b.disabled = not GameManager.is_mission_unlocked(number)
		if b.disabled: b.text += " [Locked]"
		_mission_buttons[number] = b
	_button("Main Menu", func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	if ResourceLoader.exists("res://scenes/TechTree.tscn"):
		_button("Research", func(): get_tree().change_scene_to_file("res://scenes/TechTree.tscn"))
	_select_mission(GlobalData.get_mission(1))
	_refresh_campaign_ui()

func _select_mission(mission: Dictionary) -> void:
	if mission.is_empty(): return
	_selected = mission
	for child in _details.get_children(): child.queue_free()
	_label(mission.title, _details, Color("00e5ff"))
	_label(mission.briefing, _details)
	if mission.has("historyNote"): _label("History note: " + mission.historyNote, _details, Color("ffb300"))
	_label("%s · %s km · %s days" % [mission.targetOrbit, mission.targetAltitudeKm, mission.durationDays], _details)
	var names: Array[String] = []
	for id in mission.requiredPartIds:
		names.append(GlobalData.get_part(id).get("name", id))
	_label("Required: " + ", ".join(names), _details)
	_label("Budget $%.2fM · Reward $%.2fM / %d SP" % [mission.budgetCapMillions, mission.rewardFundsMillions, mission.rewardSciencePoints], _details)
	var missing: Array[String] = []
	if not GameManager.is_part_unlocked(mission.requiredLauncher): missing.append(str(GlobalData.get_launcher(mission.requiredLauncher).get("name", mission.requiredLauncher)))
	if not GameManager.is_part_unlocked(mission.requiredBus): missing.append(str(GlobalData.get_bus(mission.requiredBus).get("name", mission.requiredBus)))
	if not missing.is_empty(): _label("Research required: " + ", ".join(missing), _details, Color("ffb300"))
	_start_button = _button("Start", _start_selected, _details)
	_start_button.disabled = not GameManager.is_mission_unlocked(int(mission.missionNumber)) or not missing.is_empty()

func _start_selected() -> void:
	if GameManager.is_part_unlocked(_selected.requiredLauncher) and GameManager.is_part_unlocked(_selected.requiredBus) and GameManager.start_mission(int(_selected.missionNumber)):
		get_tree().change_scene_to_file("res://scenes/Workshop.tscn")

func _debrief() -> void:
	GameManager.state = GameManager.State.DEBRIEF
	_label("FLIGHT DEBRIEF", null, Color("00e5ff")).add_theme_font_size_override("font_size", 36)
	if GameManager.last_result.is_empty():
		_label("No flight result is available.")
		_button("Continue", _return_to_missions)
		return
	var receipt: Dictionary = GameManager.finalize_mission(GameManager.last_result)
	if receipt.is_empty():
		_label("The flight result could not be processed.")
		_button("Continue", _return_to_missions)
		return
	_label("%s  %s   %.1f / 100" % [receipt.outcome, ("%d star%s" % [receipt.stars, "" if receipt.stars == 1 else "s"]) if receipt.stars > 0 else "", receipt.score])
	for item in [["Primary", "primary", 60], ["Bonus", "bonus", 20], ["Cost efficiency", "efficiency", 10], ["Mass margin", "mass_margin", 10]]:
		_label("%s: %.1f / %d" % [item[0], receipt[item[1]], item[2]])
		var bar := ProgressBar.new()
		bar.max_value = item[2]
		bar.value = receipt[item[1]]
		bar.show_percentage = false
		_body.add_child(bar)
	_label("Payout: $%.2fM and %d SP" % [receipt.funds_millions, receipt.science_points])
	if not receipt.unlocks.is_empty(): _label("Unlocked: " + ", ".join(receipt.unlocks), null, Color("ffb300"))
	if "SpaceX Falcon 9" in receipt.unlocks: _label("SpaceX Falcon 9 now available", null, Color("00e5ff"))
	_label("Objectives")
	for objective in GameManager.last_result.get("objectives", []):
		_label(("[DONE] " if objective.get("done", false) else "[PENDING] ") + str(objective.get("name", "")))
	_label("Flight log")
	for line in receipt.flight_log: _label(str(line))
	for event_id in receipt.get("events_fired", []):
		var event: Dictionary = EventManager.get_event(event_id)
		if event.is_empty(): continue
		var card := PanelContainer.new()
		_body.add_child(card)
		var margin := MarginContainer.new()
		for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(edge, 12)
		card.add_child(margin)
		var content := VBoxContainer.new()
		margin.add_child(content)
		_label("Historical precedent  /  " + str(event.title), content, Color("ffb300"))
		_label(event.precedent, content)
	var next := _button("Continue", _return_to_missions)
	if GameManager.save_campaign() != OK:
		next.disabled = true
		_show_save_error(func():
			if GameManager.save_campaign() == OK:
				_retry.visible = false
				_error_label.text = ""
				next.disabled = false
		)

func _return_to_missions() -> void:
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _refresh_campaign_ui() -> void:
	_balance_label.text = "Funds: $%.2fM    Science: %d SP" % [GameManager.funds_millions, GameManager.science_points]
	for number in _mission_buttons:
		var button: Button = _mission_buttons[number]
		button.disabled = not GameManager.is_mission_unlocked(number)
		button.text = "%d. %s%s" % [number, GlobalData.get_mission(number).title, " [Locked]" if button.disabled else ""]
	if is_instance_valid(_start_button):
		_start_button.disabled = not GameManager.is_mission_unlocked(int(_selected.missionNumber)) or not GameManager.is_part_unlocked(_selected.requiredLauncher) or not GameManager.is_part_unlocked(_selected.requiredBus)

func _exit_tree() -> void:
	if GameManager.campaign_changed.is_connected(_refresh_campaign_ui):
		GameManager.campaign_changed.disconnect(_refresh_campaign_ui)
