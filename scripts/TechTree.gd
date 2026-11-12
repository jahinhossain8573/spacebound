extends Control

const UI = preload("res://scripts/UIStyle.gd")
const Canvas = preload("res://scripts/ResearchCanvas.gd")
const BRANCHES := ["launch", "power", "comms", "adcs_prop", "instruments", "landing"]
const TITLES := ["LAUNCH SYSTEMS", "POWER & STORAGE", "COMMUNICATIONS", "ADCS & PROPULSION", "INSTRUMENTS", "LUNAR LANDING"]
var _balance: Label
var _funds_label: Label
var _rep_meter: Control
var _canvas: Control
var _surface: Control
var _scroll: ScrollContainer
var _details: VBoxContainer
var _action: Button
var _requires_box: VBoxContainer
var _zoom_label: Label
var _buttons: Dictionary = {}
var _node_badges: Dictionary = {}
var _positions: Dictionary = {}
var _depths: Dictionary = {}
var _branch_y: Array[float] = []
var _selected := "L1"
var _pending := ""
var _zoom := 1.0
var _world_size := Vector2.ZERO
var _query := ""
var _panning := false
var _dialog: ConfirmationDialog
var _error: AcceptDialog
var _part_popup: PanelContainer
var _part_popup_body: VBoxContainer

func _label(text: String, parent: Node, tint: Color = UI.WHITE, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", roundi(font_size * 1.2))
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

	var root_col := VBoxContainer.new()
	root_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_col.add_theme_constant_override("separation", 0)
	add_child(root_col)

	# 1. Top KSP R&D Bar: [Technology] [Archives] + Clock | Funds / Stars / Science | Exit
	var top := UI.build_agency_bar(["⚛ Technology", "Archives"])
	root_col.add_child(top.bar)
	_funds_label = top.funds_label
	_balance = top.science_label
	_rep_meter = top.rep_meter

	var branches := OptionButton.new()
	branches.add_item("All Disciplines")
	for title in TITLES: branches.add_item(title)
	branches.add_theme_font_size_override("font_size", 16)
	branches.item_selected.connect(func(index: int):
		if index == 0:
			_scroll.scroll_vertical = 0
		else:
			_scroll.scroll_vertical = int(_branch_y[maxi(0, index - 1)] * _zoom)
	)
	top.right_box.add_child(branches)

	var back_btn := _button("< Missions", func(): get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn"), top.right_box)
	back_btn.add_theme_font_size_override("font_size", 17)
	UI.style_button(back_btn, "amber", 10, 4, 3)

	# 2. Main Split: Blueprint Canvas on Left + Metallic R&D Inspector on Right
	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 0)
	root_col.add_child(main_row)

	var canvas_holder := Control.new()
	canvas_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(canvas_holder)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.gui_input.connect(_on_scroll_gui_input)
	canvas_holder.add_child(_scroll)

	_surface = Control.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_surface)

	_canvas = Canvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_surface.add_child(_canvas)

	# Floating Zoom Widget in bottom-right corner of the blueprint canvas (matches Photo 4 "100% 🔍")
	var zoom_pod := PanelContainer.new()
	zoom_pod.anchor_left = 1.0
	zoom_pod.anchor_right = 1.0
	zoom_pod.anchor_top = 1.0
	zoom_pod.anchor_bottom = 1.0
	zoom_pod.offset_left = -168
	zoom_pod.offset_right = -10
	zoom_pod.offset_top = -46
	zoom_pod.offset_bottom = -10
	zoom_pod.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.12, 0.16, 0.22, 0.90), Color("4f5e73"), 4, 4))
	canvas_holder.add_child(zoom_pod)

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	zoom_pod.add_child(zoom_row)
	var z_minus := _button("−", func(): _set_zoom(_zoom - 0.15), zoom_row)
	z_minus.add_theme_font_size_override("font_size", 17)
	UI.style_button(z_minus, "slate", 7, 2, 3)
	_zoom_label = _label("100%", zoom_row, UI.WHITE, 14)
	_zoom_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var z_plus := _button("+", func(): _set_zoom(_zoom + 0.15), zoom_row)
	z_plus.add_theme_font_size_override("font_size", 17)
	UI.style_button(z_plus, "slate", 7, 2, 3)
	var z_rst := _button("1:1", func(): _set_zoom(1.0); _scroll.scroll_horizontal = 0; _scroll.scroll_vertical = 0, zoom_row)
	z_rst.add_theme_font_size_override("font_size", 14)
	UI.style_button(z_rst, "slate", 6, 2, 3)

	# 3. Right Metallic KSP R&D Sidebar
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 368
	panel.add_theme_stylebox_override("panel", UI.metallic_panel(Color("454c57"), Color("6c7685"), 0, 10))
	main_row.add_child(panel)

	var inspector := VBoxContainer.new()
	inspector.add_theme_constant_override("separation", 10)
	panel.add_child(inspector)

	# Top search bar with orange search icon button (matches Photo 4!)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 4)
	inspector.add_child(search_row)
	var search := LineEdit.new()
	search.placeholder_text = "Enter search..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", 17)
	search.text_changed.connect(_search)
	search_row.add_child(search)
	var clear_btn := Button.new()
	clear_btn.text = "⌕"
	clear_btn.tooltip_text = "Clear search"
	clear_btn.add_theme_font_size_override("font_size", 18)
	UI.style_button(clear_btn, "amber", 8, 3, 3)
	clear_btn.pressed.connect(func(): search.text = ""; _search(""))
	search_row.add_child(clear_btn)

	# Scrollable Node Details + Available Parts Grid
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.add_child(detail_scroll)

	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_details)

	# Blue KSP "Research [⚛ X]" Action Button
	_action = _button("RESEARCH", func(): _confirm(_selected), inspector)
	_action.custom_minimum_size.y = 42
	_action.add_theme_font_size_override("font_size", 19)
	UI.style_button(_action, "blue", 12, 8, 4)

	# Bottom "Requires:" strip
	var req_panel := PanelContainer.new()
	req_panel.add_theme_stylebox_override("panel", UI.inset_well(Color("2e343d"), Color("555f6e"), 3, 8))
	inspector.add_child(req_panel)
	_requires_box = VBoxContainer.new()
	_requires_box.add_theme_constant_override("separation", 6)
	req_panel.add_child(_requires_box)

	# 4. Floating KSP Part Spec Tooltip Card (overlapping left of right sidebar like Photo 4!)
	_part_popup = PanelContainer.new()
	_part_popup.visible = false
	_part_popup.anchor_left = 1.0
	_part_popup.anchor_right = 1.0
	_part_popup.anchor_top = 0.5
	_part_popup.anchor_bottom = 0.5
	_part_popup.offset_left = -690
	_part_popup.offset_right = -356
	_part_popup.offset_top = -105
	_part_popup.offset_bottom = 205
	_part_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_part_popup.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.14, 0.18, 0.23, 0.96), Color("69778a"), 4, 10))
	add_child(_part_popup)
	_part_popup_body = VBoxContainer.new()
	_part_popup_body.add_theme_constant_override("separation", 6)
	_part_popup_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_part_popup.add_child(_part_popup_body)

	_build_tree()
	_dialog = ConfirmationDialog.new()
	_dialog.confirmed.connect(_purchase)
	add_child(_dialog)
	_error = AcceptDialog.new()
	add_child(_error)
	GameManager.campaign_changed.connect(_refresh)
	_refresh()

func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and Input.is_key_pressed(KEY_CTRL):
			_set_zoom(_zoom + 0.1)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and Input.is_key_pressed(KEY_CTRL):
			_set_zoom(_zoom - 0.1)
			accept_event()
	elif event is InputEventMouseMotion and _panning:
		_scroll.scroll_horizontal -= int(event.relative.x)
		_scroll.scroll_vertical -= int(event.relative.y)

func _depth(id: String) -> int:
	if _depths.has(id): return _depths[id]
	var node: Dictionary = GlobalData.get_tech_node(id)
	var depth := int(node.tier) - 1
	for prereq in node.prereqNodes:
		depth = maxi(depth, _depth(prereq) + 1)
	_depths[id] = depth
	return depth

func _build_tree() -> void:
	var start_x := 44.0
	var col_x0 := 196.0
	var col_step := 188.0
	var row_step := 76.0
	var node_sz := Vector2(56, 56)

	var y := 28.0
	var max_depth := 0
	for index in BRANCHES.size():
		_branch_y.append(maxf(0.0, y - 16.0))
		var lane_lbl := _label(TITLES[index], _canvas, Color("5a7599"), 12)
		lane_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lane_lbl.position = Vector2(col_x0, y)
		var counts := {}
		var rows := 1
		for node in GlobalData.tech_nodes:
			if node.branch != BRANCHES[index]: continue
			var depth := _depth(node.id)
			var row: int = counts.get(depth, 0)
			counts[depth] = row + 1
			rows = maxi(rows, row + 1)
			max_depth = maxi(max_depth, depth)
			_positions[node.id] = Vector2(col_x0 + depth * col_step, y + 22.0 + row * row_step)
		y += 38.0 + rows * row_step

	_world_size = Vector2(col_x0 + (max_depth + 1) * col_step + 120.0, maxf(760.0, y + 40.0))
	_canvas.extent = _world_size
	_canvas.size = _world_size
	_surface.custom_minimum_size = _world_size

	# Root KSP "Start" Node on the left of the blueprint tree
	var start_pos := Vector2(start_x, _world_size.y * 0.44)
	var start_card := PanelContainer.new()
	start_card.position = start_pos
	start_card.size = node_sz
	start_card.tooltip_text = "Start — Tier 0 Baseline Spaceflight Hardware"
	start_card.add_theme_stylebox_override("panel", UI.metallic_panel(Color("2b7a29"), Color("8ef55b"), 5, 4))
	var start_center := CenterContainer.new()
	start_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_center.add_child(UI.icon("launch", Vector2(30, 30), UI.WHITE))
	start_card.add_child(start_center)
	_canvas.add_child(start_card)

	for node in GlobalData.tech_nodes:
		if node.prereqNodes.is_empty() and int(node.tier) == 1:
			_canvas.links.append({"from": start_pos + Vector2(node_sz.x, node_sz.y * 0.5), "to": _positions[node.id] + Vector2(0, node_sz.y * 0.5), "owned": true})
		for prereq in node.prereqNodes:
			if _positions.has(prereq):
				_canvas.links.append({"from": _positions[prereq] + Vector2(node_sz.x, node_sz.y * 0.5), "to": _positions[node.id] + Vector2(0, node_sz.y * 0.5), "id": prereq})

	for node in GlobalData.tech_nodes:
		var button := Button.new()
		button.position = _positions[node.id]
		button.size = node_sz
		button.tooltip_text = "%s — %s\n%s" % [node.id, node.name, node.description]
		button.pressed.connect(_select.bind(node.id))
		_canvas.add_child(button)
		_buttons[node.id] = button

		# Vector discipline icon + compact ID code inside the square KSP tech node
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(vbox)

		var ic_wrap := CenterContainer.new()
		ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UI.icon(str(node.branch), Vector2(24, 24), UI.WHITE)
		ic_wrap.add_child(ic)
		vbox.add_child(ic_wrap)

		var code_lbl := Label.new()
		code_lbl.text = str(node.id)
		code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code_lbl.add_theme_font_size_override("font_size", 13)
		code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(code_lbl)
		_node_badges[node.id] = {"icon": ic, "code": code_lbl}

		# Small circular green part-count badge on top-left corner of node (matches KSP "(3)" / "(4)")
		var part_count: int = node.unlocksParts.size()
		if part_count > 0:
			var badge := PartCountBadge.new()
			badge.count = part_count
			badge.position = Vector2(-6, -6)
			badge.size = Vector2(18, 18)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)

func _part_record(id: String) -> Dictionary:
	for item in [GlobalData.get_part(id), GlobalData.get_bus(id), GlobalData.get_launcher(id)]:
		if not item.is_empty(): return item
	return {}

func _part_name(id: String) -> String:
	var rec := _part_record(id)
	return str(rec.name) if not rec.is_empty() else id

func _select(id: String) -> void:
	_selected = id
	_part_popup.visible = false
	_refresh()

func _refresh() -> void:
	if _funds_label:
		_funds_label.text = UI.format_funds_ksp(GameManager.funds_millions)
	if _rep_meter:
		_rep_meter.set("progress", float(GameManager.completed_missions.size() + 1) / 5.0)
	_balance.text = "%d SP" % GameManager.science_points

	for node in GlobalData.tech_nodes:
		var state: String = GameManager.research_status(node.id)
		var button: Button = _buttons[node.id]
		var is_sel: bool = node.id == _selected
		button.tooltip_text = "%s — %s (%d SP)\nStatus: %s\n%s" % [node.id, node.name, node.cost, state, node.description]

		var fill := Color("242b35")
		var border := Color("4f5969")
		var icon_col := Color("aeb8c4")
		if state == "Owned":
			fill = Color("256624")
			border = Color("76e649")
			icon_col = UI.WHITE
		elif state == "Available":
			fill = Color("1f3b57")
			border = UI.KSP_CYAN
			icon_col = UI.WHITE
		elif state == "Post-hackathon":
			fill = Color("191d24")
			border = Color("363d47")
			icon_col = Color("6d7682")

		if is_sel:
			border = Color("b6ff66") if state in ["Owned", "Available"] else UI.KSP_AMBER
			fill = fill.lightened(0.14)

		for st_name in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill.lightened(0.08) if st_name == "hover" else fill
			sb.border_color = border
			sb.set_border_width_all(3 if is_sel else 2)
			sb.set_corner_radius_all(5)
			button.add_theme_stylebox_override(st_name, sb)

		if _node_badges.has(node.id):
			_node_badges[node.id].icon.tint = icon_col
			_node_badges[node.id].icon.queue_redraw()
			_node_badges[node.id].code.add_theme_color_override("font_color", icon_col)

	_canvas.queue_redraw()
	_show_details()

func _show_details() -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	for child in _requires_box.get_children():
		_requires_box.remove_child(child)
		child.queue_free()

	var node: Dictionary = GlobalData.get_tech_node(_selected)
	var state: String = GameManager.research_status(_selected)

	# KSP Inspector Top Card: Square Metallic Icon + Green Node Title
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	_details.add_child(hdr_row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(58, 58)
	icon_frame.add_theme_stylebox_override("panel", UI.metallic_panel(Color("68717d"), Color("98a2b0"), 5, 6))
	var ic_center := CenterContainer.new()
	ic_center.add_child(UI.icon(str(node.branch), Vector2(36, 36), UI.WHITE))
	icon_frame.add_child(ic_center)
	hdr_row.add_child(icon_frame)

	var hdr_col := VBoxContainer.new()
	hdr_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr_col.add_theme_constant_override("separation", 2)
	hdr_row.add_child(hdr_col)

	_label(str(node.name), hdr_col, Color("a6f25c") if state in ["Owned", "Available"] else UI.WHITE, 18)
	_label("%s  ·  Tier %d  ·  %s" % [node.id, node.tier, state], hdr_col, UI.KSP_CYAN if state in ["Owned", "Available"] else UI.KSP_AMBER, 13)

	# Description well
	var desc_well := PanelContainer.new()
	desc_well.add_theme_stylebox_override("panel", UI.inset_well(Color("2e343e"), Color("505a69"), 3, 8))
	_details.add_child(desc_well)
	var desc_col := VBoxContainer.new()
	desc_col.add_theme_constant_override("separation", 6)
	desc_well.add_child(desc_col)
	_label(str(node.description), desc_col, Color("e3e9f0"), 14)
	if not str(node.get("heritage", "")).is_empty():
		_label("Heritage: " + str(node.heritage), desc_col, Color("b4bec9"), 12)

	# "Available Parts" Folder Tab + Tile Grid (matches Photo 4!)
	var parts_tab := PanelContainer.new()
	parts_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parts_tab.add_theme_stylebox_override("panel", UI.metallic_panel(Color("2d333d"), Color("586273"), 3, 5))
	var parts_caption := _label("Available Parts", parts_tab, UI.WHITE, 13)
	parts_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_details.add_child(parts_tab)

	var parts_well := PanelContainer.new()
	parts_well.add_theme_stylebox_override("panel", UI.inset_well(Color("262c35"), Color("525c6b"), 3, 8))
	_details.add_child(parts_well)

	if node.unlocksParts.is_empty():
		var eff_txt := "Launch reliability +2%" if node.id in ["L7", "L8", "L9"] else ("Adapter mass reduced to 1%" if node.id == "L10" else "Program-wide engineering upgrade (no standalone part).")
		_label(eff_txt, parts_well, Color("cfd7e2"), 13)
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		parts_well.add_child(grid)
		for part_id in node.unlocksParts:
			var rec := _part_record(part_id)
			var tile_col := VBoxContainer.new()
			tile_col.add_theme_constant_override("separation", 2)
			grid.add_child(tile_col)

			var tile_btn := Button.new()
			tile_btn.custom_minimum_size = Vector2(68, 68)
			UI.style_button(tile_btn, "tile", 4, 4, 3)
			var prev_center := CenterContainer.new()
			prev_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			prev_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prev_center.add_child(UI.part_preview(rec, Vector2(52, 52)))
			tile_btn.add_child(prev_center)

			tile_btn.mouse_entered.connect(_show_part_popup.bind(rec))
			tile_btn.mouse_exited.connect(func(): _part_popup.visible = false)
			tile_btn.pressed.connect(func():
				if _part_popup.visible:
					_part_popup.visible = false
				else:
					_show_part_popup(rec)
			)
			tile_col.add_child(tile_btn)

			var cost_lbl := Label.new()
			cost_lbl.text = "√ $%.2fM" % float(rec.get("costMillions", 0.0))
			cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost_lbl.add_theme_font_size_override("font_size", 13)
			cost_lbl.add_theme_color_override("font_color", Color("cfd7e2"))
			tile_col.add_child(cost_lbl)

	# Action button text & disabled state (preserves exact test_research.gd contract!)
	_action.text = "Research [⚛ %d]" % node.cost if state == "Available" else state.to_upper()
	_action.disabled = state != "Available"

	# Bottom "Requires:" strip
	_label("Requires:", _requires_box, Color("cfd7e2"), 13)
	if node.prereqNodes.is_empty():
		var start_chip := PanelContainer.new()
		start_chip.add_theme_stylebox_override("panel", UI.metallic_panel(Color("256624"), Color("76e649"), 4, 5))
		var sc_row := HBoxContainer.new()
		sc_row.add_theme_constant_override("separation", 6)
		start_chip.add_child(sc_row)
		sc_row.add_child(UI.icon("launch", Vector2(20, 20), UI.WHITE))
		var start_caption := _label("Start (Tier %d)" % node.tier, sc_row, UI.WHITE, 13)
		start_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		_requires_box.add_child(start_chip)
	else:
		for id in node.prereqNodes:
			var prereq: Dictionary = GlobalData.get_tech_node(id)
			var owned_pre := GameManager.research_status(id) == "Owned"
			var pb := _button("%s · %s" % [id, prereq.name], _navigate.bind(id), _requires_box)
			pb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pb.add_theme_font_size_override("font_size", 14)
			UI.style_button(pb, "green" if owned_pre else "slate", 8, 5, 4)

	if node.prereqMission != null:
		_label("Mission Gate: Complete Mission %s" % node.prereqMission, _requires_box, UI.KSP_AMBER, 12)
	elif int(node.tier) > GameManager.unlocked_tier:
		_label("Campaign Gate: Unlock Tier %d via missions" % int(node.tier), _requires_box, UI.MUTED, 12)

func _show_part_popup(rec: Dictionary) -> void:
	if rec.is_empty():
		_part_popup.visible = false
		return
	for child in _part_popup_body.get_children():
		_part_popup_body.remove_child(child)
		child.queue_free()

	_label(str(rec.get("name", "")), _part_popup_body, UI.KSP_AMBER, 16)

	var top_split := HBoxContainer.new()
	top_split.add_theme_constant_override("separation", 10)
	_part_popup_body.add_child(top_split)

	var icon_well := PanelContainer.new()
	icon_well.add_theme_stylebox_override("panel", UI.inset_well(Color("222a35"), Color("505d70"), 3, 6))
	icon_well.add_child(UI.part_preview(rec, Vector2(72, 72)))
	top_split.add_child(icon_well)

	var stats_lines: Array[String] = []
	if rec.has("massKg"): stats_lines.append("Mass: %.2f kg" % float(rec.massKg))
	if rec.has("dryMassKg"): stats_lines.append("Dry Mass: %.1f kg" % float(rec.dryMassKg))
	if rec.has("volumeLiters") and float(rec.volumeLiters) > 0: stats_lines.append("Volume: %.2f L" % float(rec.volumeLiters))
	if rec.has("internalVolumeLiters"): stats_lines.append("Payload Bay: %.0f L" % float(rec.internalVolumeLiters))
	if float(rec.get("powerGenWatts", 0.0)) > 0: stats_lines.append("Generation: +%.1f W" % float(rec.powerGenWatts))
	if float(rec.get("powerDrawWatts", 0.0)) > 0: stats_lines.append("Power Draw: -%.1f W" % float(rec.powerDrawWatts))
	if rec.has("batteryWh"): stats_lines.append("Capacity: %.0f Wh" % float(rec.batteryWh))
	if rec.has("thrustNewtons"): stats_lines.append("Thrust: %.0f N (Isp %.0f s)" % [float(rec.thrustNewtons), float(rec.get("ispSeconds", 0.0))])
	if rec.has("dataRateKbps"): stats_lines.append("Data Rate: %.0f kbps" % float(rec.dataRateKbps))
	if rec.has("capacityLeoKg"): stats_lines.append("LEO Cap: %.0f kg" % float(rec.capacityLeoKg))
	if rec.get("radiationHardened", false): stats_lines.append("Radiation: Hardened")

	var st_lbl := _label("\n".join(stats_lines), top_split, UI.WHITE, 12)
	st_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var mfg_well := PanelContainer.new()
	mfg_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mfg_well.add_theme_stylebox_override("panel", UI.inset_well(Color("1a222c"), Color("3c4859"), 3, 6))
	_part_popup_body.add_child(mfg_well)
	var mfg_col := VBoxContainer.new()
	mfg_col.add_theme_constant_override("separation", 3)
	mfg_well.add_child(mfg_col)
	_label("Flight Heritage:", mfg_col, Color("8ab4d9"), 11)
	_label(str(rec.get("heritage", "")), mfg_col, Color("d4dde8"), 12)

	var footer := HBoxContainer.new()
	_part_popup_body.add_child(footer)
	var cost_lbl := _label("Cost: √ $%.2fM" % float(rec.get("costMillions", 0.0)), footer, UI.GOLD, 13)
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unlocked := GameManager.is_part_unlocked(str(rec.get("id", "")))
	_label("[Unlocked]" if unlocked else "[R&D Lock]", footer, UI.KSP_GREEN_TEXT if unlocked else UI.KSP_AMBER, 12)

	_part_popup.visible = true

func _navigate(id: String) -> void:
	_select(id)
	_scroll.scroll_horizontal = int(maxf(0, _positions[id].x * _zoom - 60))
	_scroll.scroll_vertical = int(maxf(0, _positions[id].y * _zoom - 60))

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


class PartCountBadge extends Control:
	var count: int = 1

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.48
		draw_circle(c, r, Color("2e6e2c"))
		draw_arc(c, r, 0, TAU, 16, Color("9ef56c"), 1.5, true)
		var font := ThemeDB.fallback_font
		if font:
			draw_string(font, Vector2(0, size.y - 4), str(count), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color.WHITE)
