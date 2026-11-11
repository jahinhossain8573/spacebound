extends Control

signal build_changed

const UI = preload("res://scripts/UIStyle.gd")
const WAREHOUSE = preload("res://scripts/WarehouseWorld.gd")
const CATEGORIES := ["power", "avionics", "adcs", "comms", "propulsion", "instrument", "thermal", "landing"]
var mission: Dictionary
var launcher: Dictionary
var bus: Dictionary
var installed_components: Array[Dictionary] = []
var propellant_mass_kg: float = 0.0
var _visuals: Array[Node3D] = []
var _engine_buttons: Array[Button] = []
var _category_container: VBoxContainer
var _installed_container: VBoxContainer
var _fuel_box: VBoxContainer
var _slider: HSlider
var _spin: SpinBox
var _fuel_hint: Label
var _message: Label
var _viewport_container: SubViewportContainer
var _craft: Node3D
var _attachments: Node3D
var _camera: Camera3D
var _pitch := 0.34
var _yaw := 0.42
var _distance := 5.6
var _dragging := false
var _dimensions := Vector3.ONE
var _stats_helper = preload("res://scripts/BuildStats.gd").new()
const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")
const SPACECRAFT = preload("res://scripts/SpacecraftAssembly.gd")
var _mounts: Dictionary = {}
var _telemetry: VBoxContainer
var _launch: Button
var _notice: Label
var stats: Dictionary = {}
var review: Array[Dictionary] = []

# KSP VAB UI state
var _active_category_filter := "all"
var _part_search_query := ""
var _cat_rail_buttons: Dictionary = {}
var _cost_readout_label: Label
var _budget_readout_label: Label
var _stage_dv_badge: Label
var _right_dock: PanelContainer
var _build_tab_box: VBoxContainer
var _brief_tab_box: VBoxContainer

func _ready() -> void:
	GameManager.state = GameManager.State.WORKSHOP
	mission = GameManager.current_mission if not GameManager.current_mission.is_empty() else GlobalData.get_mission(1)
	launcher = GlobalData.get_launcher(mission.get("requiredLauncher", ""))
	bus = GlobalData.get_bus(mission.get("requiredBus", ""))
	if mission.is_empty() or launcher.is_empty() or bus.is_empty():
		push_error("Workshop: mission, launcher or bus is unavailable")
		return
	_make_ui()
	_make_world()
	_refresh_parts()
	_refresh_build()
	build_changed.connect(_update_readiness)
	_update_readiness()
	GameManager.campaign_changed.connect(_refresh_parts)

func _make_ui() -> void:
	# 1. Full-screen 3D Warehouse Viewport behind all VAB chrome
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.focus_mode = Control.FOCUS_ALL
	_viewport_container.gui_input.connect(_viewport_input)
	add_child(_viewport_container)
	var viewport := SubViewport.new()
	viewport.name = "SpacecraftViewport"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(viewport)

	# 2. Top KSP VAB Metallic Header Bar
	var top_bar := PanelContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 44
	top_bar.add_theme_stylebox_override("panel", UI.metallic_panel(Color("262c35"), Color("556070"), 0, 5))
	add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_row)

	# Search field on top-left (above parts palette)
	var search := LineEdit.new()
	search.placeholder_text = "Enter search..."
	search.custom_minimum_size.x = 248
	search.add_theme_font_size_override("font_size", 14)
	search.text_changed.connect(func(q: String):
		_part_search_query = q.strip_edges().to_lower()
		_refresh_parts()
	)
	top_row.add_child(search)

	for mode_lbl in ["Build", "Mounts", "Cleanroom"]:
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UI.inset_well(Color("162530"), Color("386b82"), 3, 4))
		var tl := Label.new()
		tl.text = mode_lbl
		tl.add_theme_font_size_override("font_size", 12)
		tl.add_theme_color_override("font_color", UI.KSP_CYAN)
		tag.add_child(tl)
		top_row.add_child(tag)

	var sp_l := Control.new()
	sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp_l)

	# Center Craft / Mission Name Plaque (matches "Untitled Space Craft" plaque in Photo 3)
	var plaque := PanelContainer.new()
	plaque.custom_minimum_size.x = 380
	plaque.add_theme_stylebox_override("panel", UI.inset_well(Color("171c23"), Color("5c6778"), 4, 5))
	top_row.add_child(plaque)
	var title := Label.new()
	title.text = "%s   •   %s (%s)" % [str(mission.title), str(bus.name), str(launcher.name)]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("ffd97d"))
	plaque.add_child(title)

	var sp_r := Control.new()
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp_r)

	# Top-right KSP Action Toolbar (Reset Cam, Readiness Review, Green Launch, Orange Exit)
	var reset := Button.new()
	reset.text = "Reset View"
	reset.add_theme_font_size_override("font_size", 14)
	UI.style_button(reset, "slate", 10, 4, 3)
	reset.pressed.connect(_reset_camera)
	top_row.add_child(reset)

	var top_review := Button.new()
	top_review.text = "Readiness"
	top_review.tooltip_text = "Run Flight Readiness Review"
	top_review.add_theme_font_size_override("font_size", 14)
	UI.style_button(top_review, "blue", 10, 4, 3)
	top_review.pressed.connect(_show_review)
	top_row.add_child(top_review)

	_launch = Button.new()
	_launch.text = "▶ Launch"
	_launch.disabled = true
	_launch.custom_minimum_size.x = 108
	_launch.add_theme_font_size_override("font_size", 15)
	UI.style_button(_launch, "green", 12, 4, 3)
	_launch.pressed.connect(_launch_build)
	top_row.add_child(_launch)

	var back := Button.new()
	back.text = "< Back"
	back.tooltip_text = "Return to Mission Control"
	back.add_theme_font_size_override("font_size", 14)
	UI.style_button(back, "amber", 10, 4, 3)
	back.pressed.connect(_back)
	top_row.add_child(back)

	# 3. Left KSP VAB Parts Palette (Category Icon Rail + Translucent Parts Drawer)
	var left_dock := HBoxContainer.new()
	left_dock.anchor_bottom = 1.0
	left_dock.offset_left = 0
	left_dock.offset_top = 44
	left_dock.offset_right = 304
	left_dock.offset_bottom = -84
	left_dock.add_theme_constant_override("separation", 0)
	add_child(left_dock)

	var cat_rail := PanelContainer.new()
	cat_rail.custom_minimum_size.x = 40
	cat_rail.add_theme_stylebox_override("panel", UI.metallic_panel(Color("1e232b"), Color("4a5464"), 0, 3))
	left_dock.add_child(cat_rail)
	var rail_col := VBoxContainer.new()
	rail_col.add_theme_constant_override("separation", 3)
	cat_rail.add_child(rail_col)

	for cat_id in ["all"] + CATEGORIES:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(32, 32)
		cb.tooltip_text = "Filter: " + cat_id.to_upper()
		UI.style_button(cb, "tab_active" if cat_id == "all" else "slate", 2, 2, 3)
		var ic_center := CenterContainer.new()
		ic_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_center.add_child(UI.icon(cat_id, Vector2(18, 18), UI.WHITE))
		cb.add_child(ic_center)
		cb.pressed.connect(_set_category_filter.bind(cat_id))
		rail_col.add_child(cb)
		_cat_rail_buttons[cat_id] = cb

	var parts_panel := PanelContainer.new()
	parts_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_panel.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.18, 0.21, 0.25, 0.90), Color("535d6e"), 0, 6))
	left_dock.add_child(parts_panel)

	var parts_vbox := VBoxContainer.new()
	parts_vbox.add_theme_constant_override("separation", 6)
	parts_panel.add_child(parts_vbox)

	var sort_hdr := Label.new()
	sort_hdr.text = "Name  ·  Mass  ·  Cost  ·  Power"
	sort_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sort_hdr.add_theme_font_size_override("font_size", 12)
	sort_hdr.add_theme_color_override("font_color", UI.MUTED)
	parts_vbox.add_child(sort_hdr)

	var part_scroll := ScrollContainer.new()
	part_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	part_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_vbox.add_child(part_scroll)

	_category_container = VBoxContainer.new()
	_category_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_container.add_theme_constant_override("separation", 6)
	part_scroll.add_child(_category_container)

	# 4. Bottom-Left KSP Cost vs Mission Budget Widget
	var cost_pod := PanelContainer.new()
	cost_pod.anchor_top = 1.0
	cost_pod.anchor_bottom = 1.0
	cost_pod.offset_left = 4
	cost_pod.offset_top = -80
	cost_pod.offset_right = 304
	cost_pod.offset_bottom = -4
	cost_pod.add_theme_stylebox_override("panel", UI.metallic_panel(Color("252b34"), Color("5a6475"), 4, 6))
	add_child(cost_pod)

	var cost_col := VBoxContainer.new()
	cost_col.add_theme_constant_override("separation", 4)
	cost_pod.add_child(cost_col)

	var cost_well := PanelContainer.new()
	cost_well.add_theme_stylebox_override("panel", UI.inset_well(UI.LCD_BG, Color("574b24"), 3, 4))
	cost_col.add_child(cost_well)
	_cost_readout_label = Label.new()
	_cost_readout_label.add_theme_font_size_override("font_size", 15)
	_cost_readout_label.add_theme_color_override("font_color", UI.GOLD)
	cost_well.add_child(_cost_readout_label)

	var budget_well := PanelContainer.new()
	budget_well.add_theme_stylebox_override("panel", UI.inset_well(UI.LCD_BG, Color("2e4a29"), 3, 4))
	cost_col.add_child(budget_well)
	_budget_readout_label = Label.new()
	_budget_readout_label.add_theme_font_size_override("font_size", 14)
	_budget_readout_label.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	budget_well.add_child(_budget_readout_label)

	# 5. Right Collapsible Engineer & Loadout Dock
	_right_dock = PanelContainer.new()
	_right_dock.anchor_left = 1.0
	_right_dock.anchor_right = 1.0
	_right_dock.anchor_bottom = 1.0
	_right_dock.offset_left = -356
	_right_dock.offset_top = 50
	_right_dock.offset_right = -6
	_right_dock.offset_bottom = -52
	_right_dock.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.14, 0.17, 0.21, 0.91), Color("535d6e"), 4, 8))
	add_child(_right_dock)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_dock.add_child(right_scroll)

	var right_inner := VBoxContainer.new()
	right_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_inner.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_inner)

	# Build & Telemetry Tab Content
	_build_tab_box = VBoxContainer.new()
	_build_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_tab_box.add_theme_constant_override("separation", 8)
	right_inner.add_child(_build_tab_box)

	var installed_label := Label.new()
	installed_label.text = "INSTALLED PAYLOAD PARTS"
	installed_label.add_theme_font_size_override("font_size", 14)
	installed_label.add_theme_color_override("font_color", UI.KSP_AMBER)
	_build_tab_box.add_child(installed_label)

	var installed_well := PanelContainer.new()
	installed_well.add_theme_stylebox_override("panel", UI.inset_well(Color("10151c"), Color("333d4b"), 3, 6))
	_build_tab_box.add_child(installed_well)

	_installed_container = VBoxContainer.new()
	_installed_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_installed_container.add_theme_constant_override("separation", 4)
	installed_well.add_child(_installed_container)

	_fuel_box = VBoxContainer.new()
	_fuel_box.add_theme_constant_override("separation", 4)
	_build_tab_box.add_child(_fuel_box)
	var fuel_label := Label.new()
	fuel_label.text = "PROPELLANT TANKS (kg)"
	fuel_label.add_theme_font_size_override("font_size", 14)
	fuel_label.add_theme_color_override("font_color", UI.KSP_CYAN)
	_fuel_box.add_child(fuel_label)
	_slider = HSlider.new()
	_slider.max_value = 100.0
	_slider.step = 0.001
	_slider.value_changed.connect(set_propellant_mass)
	_fuel_box.add_child(_slider)
	_spin = SpinBox.new()
	_spin.max_value = 100.0
	_spin.step = 0.001
	_spin.allow_greater = true
	_spin.value_changed.connect(set_propellant_mass)
	_fuel_box.add_child(_spin)
	_fuel_hint = Label.new()
	_fuel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fuel_hint.add_theme_font_size_override("font_size", 12)
	_fuel_hint.add_theme_color_override("font_color", UI.MUTED)
	_fuel_box.add_child(_fuel_hint)
	var fill := Button.new()
	fill.text = "Fill to required Δv + 10%"
	fill.add_theme_font_size_override("font_size", 13)
	UI.style_button(fill, "blue", 8, 4, 3)
	fill.pressed.connect(fill_to_required_delta_v)
	_fuel_box.add_child(fill)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 12)
	_message.add_theme_color_override("font_color", Color("ff8811"))
	_fuel_box.add_child(_message)

	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_font_size_override("font_size", 13)
	_build_tab_box.add_child(_notice)

	var review_button := Button.new()
	review_button.text = "Run Readiness Review"
	review_button.add_theme_font_size_override("font_size", 14)
	UI.style_button(review_button, "amber", 10, 5, 3)
	review_button.pressed.connect(_show_review)
	_build_tab_box.add_child(review_button)

	var telem_hdr := Label.new()
	telem_hdr.text = "ENGINEER REPORT"
	telem_hdr.add_theme_font_size_override("font_size", 14)
	telem_hdr.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	_build_tab_box.add_child(telem_hdr)

	_telemetry = VBoxContainer.new()
	_telemetry.add_theme_constant_override("separation", 4)
	_build_tab_box.add_child(_telemetry)

	# Mission Objective Tab Content
	_brief_tab_box = VBoxContainer.new()
	_brief_tab_box.visible = false
	_brief_tab_box.add_theme_constant_override("separation", 8)
	right_inner.add_child(_brief_tab_box)

	var objective_panel := PanelContainer.new()
	objective_panel.name = "MissionObjectivePanel"
	objective_panel.add_theme_stylebox_override("panel", UI.inset_well(Color("111720"), Color("384556"), 3, 8))
	_brief_tab_box.add_child(objective_panel)
	var objective_content := VBoxContainer.new()
	objective_content.add_theme_constant_override("separation", 6)
	objective_panel.add_child(objective_content)
	var objective_title := Label.new()
	objective_title.text = "MISSION OBJECTIVE  /  " + str(mission.title)
	objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_title.add_theme_font_size_override("font_size", 15)
	objective_title.add_theme_color_override("font_color", UI.KSP_AMBER)
	objective_content.add_child(objective_title)
	var objective_brief := Label.new()
	objective_brief.text = str(mission.get("briefing", ""))
	objective_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_brief.add_theme_font_size_override("font_size", 14)
	objective_content.add_child(objective_brief)
	if mission.has("historyNote"):
		var history := Label.new()
		history.text = "History: " + str(mission.historyNote)
		history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history.add_theme_font_size_override("font_size", 13)
		history.add_theme_color_override("font_color", Color("f0c674"))
		objective_content.add_child(history)
	var required_names: Array[String] = []
	for part_id in mission.get("requiredPartIds", []):
		required_names.append(str(GlobalData.get_part(part_id).get("name", part_id)))
	var objective_details := Label.new()
	objective_details.text = "Orbit: %s · %s km · %s days\nRequired Hardware: %s" % [mission.get("targetOrbit", ""), mission.get("targetAltitudeKm", 0), mission.get("durationDays", 0), ", ".join(required_names)]
	objective_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_details.add_theme_font_size_override("font_size", 14)
	objective_details.add_theme_color_override("font_color", UI.KSP_CYAN)
	objective_content.add_child(objective_details)

	# 6. Bottom-Right KSP Engineer App Strip + Stage Δv Pill
	var bottom_right := HBoxContainer.new()
	bottom_right.anchor_left = 1.0
	bottom_right.anchor_right = 1.0
	bottom_right.anchor_top = 1.0
	bottom_right.anchor_bottom = 1.0
	bottom_right.offset_left = -420
	bottom_right.offset_top = -44
	bottom_right.offset_right = -6
	bottom_right.offset_bottom = -4
	bottom_right.alignment = BoxContainer.ALIGNMENT_END
	bottom_right.add_theme_constant_override("separation", 6)
	add_child(bottom_right)

	var dock_bar := PanelContainer.new()
	dock_bar.add_theme_stylebox_override("panel", UI.metallic_panel(Color("262c35"), Color("5a6475"), 4, 3))
	bottom_right.add_child(dock_bar)
	var dock_btns := HBoxContainer.new()
	dock_btns.add_theme_constant_override("separation", 4)
	dock_bar.add_child(dock_btns)

	var btn_eng := Button.new()
	btn_eng.text = "Δv / Engineer"
	btn_eng.add_theme_font_size_override("font_size", 13)
	UI.style_button(btn_eng, "tab_active", 8, 3, 3)
	dock_btns.add_child(btn_eng)

	var btn_brief := Button.new()
	btn_brief.text = "Briefing"
	btn_brief.add_theme_font_size_override("font_size", 13)
	UI.style_button(btn_brief, "slate", 8, 3, 3)
	dock_btns.add_child(btn_brief)

	var btn_hide := Button.new()
	btn_hide.text = "Hide UI"
	btn_hide.add_theme_font_size_override("font_size", 13)
	UI.style_button(btn_hide, "slate", 8, 3, 3)
	dock_btns.add_child(btn_hide)

	btn_eng.pressed.connect(func():
		_right_dock.visible = true
		_build_tab_box.visible = true
		_brief_tab_box.visible = false
		UI.style_button(btn_eng, "tab_active", 8, 3, 3)
		UI.style_button(btn_brief, "slate", 8, 3, 3)
	)
	btn_brief.pressed.connect(func():
		_right_dock.visible = true
		_build_tab_box.visible = false
		_brief_tab_box.visible = true
		UI.style_button(btn_eng, "slate", 8, 3, 3)
		UI.style_button(btn_brief, "tab_active", 8, 3, 3)
	)
	btn_hide.pressed.connect(func():
		_right_dock.visible = not _right_dock.visible
	)

	var stage_pill := PanelContainer.new()
	stage_pill.add_theme_stylebox_override("panel", UI.metallic_panel(Color("1c2e42"), UI.KSP_AMBER, 4, 5))
	bottom_right.add_child(stage_pill)
	_stage_dv_badge = Label.new()
	_stage_dv_badge.text = "0 m/s"
	_stage_dv_badge.add_theme_font_size_override("font_size", 13)
	_stage_dv_badge.add_theme_color_override("font_color", UI.KSP_CYAN)
	stage_pill.add_child(_stage_dv_badge)

func _set_category_filter(cat_id: String) -> void:
	_active_category_filter = cat_id
	for k in _cat_rail_buttons:
		UI.style_button(_cat_rail_buttons[k], "tab_active" if k == cat_id else "slate", 2, 2, 3)
	_refresh_parts()

func _make_world() -> void:
	var viewport: SubViewport = _viewport_container.get_child(0)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2a3038")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfd8e3")
	environment.ambient_light_energy = 0.78
	MODEL_LIBRARY.use_sky_reflections(environment)
	env.environment = environment
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 1.05
	world.add_child(light)

	# Build full 3D VAB Assembly Warehouse around the central spacecraft stand
	WAREHOUSE.populate_warehouse(world, str(launcher.get("id", "launcher_electron")))

	_camera = Camera3D.new()
	_camera.current = true
	world.add_child(_camera)
	var dims: Array = bus.dimensionsMeters
	_dimensions = Vector3(dims[0], dims[1], dims[2])
	_craft = Node3D.new()
	_craft.scale = Vector3.ONE * (2.0 / maxf(_dimensions.x, maxf(_dimensions.y, _dimensions.z)))
	world.add_child(_craft)
	_attachments = Node3D.new()
	_attachments.name = "Attachments"
	var model := MODEL_LIBRARY.instantiate("buses", bus.id)
	if model:
		model.name = "Bus"
		_craft.add_child(model)
		_craft.add_child(_attachments)
		_mounts = SPACECRAFT.mounts_of(model)
		_reset_camera()
		return
	var box := CSGBox3D.new()
	box.name = "Bus"
	box.size = _dimensions
	box.material = _material(Color("d5d9de"))
	_craft.add_child(box)
	_craft.add_child(_attachments)
	for marker in {"mount_top": Vector3(0, _dimensions.y/2, 0), "mount_bottom": Vector3(0, -_dimensions.y/2, 0), "mount_front": Vector3(0, 0, -_dimensions.z/2), "mount_back": Vector3(0, 0, _dimensions.z/2), "mount_left": Vector3(-_dimensions.x/2, 0, 0), "mount_right": Vector3(_dimensions.x/2, 0, 0), "array_hinge_left": Vector3(-_dimensions.x/2, 0, 0), "array_hinge_right": Vector3(_dimensions.x/2, 0, 0), "engine_mount": Vector3(0, -_dimensions.y/2, 0)}:
		var point := Marker3D.new()
		point.name = marker
		point.position = {"mount_top": Vector3(0, _dimensions.y/2, 0), "mount_bottom": Vector3(0, -_dimensions.y/2, 0), "mount_front": Vector3(0, 0, -_dimensions.z/2), "mount_back": Vector3(0, 0, _dimensions.z/2), "mount_left": Vector3(-_dimensions.x/2, 0, 0), "mount_right": Vector3(_dimensions.x/2, 0, 0), "array_hinge_left": Vector3(-_dimensions.x/2, 0, 0), "array_hinge_right": Vector3(_dimensions.x/2, 0, 0), "engine_mount": Vector3(0, -_dimensions.y/2, 0)}[marker]
		if marker in ["mount_bottom", "engine_mount"]:
			point.rotation.z = PI
		elif marker == "mount_front":
			point.rotation.x = -PI / 2.0
		elif marker == "mount_back":
			point.rotation.x = PI / 2.0
		elif marker in ["mount_left", "array_hinge_left"]:
			point.rotation.z = PI / 2.0
		elif marker in ["mount_right", "array_hinge_right"]:
			point.rotation.z = -PI / 2.0
		_craft.add_child(point)
		_mounts[marker] = point
	_reset_camera()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)

func _refresh_parts() -> void:
	for child in _category_container.get_children():
		child.queue_free()
	_engine_buttons.clear()
	var groups: Dictionary = GlobalData.parts_by_subsystem(true)
	var req_ids: Array = mission.get("requiredPartIds", [])
	for category in CATEGORIES:
		if _active_category_filter != "all" and category != _active_category_filter:
			continue
		if not groups.has(category):
			continue
		var matching_parts: Array[Dictionary] = []
		for part: Dictionary in groups[category]:
			if not _part_search_query.is_empty():
				var hay := (str(part.name) + " " + str(part.subsystem) + " " + str(part.heritage)).to_lower()
				if not hay.contains(_part_search_query):
					continue
			matching_parts.append(part)
		if matching_parts.is_empty():
			continue

		var cat_hdr := Label.new()
		cat_hdr.text = "▾ " + category.to_upper()
		cat_hdr.add_theme_font_size_override("font_size", 13)
		cat_hdr.add_theme_color_override("font_color", UI.KSP_AMBER)
		_category_container.add_child(cat_hdr)

		for part: Dictionary in matching_parts:
			var button := Button.new()
			button.custom_minimum_size.y = 58
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var is_req: bool = part.id in req_ids
			UI.style_button(button, "tile_selected" if is_req else "tile", 6, 4, 3)
			button.tooltip_text = "%s\nMass: %.2f kg  |  Volume: %.2f L\nPower: +%.1f W / -%.1f W  |  Cost: $%.2fM\n%s" % [
				part.name, part.massKg, part.volumeLiters, part.powerGenWatts, part.powerDrawWatts, part.costMillions, part.heritage
			]
			button.pressed.connect(add_part.bind(part.id))

			var row := HBoxContainer.new()
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 6
			row.offset_right = -6
			row.offset_top = 4
			row.offset_bottom = -4
			row.add_theme_constant_override("separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(row)

			row.add_child(UI.part_preview(part, Vector2(44, 44)))

			var txt_col := VBoxContainer.new()
			txt_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			txt_col.alignment = BoxContainer.ALIGNMENT_CENTER
			txt_col.add_theme_constant_override("separation", 2)
			txt_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(txt_col)

			var nm := Label.new()
			nm.text = str(part.name) + (" ★" if is_req else "")
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nm.add_theme_font_size_override("font_size", 13)
			nm.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT if is_req else UI.WHITE)
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			txt_col.add_child(nm)

			var specs := Label.new()
			specs.text = "%.2f kg · +%.0f/-%.1fW · $%.2fM" % [part.massKg, part.powerGenWatts, part.powerDrawWatts, part.costMillions]
			specs.add_theme_font_size_override("font_size", 11)
			specs.add_theme_color_override("font_color", UI.MUTED)
			specs.mouse_filter = Control.MOUSE_FILTER_IGNORE
			txt_col.add_child(specs)

			_category_container.add_child(button)
			if part.get("thrustNewtons", 0.0) > 0.0:
				button.disabled = not _engine().is_empty()
				_engine_buttons.append(button)

func _engine() -> Dictionary:
	for part in installed_components:
		if part.get("thrustNewtons", 0.0) > 0.0:
			return part
	return {}

func add_part(part_id: String) -> bool:
	var part: Dictionary = GlobalData.get_part(part_id)
	if part.is_empty() or not GameManager.is_part_unlocked(part_id):
		return false
	if part.get("thrustNewtons", 0.0) > 0.0 and not _engine().is_empty():
		return false
	installed_components.append(part)
	_refresh_build()
	build_changed.emit()
	return true

func remove_part(index: int) -> void:
	if index < 0 or index >= installed_components.size():
		return
	var was_engine: bool = installed_components[index].get("thrustNewtons", 0.0) > 0.0
	installed_components.remove_at(index)
	if was_engine:
		propellant_mass_kg = 0.0
	_refresh_build()
	build_changed.emit()

func set_propellant_mass(kg: float) -> void:
	var value := maxf(0.0, kg) if not _engine().is_empty() and is_finite(kg) else 0.0
	if is_equal_approx(value, propellant_mass_kg):
		return
	propellant_mass_kg = value
	_sync_fuel()
	build_changed.emit()

func _sync_fuel() -> void:
	var limits: Dictionary = _stats_helper.propellant_limits(_build_data(), mission)
	# The slider covers usable headroom; the spin box still permits deliberate overloads.
	var upper := maxf(0.001, maxf(floorf(limits.maximum_kg * 1000.0) / 1000.0, propellant_mass_kg))
	_slider.set_block_signals(true)
	_spin.set_block_signals(true)
	_slider.max_value = upper
	_spin.max_value = maxf(100.0, upper)
	_slider.value = propellant_mass_kg
	_spin.value = propellant_mass_kg
	_slider.set_block_signals(false)
	_spin.set_block_signals(false)
	_fuel_hint.text = "Fuel allowance: %.3f kg, limited by %s." % [limits.maximum_kg, limits.limiting_factor]
	if float(mission.get("requiredDeltaVMps", 0.0)) <= 0.0:
		_fuel_hint.text += " This mission needs no propulsion; its launcher supplies the orbit."
	if propellant_mass_kg > limits.maximum_kg + 0.000001:
		_fuel_hint.text += " Current fuel exceeds this allowance. Reduce fuel or remove parts."

func fill_to_required_delta_v() -> void:
	var engine := _engine()
	if engine.is_empty():
		return
	var target: float = float(mission.requiredDeltaVMps) * 1.1
	var dry: float = float(bus.dryMassKg)
	for part in installed_components:
		dry += float(part.massKg)
	var q: float = FlightSim.calculate_required_propellant(1.0, target, engine.ispSeconds)
	if not is_finite(q) or q * FlightSim.TANK_MASS_RATIO >= 1.0:
		_message.text = "This engine cannot reach the target with its tank mass."
		return
	var fuel := 0.0
	for i in 4:
		fuel = FlightSim.calculate_required_propellant(dry + fuel * FlightSim.TANK_MASS_RATIO, target, engine.ispSeconds)
	fuel = maxf(fuel, dry * q / (1.0 - q * FlightSim.TANK_MASS_RATIO))
	if target > 0.0:
		fuel *= 1.000001
	_message.text = ""
	set_propellant_mass(fuel)

func _refresh_build() -> void:
	for child in _installed_container.get_children():
		_installed_container.remove_child(child)
		child.queue_free()
	var categories: Array[String] = []
	categories.assign(CATEGORIES)
	for part in installed_components:
		var subsystem: String = part.get("subsystem", "other")
		if subsystem not in categories: categories.append(subsystem)
	for category in categories:
		var indices: Array[int] = []
		for i in installed_components.size():
			if installed_components[i].get("subsystem", "other") == category: indices.append(i)
		if indices.is_empty(): continue
		var heading := Label.new()
		heading.text = category.to_upper().replace("_", " ")
		heading.add_theme_font_size_override("font_size", 12)
		heading.add_theme_color_override("font_color", UI.KSP_CYAN)
		_installed_container.add_child(heading)
		for index in indices:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_installed_container.add_child(row)
			var label := Label.new()
			label.text = installed_components[index].name
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.add_theme_font_size_override("font_size", 13)
			row.add_child(label)
			var remove := Button.new()
			remove.text = "×"
			remove.tooltip_text = "Remove " + str(installed_components[index].name)
			remove.add_theme_font_size_override("font_size", 13)
			UI.style_button(remove, "red", 7, 2, 3)
			remove.pressed.connect(remove_part.bind(index))
			row.add_child(remove)
	for child in _attachments.get_children():
		child.queue_free()
	_visuals.clear()
	var wing := 0
	var occupied := {}
	for i in installed_components.size():
		var part := installed_components[i]
		var visual := Node3D.new()
		visual.name = "Part%d" % i
		_attachments.add_child(visual)
		_visuals.append(visual)
		var d := _dimensions
		var models := SPACECRAFT.place_part(part, _mounts, occupied, d)
		for instance in models:
			visual.add_child(instance)
		if not models.is_empty():
			continue
		if part.id == "pwr_gomspace_p31u":
			_box(visual, Vector3(d.x*0.85,d.y*0.85,d.z*0.03), Vector3(0,0,-d.z*0.52), Color("173f79"))
			_box(visual, Vector3(d.x*0.85,d.y*0.85,d.z*0.03), Vector3(0,0,d.z*0.52), Color("173f79"))
		elif part.subsystem == "power" and part.powerGenWatts > 0 and part.isExternal:
			var side := -1.0 if wing % 2 == 0 else 1.0
			_box(visual, Vector3(d.x,d.y*0.75,d.z*0.05), Vector3(side*d.x,0,0), Color("16447f"))
			wing += 1
		elif part.get("thrustNewtons", 0.0) > 0.0 and part.isExternal:
			var nozzle := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = d.x*0.08
			cylinder.bottom_radius = d.x*0.2
			cylinder.height = d.y*0.3
			nozzle.mesh = cylinder
			nozzle.position.y = -d.y*0.65
			nozzle.material_override = _material(Color("515e68"))
			visual.add_child(nozzle)
		elif part.subsystem == "landing" and part.id == "land_hex_gear":
			for x: int in [-1,1]:
				for z: int in [-1,1]:
					_box(visual, Vector3(d.x*0.06,d.y*0.4,d.z*0.06), Vector3(x*d.x*0.4,-d.y*0.7,z*d.z*0.4), Color("aab5be"))
					visual.get_child(visual.get_child_count() - 1).rotation.z = x * 0.3
		elif part.subsystem == "comms":
			_box(visual, Vector3(d.x*0.25,d.y*0.15,d.z*0.25), Vector3(0,d.y*0.57,0), Color("98a8b4"))
		elif part.subsystem == "instrument":
			_box(visual, Vector3(d.x*0.25,d.y*0.25,d.z*0.15), Vector3(0,0,-d.z*0.58), Color("42515c"))
	for button in _engine_buttons:
		button.disabled = not _engine().is_empty()
	_fuel_box.visible = not _engine().is_empty()
	_sync_fuel()

func _viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_viewport_container.grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if event.pressed:
				_viewport_container.grab_focus()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2.5, 11.5)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.01, -0.22, 1.18)
		_update_camera()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _yaw -= 0.1
			KEY_RIGHT: _yaw += 0.1
			KEY_UP: _pitch -= 0.1
			KEY_DOWN: _pitch += 0.1
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: _distance *= 0.9
			KEY_MINUS, KEY_KP_SUBTRACT: _distance *= 1.1
			_: return
		_pitch = clampf(_pitch, -0.22, 1.18)
		_distance = clampf(_distance, 2.5, 11.5)
		_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_dragging = false

func _update_camera() -> void:
	var raw := Vector3(sin(_yaw)*cos(_pitch), sin(_pitch), cos(_yaw)*cos(_pitch)) * _distance
	raw.y = maxf(raw.y, WAREHOUSE.FLOOR_Y + 0.55)
	_camera.position = raw
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _reset_camera() -> void:
	_yaw = 0.42
	_pitch = 0.34
	_distance = 5.6
	_update_camera()

func _back() -> void:
	var path := "res://scenes/MissionSelect.tscn"
	get_tree().change_scene_to_file(path if ResourceLoader.exists(path) else "res://scenes/MainMenu.tscn")

func _build_data() -> Dictionary:
	return {"launcher": launcher, "bus": bus, "installed_components": installed_components, "propellant_mass_kg": propellant_mass_kg}

func _update_readiness() -> void:
	var build := _build_data()
	stats = _stats_helper.calculate_stats(build, mission)
	review = _stats_helper.run_readiness_review(build, mission)
	_launch.disabled = _has_failures()
	_notice.text = ""

	if _cost_readout_label:
		_cost_readout_label.text = "√ Cost: $%.2fM (%06d)" % [stats.cost_millions, int(round(stats.cost_millions * 1000.0))]
		_cost_readout_label.add_theme_color_override("font_color", UI.ORANGE if stats.cost_millions > stats.budget_millions else UI.GOLD)
	if _budget_readout_label:
		_budget_readout_label.text = "√ Cap:  $%.2fM  |  Parts: %d" % [stats.budget_millions, installed_components.size()]
	if _stage_dv_badge:
		_stage_dv_badge.text = "STAGE 0   |   %.0f m/s Δv   |   %s" % [stats.delta_v_mps, "READY" if not _has_failures() else "CHECK"]

	for child in _telemetry.get_children():
		child.queue_free()
	var endurance := "No load" if is_inf(stats.endurance_minutes) else "%.1f min" % stats.endurance_minutes
	if mission.get("targetOrbit", "") == "SSO":
		var capacity := Label.new()
		capacity.text = "SSO capacity: %.0f kg" % stats.launcher_capacity_kg
		capacity.add_theme_font_size_override("font_size", 12)
		_telemetry.add_child(capacity)
	elif mission.get("targetOrbit", "") in ["GEO", "GTO"]:
		var capacity := Label.new()
		capacity.text = "GTO capacity: %.0f kg" % stats.launcher_capacity_kg
		capacity.add_theme_font_size_override("font_size", 12)
		_telemetry.add_child(capacity)
	_add_telemetry("Mass", "%.2f / %.2f kg (%.1f%% margin)" % [stats.wet_mass_kg, stats.launcher_capacity_kg, stats.mass_margin_pct], stats.wet_mass_kg, stats.launcher_capacity_kg * 0.9, "Mass budget")
	_add_telemetry("Volume", "%.2f / %.2f L" % [stats.internal_volume_liters, stats.volume_capacity_liters], stats.internal_volume_liters, stats.volume_capacity_liters, "Volume")
	_add_telemetry("Power", "+%.1f / -%.1f W (net %.1f W)" % [stats.generation_w, stats.draw_w, stats.net_power_w], stats.draw_w, stats.generation_w, "Daylight power")
	_add_telemetry("Battery", "%.1f Wh; %s / %.1f min eclipse" % [stats.battery_wh, endurance, stats.eclipse_minutes], stats.eclipse_minutes, stats.endurance_minutes, "Eclipse endurance")
	_add_telemetry("Delta-v", "%.1f / %.1f m/s" % [stats.delta_v_mps, stats.delta_v_target_mps], stats.delta_v_target_mps, stats.delta_v_mps, "Delta-v")
	_add_telemetry("Cost", "$%.2fM / $%.2fM" % [stats.cost_millions, stats.budget_millions], stats.cost_millions, stats.budget_millions, "Budget")

func _add_telemetry(title: String, text: String, used: float, limit: float, check_name: String) -> void:
	var status := "PASS"
	for item in review:
		if item.check == check_name: status = item.status
	var color := Color("ff8811") if status == "FAIL" else (Color("f5b942") if status == "ADVISORY" or (is_finite(limit) and limit > 0.0 and used >= limit * 0.9) else UI.KSP_GREEN_TEXT)
	var label := Label.new()
	label.text = title + ": " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	_telemetry.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = clampf(used / limit * 100.0, 0.0, 100.0) if is_finite(limit) and limit > 0 else 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	_telemetry.add_child(bar)

func _has_failures() -> bool:
	for item in review:
		if item.status == "FAIL": return true
	return false

func _show_review() -> void:
	var dialog: AcceptDialog = load("res://scenes/ui/ReadinessReport.tscn").instantiate()
	add_child(dialog)
	var container: VBoxContainer = dialog.get_node("Scroll/Checks")
	for item in review:
		var label := Label.new()
		label.text = "%s — %s: %s" % [item.status, item.check, item.message]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 600
		label.add_theme_color_override("font_color", Color("ff8811") if item.status == "FAIL" else (Color("ff8811") if item.status == "ADVISORY" else UI.KSP_GREEN_TEXT))
		container.add_child(label)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(700, 600))

func _launch_build() -> void:
	_update_readiness()
	if _has_failures(): return
	var build := _build_data().duplicate(true)
	build["stats"] = stats.duplicate(true)
	GameManager.current_build = build
	if ResourceLoader.exists("res://scenes/Launch.tscn"):
		GameManager.state = GameManager.State.LAUNCH
		get_tree().change_scene_to_file("res://scenes/Launch.tscn")
	else:
		_notice.text = "Build ready. Launch sequence coming soon."
