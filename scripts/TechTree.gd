extends Control

const UI = preload("res://scripts/UIStyle.gd")
const Canvas = preload("res://scripts/ResearchCanvas.gd")
const BRANCHES := ["launch", "power", "comms", "adcs_prop", "instruments", "landing"]
const TITLES := ["LAUNCH SYSTEMS", "POWER", "COMMUNICATIONS", "ATTITUDE / PROPULSION", "INSTRUMENTS", "LANDING"]
var _balance: Label
var _canvas: Control
var _surface: Control
var _scroll: ScrollContainer
var _details: VBoxContainer
var _action: Button
var _zoom_label: Label
var _buttons: Dictionary = {}
var _positions: Dictionary = {}
var _depths: Dictionary = {}
var _branch_y: Array[float] = []
var _selected := "L1"
var _pending := ""
var _zoom := 1.0
var _world_size := Vector2.ZERO
var _query := ""
var _dialog: ConfirmationDialog
var _error: AcceptDialog

func _label(text: String, parent: Node, tint: Color = UI.WHITE, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _ready() -> void:
	GameManager.state = GameManager.State.TECH_TREE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	margin.add_child(outer)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	outer.add_child(header)
	_button("< MISSIONS", func(): get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn"), header)
	var heading := _label("RESEARCH / TECHNOLOGY", header, UI.WHITE, 32)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance = _label("", header, UI.BLUE, 28)
	_balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	outer.add_child(toolbar)
	var search := LineEdit.new()
	search.placeholder_text = "Search technologies or parts..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_search)
	toolbar.add_child(search)
	var branches := OptionButton.new()
	branches.add_item("ALL DISCIPLINES")
	for title in TITLES: branches.add_item(title)
	branches.item_selected.connect(func(index: int):
		_scroll.scroll_vertical = int(_branch_y[maxi(0, index - 1)] * _zoom)
	)
	toolbar.add_child(branches)
	_button("−", func(): _set_zoom(_zoom - 0.15), toolbar)
	_zoom_label = _label("100%", toolbar)
	_zoom_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button("+", func(): _set_zoom(_zoom + 0.15), toolbar)
	_button("RESET", func(): _set_zoom(1.0); _scroll.scroll_horizontal = 0; _scroll.scroll_vertical = 0, toolbar)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(split)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.x = 440
	split.add_child(_scroll)
	_surface = Control.new()
	_scroll.add_child(_surface)
	_canvas = Canvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_surface.add_child(_canvas)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	split.add_child(panel)
	var inspector := VBoxContainer.new()
	inspector.add_theme_constant_override("separation", 16)
	panel.add_child(inspector)
	_label("TECHNOLOGY BRIEF", inspector, UI.BLUE, 20)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.add_child(detail_scroll)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 18)
	detail_scroll.add_child(_details)
	_action = _button("RESEARCH", func(): _confirm(_selected), inspector)
	_action.custom_minimum_size.y = 56
	_label("BLUE  Available / owned     ORANGE  Selected
Select any node to inspect its requirements.", outer, UI.MUTED, 18)
	_build_tree()
	_dialog = ConfirmationDialog.new()
	_dialog.confirmed.connect(_purchase)
	add_child(_dialog)
	_error = AcceptDialog.new()
	add_child(_error)
	GameManager.campaign_changed.connect(_refresh)
	_refresh()

func _depth(id: String) -> int:
	if _depths.has(id): return _depths[id]
	var node: Dictionary = GlobalData.get_tech_node(id)
	var depth := int(node.tier) - 1
	for prereq in node.prereqNodes:
		depth = maxi(depth, _depth(prereq) + 1)
	_depths[id] = depth
	return depth

func _build_tree() -> void:
	var y := 48.0
	var max_depth := 0
	for index in BRANCHES.size():
		_branch_y.append(y - 24)
		var title := _label(TITLES[index], _canvas, UI.BLUE, 20)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.position = Vector2(24, y)
		var counts := {}
		var rows := 1
		for node in GlobalData.tech_nodes:
			if node.branch != BRANCHES[index]: continue
			var depth := _depth(node.id)
			var row: int = counts.get(depth, 0)
			counts[depth] = row + 1
			rows = maxi(rows, row + 1)
			max_depth = maxi(max_depth, depth)
			_positions[node.id] = Vector2(24 + depth * 320, y + 44 + row * 112)
		y += 72 + rows * 112
	_world_size = Vector2((max_depth + 1) * 320 + 40, y)
	_canvas.extent = _world_size
	_canvas.size = _world_size
	_surface.custom_minimum_size = _world_size
	for node in GlobalData.tech_nodes:
		for prereq in node.prereqNodes:
			if _positions.has(prereq):
				_canvas.links.append({"from": _positions[prereq] + Vector2(260, 44), "to": _positions[node.id] + Vector2(0, 44), "id": prereq})
	for node in GlobalData.tech_nodes:
		var button := Button.new()
		button.position = _positions[node.id]
		button.size = Vector2(260, 88)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
		button.tooltip_text = node.name + "\n" + node.description
		button.pressed.connect(_select.bind(node.id))
		_canvas.add_child(button)
		_buttons[node.id] = button

func _part_name(id: String) -> String:
	for item in [GlobalData.get_part(id), GlobalData.get_bus(id), GlobalData.get_launcher(id)]:
		if not item.is_empty(): return str(item.name)
	return id

func _select(id: String) -> void:
	_selected = id
	_refresh()

func _refresh() -> void:
	_balance.text = "%d SP  /  SCIENCE" % GameManager.science_points
	for node in GlobalData.tech_nodes:
		var state: String = GameManager.research_status(node.id)
		var button: Button = _buttons[node.id]
		button.text = "%s / T%d / %d SP\n%s" % [node.id, node.tier, node.cost, node.name]
		button.tooltip_text = node.name + "\n" + state + "\n" + node.description
		var border: Color = UI.ORANGE if node.id == _selected else (UI.BLUE if state in ["Available", "Owned"] else Color("454b52"))
		var fill: Color = Color("30200e") if node.id == _selected else (Color("10283b") if state == "Owned" else UI.PANEL)
		button.add_theme_stylebox_override("normal", UI.box(fill, border, 2 if node.id == _selected else 1))
		button.add_theme_color_override("font_color", UI.WHITE if state in ["Available", "Owned"] or node.id == _selected else UI.MUTED)
	_canvas.queue_redraw()
	_show_details()

func _show_details() -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var node: Dictionary = GlobalData.get_tech_node(_selected)
	var state: String = GameManager.research_status(_selected)
	_label("%s / TIER %d" % [node.id, node.tier], _details, UI.ORANGE, 20)
	_label(node.name, _details, UI.WHITE, 30)
	_label(state.to_upper() + "  /  %d SP" % node.cost, _details, UI.BLUE if state in ["Available", "Owned"] else UI.ORANGE)
	_label(node.description, _details)
	if not node.get("heritage", "").is_empty(): _label("HERITAGE\n" + str(node.heritage), _details, UI.MUTED)
	_label("UNLOCKED PARTS / EFFECTS", _details, UI.BLUE, 20)
	if node.unlocksParts.is_empty():
		_label("Launch reliability +2%" if node.id in ["L7", "L8"] else ("Adapter mass reduced to 1%" if node.id == "L10" else "No additional hardware."), _details)
	for id in node.unlocksParts: _label("+ " + _part_name(id), _details)
	_label("REQUIRES", _details, UI.BLUE, 20)
	for id in node.prereqNodes:
		var prereq: Dictionary = GlobalData.get_tech_node(id)
		_button("%s / %s" % [id, prereq.name], _navigate.bind(id), _details)
	if node.prereqNodes.is_empty(): _label("No prerequisite technology", _details, UI.MUTED)
	if node.prereqMission != null: _label("Complete mission %s" % node.prereqMission, _details, UI.ORANGE)
	_label("Campaign tier %d required" % node.tier, _details, UI.MUTED)
	_action.text = "RESEARCH / %d SP" % node.cost if state == "Available" else state.to_upper()
	_action.disabled = state != "Available"

func _navigate(id: String) -> void:
	_select(id)
	_scroll.scroll_horizontal = int(maxf(0, _positions[id].x * _zoom - 24))
	_scroll.scroll_vertical = int(maxf(0, _positions[id].y * _zoom - 24))

func _set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.55, 1.45)
	_canvas.scale = Vector2.ONE * _zoom
	_surface.custom_minimum_size = _world_size * _zoom
	_zoom_label.text = "%d%%" % roundi(_zoom * 100)

func _search(query: String) -> void:
	_query = query.to_lower().strip_edges()
	var first := ""
	for node in GlobalData.tech_nodes:
		var terms: String = node.id + " " + node.name + " " + node.description
		for id in node.unlocksParts: terms += " " + _part_name(id)
		var matches := _query.is_empty() or terms.to_lower().contains(_query)
		_buttons[node.id].modulate.a = 1.0 if matches else 0.25
		if matches and first.is_empty(): first = node.id
	if not first.is_empty() and not _query.is_empty(): _navigate(first)

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
	_pending = ""
	_refresh()

func _exit_tree() -> void:
	if GameManager.campaign_changed.is_connected(_refresh): GameManager.campaign_changed.disconnect(_refresh)
