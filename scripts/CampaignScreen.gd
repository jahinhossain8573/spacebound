extends Control

const UI = preload("res://scripts/UIStyle.gd")

@export_enum("MainMenu", "MissionSelect", "Debrief") var screen := "MainMenu"
var _body: VBoxContainer
var _details: VBoxContainer
var _selected: Dictionary = {}
var _error_label: Label
var _retry: Button
var _retry_action: Callable
var _balance_label: Label
var _funds_label: Label
var _rep_meter: Control
var _director_quote: Label
var _active_count_label: Label
var _mission_buttons: Dictionary = {}
var _mission_rows: Dictionary = {}
var _start_button: Button
var _future_rows: Array[Label] = []
var _filter_mode := "available"
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	match screen:
		"MissionSelect":
			_mission_select()
			return
		"MainMenu", "Debrief":
			_legacy_shell()
			if screen == "MainMenu": _main_menu()
			else: _debrief()

func _legacy_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0d1118")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	_error_label.add_theme_color_override("font_color", Color("ff8811"))
	_body.add_child(_error_label)
	_retry = Button.new()
	_retry.text = "Retry save"
	_retry.visible = false
	_retry.pressed.connect(func(): _retry_action.call())
	_body.add_child(_retry)

func _label(text: String, parent: Node = null, color := Color.WHITE, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
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
	_label("SPACEBOUNDS", null, Color("279af1"), 48)
	_label("Build a spacecraft. Explore our world and beyond.", null, UI.WHITE, 22)
	UI.style_button(_button("New Campaign", _new_campaign), "green", 18, 10)
	if FileAccess.file_exists(GameManager.save_path):
		UI.style_button(_button("Continue", _continue_campaign), "blue", 18, 10)
	UI.style_button(_button("Credits", _credits), "slate", 18, 10)

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

# ---------------------------------------------------------------------------
# KSP MISSION CONTROL UI
# ---------------------------------------------------------------------------
func _mission_select() -> void:
	GameManager.state = GameManager.State.MISSION_SELECT

	var bg := ColorRect.new()
	bg.color = Color("0f131c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# Top KSP Agency Currency & Clock Bar
	var top := UI.build_agency_bar()
	root_vbox.add_child(top.bar)
	_funds_label = top.funds_label
	_balance_label = top.science_label
	_rep_meter = top.rep_meter

	if ResourceLoader.exists("res://scenes/TechTree.tscn"):
		var rnd_btn := Button.new()
		rnd_btn.text = "R&D Tech Tree"
		rnd_btn.add_theme_font_size_override("font_size", 15)
		UI.style_button(rnd_btn, "blue", 12, 4, 3)
		rnd_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/TechTree.tscn"))
		top.right_box.add_child(rnd_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Main Menu"
	exit_btn.tooltip_text = "Return to Main Menu"
	exit_btn.add_theme_font_size_override("font_size", 14)
	UI.style_button(exit_btn, "amber", 10, 4, 3)
	exit_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	top.right_box.add_child(exit_btn)

	# Center framed KSP Mission Control Console
	var center_margin := MarginContainer.new()
	center_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_margin.add_theme_constant_override("margin_left", 90)
	center_margin.add_theme_constant_override("margin_right", 90)
	center_margin.add_theme_constant_override("margin_top", 8)
	center_margin.add_theme_constant_override("margin_bottom", 12)
	root_vbox.add_child(center_margin)

	var console_frame := PanelContainer.new()
	console_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_frame.add_theme_stylebox_override("panel", UI.metallic_panel(Color("222730"), Color("586273"), 5, 10))
	center_margin.add_child(console_frame)

	var console_vbox := VBoxContainer.new()
	console_vbox.add_theme_constant_override("separation", 10)
	console_frame.add_child(console_vbox)

	# Flight Director Briefing Banner (matches Gene Kerman Mission Control header)
	var director_banner := PanelContainer.new()
	director_banner.add_theme_stylebox_override("panel", UI.inset_well(Color("141922"), Color("414b59"), 4, 8))
	console_vbox.add_child(director_banner)

	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 14)
	director_banner.add_child(banner_row)

	banner_row.add_child(UI.crew_portrait("director", "Gene / Flight Dir.", Vector2(114, 122)))

	var banner_text_col := VBoxContainer.new()
	banner_text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_text_col.add_theme_constant_override("separation", 6)
	banner_row.add_child(banner_text_col)

	var speaker := Label.new()
	speaker.text = "Flight Director — Mission Control"
	speaker.add_theme_font_size_override("font_size", 16)
	speaker.add_theme_color_override("font_color", UI.KSP_AMBER)
	banner_text_col.add_child(speaker)

	_director_quote = Label.new()
	_director_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_director_quote.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_director_quote.add_theme_font_size_override("font_size", 16)
	_director_quote.add_theme_color_override("font_color", Color("dce4ee"))
	banner_text_col.add_child(_director_quote)

	_active_count_label = Label.new()
	_active_count_label.add_theme_font_size_override("font_size", 14)
	_active_count_label.add_theme_color_override("font_color", UI.KSP_AMBER)
	banner_text_col.add_child(_active_count_label)

	# Decorative control-room telemetry graphic on right side of banner
	var room_deco := ControlRoomBackdrop.new()
	room_deco.custom_minimum_size = Vector2(210, 114)
	banner_row.add_child(room_deco)

	# Two-column Contract Board
	var board := HBoxContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 12)
	console_vbox.add_child(board)

	# Left Column: Folder Tabs + Contract List
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size.x = 360
	left_col.add_theme_constant_override("separation", 0)
	board.add_child(left_col)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	left_col.add_child(tabs_row)
	for pair in [["available", "Available"], ["active", "Unlocked"], ["archives", "Archives"]]:
		var tb := Button.new()
		tb.text = "● " + pair[1] if pair[0] == "available" else pair[1]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 14)
		tb.pressed.connect(_set_contract_filter.bind(pair[0]))
		tabs_row.add_child(tb)
		_tab_buttons[pair[0]] = tb

	var list_panel := PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", UI.inset_well(Color("323843"), Color("555f70"), 3, 6))
	left_col.add_child(list_panel)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(list_scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(list)

	for mission in GlobalData.missions:
		var number := int(mission.missionNumber)
		if number == 5 and not ResourceLoader.exists("res://scenes/LunarFlyby.tscn"): continue
		if number == 7:
			_add_future_row(list, "6. Lunar Polar Prospector")
		var row_wrap := HBoxContainer.new()
		row_wrap.add_theme_constant_override("separation", 0)
		list.add_child(row_wrap)

		var status_strip := ColorRect.new()
		status_strip.custom_minimum_size = Vector2(6, 52)
		status_strip.color = UI.KSP_GREEN
		row_wrap.add_child(status_strip)

		var emblem_box := PanelContainer.new()
		emblem_box.add_theme_stylebox_override("panel", UI.inset_well(Color("1c222b"), Color("485261"), 2, 4))
		emblem_box.add_child(UI.mission_emblem(number, Vector2(38, 38), GameManager.is_mission_unlocked(number)))
		row_wrap.add_child(emblem_box)

		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 52
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_select_mission.bind(mission))
		row_wrap.add_child(b)
		_mission_buttons[number] = b
		_mission_rows[number] = {"wrap": row_wrap, "strip": status_strip, "emblem_parent": emblem_box}

	_add_future_row(list, "8. South Pole Endurance & Rover")

	# Right Column: KSP Contract Dossier
	var dossier_panel := PanelContainer.new()
	dossier_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_panel.add_theme_stylebox_override("panel", UI.inset_well(Color("3a404c"), Color("5c6778"), 4, 12))
	board.add_child(dossier_panel)

	var dossier_scroll := ScrollContainer.new()
	dossier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_panel.add_child(dossier_scroll)

	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 10)
	dossier_scroll.add_child(_details)

	GameManager.campaign_changed.connect(_refresh_campaign_ui)
	var from_archive := GameManager.attempt_is_archive
	_set_contract_filter("archives" if from_archive else "available")
	_select_mission(GlobalData.get_mission(5 if from_archive else 1))
	_refresh_campaign_ui()

func _add_future_row(list: VBoxContainer, title: String) -> void:
	var row := Label.new()
	row.text = "%s\nComing after the hackathon" % title
	row.custom_minimum_size.y = 52.0
	row.add_theme_color_override("font_color", UI.MUTED)
	list.add_child(row)
	_future_rows.append(row)

func _lunar_archive_selected(number: int) -> bool:
	return _filter_mode == "archives" and number == 5

func _landing_pending(number: int) -> bool:
	return number == 7 and not ResourceLoader.exists("res://scenes/LandingMinigame.tscn")

func _set_contract_filter(mode: String) -> void:
	_filter_mode = mode
	for key in _tab_buttons:
		UI.style_button(_tab_buttons[key], "tab_active" if key == mode else "tab_inactive", 8, 5, 3)
	var selected_number := int(_selected.get("missionNumber", 0))
	if mode == "archives" and selected_number not in GameManager.completed_missions and _mission_rows.has(5):
		_select_mission(GlobalData.get_mission(5))
	elif selected_number == 5:
		_select_mission(_selected)
	_refresh_campaign_ui()

func _apply_row_visibility() -> void:
	for number: int in _mission_rows:
		var unlocked: bool = GameManager.is_mission_unlocked(number)
		var completed: bool = number in GameManager.completed_missions
		var show_row := true
		match _filter_mode:
			"active": show_row = unlocked and not completed
			"archives": show_row = completed or number == 5
			_: show_row = true
		_mission_rows[number].wrap.visible = show_row
	for row in _future_rows:
		row.visible = _filter_mode == "available"

func _select_mission(mission: Dictionary) -> void:
	if mission.is_empty(): return
	_selected = mission
	var number := int(mission.missionNumber)
	var unlocked := GameManager.is_mission_unlocked(number)
	var completed := number in GameManager.completed_missions

	var quotes := {
		1: "We may be overqualified for this mission, or maybe we overestimate our qualifications. Either way, Betbunia station is waiting for our first CubeSat beacon!",
		2: "Coastal agencies along the Bay of Bengal need crisp orbital imagery. Pack active reaction wheels and a fast S-band transmitter.",
		3: "Monsoon clouds cover the delta half the week, so we will need patience, power margin, and an X-band link to get every clear flood map down.",
		4: "Geostationary orbit is the big leagues. Launch to GTO on Falcon 9, coast to apogee, and fire the apogee engine to circularize at 35,786 km!"
	}
	if _director_quote:
		_director_quote.text = quotes.get(number, "Review the flight profile carefully and verify every subsystem in the VAB before rolling out to the pad.")

	for child in _details.get_children():
		child.queue_free()

	# Top Contract Header Row (Agency Emblem + Contract/Agent titles + Accept Button)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	_details.add_child(header_row)

	var seal_card := PanelContainer.new()
	seal_card.custom_minimum_size = Vector2(96, 84)
	seal_card.add_theme_stylebox_override("panel", UI.metallic_panel(Color("d8dee6"), Color("7f8a99"), 3, 6))
	var seal_center := CenterContainer.new()
	seal_center.add_child(UI.mission_emblem(number, Vector2(68, 68), true))
	seal_card.add_child(seal_center)
	header_row.add_child(seal_card)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 3)
	header_row.add_child(title_col)

	_label("Contract:", title_col, UI.KSP_AMBER, 14)
	_label("Mission %d — %s" % [number, str(mission.title)], title_col, UI.WHITE, 20)
	_label("Agent:", title_col, UI.KSP_AMBER, 14)
	_label("National Space & Satellite Record-Keeping Society", title_col, Color("e0e6ed"), 15)

	var action_col := VBoxContainer.new()
	action_col.alignment = BoxContainer.ALIGNMENT_CENTER
	action_col.add_theme_constant_override("separation", 4)
	header_row.add_child(action_col)

	var missing: Array[String] = []
	if not GameManager.is_part_unlocked(mission.requiredLauncher):
		missing.append(str(GlobalData.get_launcher(mission.requiredLauncher).get("name", mission.requiredLauncher)))
	if not GameManager.is_part_unlocked(mission.requiredBus):
		missing.append(str(GlobalData.get_bus(mission.requiredBus).get("name", mission.requiredBus)))

	var archive := _lunar_archive_selected(number)
	var landing_pending := _landing_pending(number)
	_start_button = Button.new()
	_start_button.text = "Start test flight" if archive else ("Coming soon" if landing_pending else ("↻ Replay Mission" if completed else "✓ Enter VAB"))
	_start_button.custom_minimum_size = Vector2(154, 46)
	_start_button.add_theme_font_size_override("font_size", 16)
	UI.style_button(_start_button, "green", 14, 8, 4)
	_start_button.disabled = not archive and (landing_pending or not unlocked or not missing.is_empty())
	_start_button.pressed.connect(_start_selected)
	action_col.add_child(_start_button)

	var exp_lbl := Label.new()
	exp_lbl.text = "Vega-C launch pad · No campaign payout" if archive else ("Status: Completed" if completed else ("Status: Ready" if unlocked and missing.is_empty() and not landing_pending else ("Status: Unlocked" if unlocked and landing_pending else "Status: Locked")))
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_lbl.add_theme_font_size_override("font_size", 12)
	exp_lbl.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT if unlocked and missing.is_empty() else UI.KSP_AMBER)
	action_col.add_child(exp_lbl)

	# Sunken Contract Dossier Text Box
	var body_well := PanelContainer.new()
	body_well.add_theme_stylebox_override("panel", UI.inset_well(Color("2b303a"), Color("4d5666"), 3, 12))
	_details.add_child(body_well)
	var body_col := VBoxContainer.new()
	body_col.add_theme_constant_override("separation", 8)
	body_well.add_child(body_col)

	_label("Briefing:", body_col, UI.KSP_AMBER, 16)
	_label(str(mission.briefing), body_col, Color("cfd7e0"), 15)
	_label("Target Profile: %s  ·  %s km altitude  ·  %s days duration  ·  Budget Cap: $%.2fM" % [mission.targetOrbit, mission.targetAltitudeKm, mission.durationDays, mission.budgetCapMillions], body_col, UI.WHITE, 15)

	if mission.has("historyNote"):
		_label("Historical Note: " + str(mission.historyNote), body_col, Color("f0c674"), 14)

	var launcher_name := str(GlobalData.get_launcher(mission.requiredLauncher).get("name", mission.requiredLauncher))
	var bus_name := str(GlobalData.get_bus(mission.requiredBus).get("name", mission.requiredBus))
	var names: Array[String] = []
	for id in mission.requiredPartIds:
		names.append(str(GlobalData.get_part(id).get("name", id)))

	_label("Assigned Hardware:", body_col, UI.KSP_AMBER, 16)
	_label("Launcher: %s   |   Platform: %s\nRequired Payload Parts: %s" % [launcher_name, bus_name, ", ".join(names) if not names.is_empty() else "Standardionics"], body_col, Color("d8e1eb"), 15)

	if not archive and not missing.is_empty():
		var alert_row := HBoxContainer.new()
		alert_row.add_theme_constant_override("separation", 10)
		body_col.add_child(alert_row)
		var alert_lbl := _label("Research required before flight: " + ", ".join(missing), alert_row, UI.ORANGE, 15)
		alert_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ResourceLoader.exists("res://scenes/TechTree.tscn"):
			var go_rnd := Button.new()
			go_rnd.text = "Open R&D"
			go_rnd.add_theme_font_size_override("font_size", 14)
			UI.style_button(go_rnd, "blue", 10, 4, 3)
			go_rnd.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/TechTree.tscn"))
			alert_row.add_child(go_rnd)

	_label("Objectives:", body_col, UI.KSP_AMBER, 16)
	if mission.has("objectives"):
		for obj in mission.objectives:
			_label("  • " + str(obj.name), body_col, UI.WHITE, 15)
	else:
		_label("  • Reach %s (%s km) and operate for %s days" % [mission.targetOrbit, mission.targetAltitudeKm, mission.durationDays], body_col, UI.WHITE, 15)
	if float(mission.get("requiredDeltaVMps", 0.0)) > 0.0:
		_label("  • Spacecraft Maneuver Reserve: %.0f m/s Δv (+10%% margin in readiness)" % float(mission.requiredDeltaVMps), body_col, UI.KSP_CYAN, 14)

	if not archive:
		_label("Rewards:", body_col, UI.KSP_AMBER, 16)
		_label("Completion:  +$%.2fM Funds   |   +%d SP Science%s" % [
			mission.rewardFundsMillions,
			mission.rewardSciencePoints,
			("   |   Unlocks Tech Tier %d" % int(mission.unlocksTier)) if mission.has("unlocksTier") else ""
		], body_col, UI.KSP_GREEN_TEXT, 16)

	_refresh_button_styles()

func _refresh_button_styles() -> void:
	var sel_num := int(_selected.get("missionNumber", -1))
	for number: int in _mission_buttons:
		var btn: Button = _mission_buttons[number]
		var unlocked: bool = GameManager.is_mission_unlocked(number)
		var completed: bool = number in GameManager.completed_missions
		if number == sel_num:
			UI.style_button(btn, "tile_selected", 10, 6, 3)
		else:
			UI.style_button(btn, "tile", 10, 6, 3)
		if _mission_rows.has(number):
			_mission_rows[number].strip.color = UI.GOLD if completed else (UI.KSP_GREEN if unlocked else Color("4a515c"))

func _start_selected() -> void:
	var number := int(_selected.missionNumber)
	if _lunar_archive_selected(number):
		if GameManager.start_lunar_archive():
			get_tree().change_scene_to_file("res://scenes/Launch.tscn")
		return
	if _landing_pending(number):
		return
	if GameManager.is_part_unlocked(_selected.requiredLauncher) and GameManager.is_part_unlocked(_selected.requiredBus) and GameManager.start_mission(int(_selected.missionNumber)):
		get_tree().change_scene_to_file("res://scenes/Workshop.tscn")

func _debrief() -> void:
	GameManager.state = GameManager.State.DEBRIEF
	_label("FLIGHT DEBRIEF", null, Color("279af1"), 36)
	if GameManager.last_result.is_empty():
		_label("No flight result is available.")
		_button("Continue", _return_to_missions)
		return
	var receipt: Dictionary = GameManager.finalize_mission(GameManager.last_result)
	if receipt.is_empty():
		_label("The flight result could not be processed.")
		_button("Continue", _return_to_missions)
		return
	_label("%s  %s   %.1f / 100" % [receipt.outcome, ("%d star%s" % [receipt.stars, "" if receipt.stars == 1 else "s"]) if receipt.stars > 0 else "", receipt.score], null, UI.KSP_GREEN_TEXT if receipt.outcome == "Success" else UI.ORANGE, 24)
	for item in [["Primary", "primary", 60], ["Bonus", "bonus", 20], ["Cost efficiency", "efficiency", 10], ["Mass margin", "mass_margin", 10]]:
		_label("%s: %.1f / %d" % [item[0], receipt[item[1]], item[2]])
		var bar := ProgressBar.new()
		bar.max_value = item[2]
		bar.value = receipt[item[1]]
		bar.show_percentage = false
		_body.add_child(bar)
	var payout := "Archives test flight · No campaign payout" if GameManager.attempt_is_archive else "Payout: $%.2fM and %d SP" % [receipt.funds_millions, receipt.science_points]
	_label(payout, null, UI.KSP_CYAN, 20)
	if not receipt.unlocks.is_empty(): _label("Unlocked: " + ", ".join(receipt.unlocks), null, Color("ff8811"))
	if "SpaceX Falcon 9" in receipt.unlocks: _label("SpaceX Falcon 9 now available", null, Color("279af1"))
	_label("Objectives")
	for objective in GameManager.last_result.get("objectives", []):
		_label(("[DONE] " if objective.get("done", false) else "[PENDING] ") + str(objective.get("name", "")))
	if receipt.has("images_captured"): _label("Images captured: %d" % receipt.images_captured)
	if receipt.has("clear_observation_s"): _label("Clear observation: %.1f days" % (receipt.clear_observation_s / 86400.0))
	if int(GameManager.last_result.get("mission_number", 0)) == 3:
		_label("Intense Flooding in Bangladesh — July 25, 2020", null, Color("279af1"))
		var flood_image := TextureRect.new()
		flood_image.texture = load("res://assets/images/nasa/bangladesh_flood.jpg")
		flood_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flood_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flood_image.custom_minimum_size.y = 360
		_body.add_child(flood_image)
		_label("NASA Earth Observatory image by Lauren Dauphin, using MODIS data from NASA EOSDIS/LANCE and GIBS/Worldview.")
		_label("Satellites like yours help agencies plan evacuations and relief.")
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
		_label("Historical precedent  /  " + str(event.title), content, Color("ff8811"))
		_label(event.precedent, content)
	var next := UI.style_button(_button("Continue", _return_to_missions), "green", 18, 10)
	if not GameManager.attempt_is_archive and GameManager.save_campaign() != OK:
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
	if _funds_label:
		_funds_label.text = UI.format_funds_ksp(GameManager.funds_millions)
	if _balance_label:
		_balance_label.text = "%d SP" % GameManager.science_points
	if _rep_meter:
		_rep_meter.set("progress", float(GameManager.completed_missions.size() + 1) / 5.0)
	var unlocked_count := 0
	for number: int in _mission_buttons:
		var button: Button = _mission_buttons[number]
		var unlocked: bool = GameManager.is_mission_unlocked(number)
		if unlocked: unlocked_count += 1
		var m := GlobalData.get_mission(number)
		var archive := _lunar_archive_selected(number)
		button.disabled = not unlocked and not archive
		if archive:
			button.text = "5. %s\nArchives test flight" % m.title
			continue
		var suffix := " [Completed]" if number in GameManager.completed_missions else (" [Locked]" if button.disabled else "")
		button.text = "%d. %s%s\n%s · $%.0fM reward" % [number, m.title, suffix, m.targetOrbit, m.rewardFundsMillions]
	if _active_count_label:
		_active_count_label.text = "Available Contracts: %d   [Completed: %d  |  Tech Tier: %d]" % [unlocked_count, GameManager.completed_missions.size(), GameManager.unlocked_tier]
	if is_instance_valid(_start_button) and not _selected.is_empty():
		var number := int(_selected.missionNumber)
		_start_button.disabled = not _lunar_archive_selected(number) and (_landing_pending(number) or not GameManager.is_mission_unlocked(number) or not GameManager.is_part_unlocked(_selected.requiredLauncher) or not GameManager.is_part_unlocked(_selected.requiredBus))
	_apply_row_visibility()
	_refresh_button_styles()

func _exit_tree() -> void:
	if GameManager.campaign_changed.is_connected(_refresh_campaign_ui):
		GameManager.campaign_changed.disconnect(_refresh_campaign_ui)


class ControlRoomBackdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0f141d"))
		# Stylized Mission Control big wall screens & desks
		draw_rect(Rect2(10, 10, size.x * 0.52, size.y * 0.48), Color("142b42"))
		draw_rect(Rect2(10, 10, size.x * 0.52, size.y * 0.48), Color("365d82"), false, 1.5)
		# Sine orbit wave on big screen
		var wave := PackedVector2Array()
		for i in 24:
			var x := 14.0 + (size.x * 0.52 - 8.0) * float(i) / 23.0
			var y := 10.0 + size.y * 0.24 + sin(float(i) * 0.35) * (size.y * 0.14)
			wave.append(Vector2(x, y))
		draw_polyline(wave, Color("56c8ff"), 1.6, true)
		# Side telemetry screen
		draw_rect(Rect2(size.x * 0.60, 12, size.x * 0.34, size.y * 0.44), Color("193326"))
		draw_rect(Rect2(size.x * 0.60, 12, size.x * 0.34, size.y * 0.44), Color("467a5c"), false, 1.2)
		# Console desks + chairs silhouettes in foreground
		draw_rect(Rect2(6, size.y * 0.72, size.x - 12, size.y * 0.22), Color("222933"))
		for cx: float in [0.22, 0.52, 0.80]:
			draw_rect(Rect2(size.x * cx - 12, size.y * 0.62, 24, size.y * 0.32), Color("2f3947"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("394352"), false, 1.0)
