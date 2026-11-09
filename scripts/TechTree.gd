extends Control

const BRANCHES := ["launch", "power", "comms", "adcs_prop", "instruments", "landing"]
const TITLES := ["LAUNCH", "POWER", "COMMS", "ADCS / PROP", "INSTRUMENTS", "LANDING"]
const WIDTH := 270.0
const ROW := 160.0
var _balance: Label
var _canvas: Control
var _buttons: Dictionary = {}
var _positions: Dictionary = {}
var _pending := ""
var _dialog: ConfirmationDialog
var _error: AcceptDialog

func _ready() -> void:
	GameManager.state = GameManager.State.TECH_TREE
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var back := Button.new()
	back.text = "< Mission Select"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn"))
	header.add_child(back)
	_balance = Label.new()
	_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_balance)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_canvas)
	var tier_counts := {}
	for tier in range(1,5):
		var max_count := 0
		for branch in BRANCHES:
			var count := 0
			for node in GlobalData.tech_nodes:
				if node.tier == tier and node.branch == branch: count += 1
			max_count = maxi(max_count, count)
		tier_counts[tier] = max_count
	var tier_y := {}
	var top := 42.0
	for tier in range(1,5):
		tier_y[tier] = top
		top += float(tier_counts[tier]) * ROW + 36.0
	_canvas.custom_minimum_size = Vector2(WIDTH * BRANCHES.size(), top)
	for index in BRANCHES.size():
		var title := Label.new()
		title.text = TITLES[index]
		title.position = Vector2(index * WIDTH + 8, 8)
		title.add_theme_color_override("font_color", Color("00e5ff"))
		_canvas.add_child(title)
	for tier in range(1,5):
		for branch_index in BRANCHES.size():
			var row := 0
			for node in GlobalData.tech_nodes:
				if node.tier != tier or node.branch != BRANCHES[branch_index]: continue
				_positions[node.id] = Vector2(branch_index * WIDTH + 8, tier_y[tier] + row * ROW)
				row += 1
	for node in GlobalData.tech_nodes:
		if not _positions.has(node.id): continue
		for prereq in node.prereqNodes:
			if not _positions.has(prereq): continue
			var line := Line2D.new()
			line.width = 2.0
			line.default_color = Color("477080")
			line.add_point(_positions[prereq] + Vector2(125, 136))
			line.add_point(_positions[node.id] + Vector2(125, 0))
			_canvas.add_child(line)
	for node in GlobalData.tech_nodes:
		if not _positions.has(node.id): continue
		var button := Button.new()
		button.position = _positions[node.id]
		button.size = Vector2(WIDTH - 20, 140)
		button.text = node.id + "  " + node.name
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_color_override("font_disabled_color", Color("a3aebb"))
		button.tooltip_text = node.description + "\n" + node.get("heritage", "")
		button.pressed.connect(_confirm.bind(node.id))
		_canvas.add_child(button)
		_buttons[node.id] = button
	_dialog = ConfirmationDialog.new()
	_dialog.confirmed.connect(_purchase)
	add_child(_dialog)
	_error = AcceptDialog.new()
	add_child(_error)
	GameManager.campaign_changed.connect(_refresh)
	_refresh()

func _part_name(id: String) -> String:
	for item in [GlobalData.get_part(id), GlobalData.get_bus(id), GlobalData.get_launcher(id)]:
		if not item.is_empty(): return str(item.name)
	return id

func _refresh() -> void:
	_balance.text = "   RESEARCH   /   %d SP available" % GameManager.science_points
	for node in GlobalData.tech_nodes:
		if not _buttons.has(node.id): continue
		var state: String = GameManager.research_status(node.id)
		var names: Array[String] = []
		for id in node.unlocksParts: names.append(_part_name(id))
		var unlocks: String = ", ".join(names) if not names.is_empty() else ("Launch reliability +2%" if node.id in ["L7","L8"] else ("Adapter mass 1%" if node.id == "L10" else node.get("heritage", "")))
		var button: Button = _buttons[node.id]
		button.text = "%s  %s\nTier %d · %d SP · %s\n%s" % [node.id, node.name, node.tier, node.cost, state, unlocks]
		button.disabled = state != "Available"
		button.tooltip_text = "%s\n%s\nRequires: %s%s" % [node.description, node.get("heritage", ""), ", ".join(node.prereqNodes) if not node.prereqNodes.is_empty() else "None", ("; Mission %s" % node.prereqMission) if node.prereqMission != null else ""]

func _confirm(id: String) -> void:
	if GameManager.research_status(id) != "Available": return
	_pending = id
	var node: Dictionary = GlobalData.get_tech_node(id)
	_dialog.dialog_text = "Research %s for %d SP?" % [node.name, node.cost]
	_dialog.popup_centered()

func _purchase() -> void:
	if _pending.is_empty(): return
	var error: Error = GameManager.research_node(_pending)
	if error != OK:
		_error.dialog_text = "Research could not be saved or is no longer available. Please try again."
		_error.popup_centered()
	else:
		var button: Button = _buttons[_pending]
		button.modulate = Color("00e5ff")
		create_tween().tween_property(button, "modulate", Color.WHITE, 0.6)
	_pending = ""

func _exit_tree() -> void:
	if GameManager.campaign_changed.is_connected(_refresh): GameManager.campaign_changed.disconnect(_refresh)
