extends Control

## Shared KSP-style Flight HUD overlay used by both Launch.gd and FlightView.gd.
## Mouse filter defaults to IGNORE on layout containers so right-drag and wheel zoom reach the 3D viewport.

const UI = preload("res://scripts/UIStyle.gd")

var mode: String = "launch" # "launch" or "orbit"
var met_label: Label
var sun_badge: Label
var back_button: Button
var warp_box: HBoxContainer
var aero_label: Label
var alt_digits: Array[Label] = []
var alt_unit_label: Label
var atmo_gauge: AtmoBar
var vspeed_dial: VSpeedDial
var status_label: Label
var beacon_label: Label
var error_label: Label
var warning_label: Label
var save_retry_button: Button

var stage_num_label: Label
var stage_cards_box: VBoxContainer
var _stage_card_bars: Dictionary = {}
var start_button: Button
var skip_ascent_button: Button

var navball: NavballControl
var trim_gauges: TrimReadout

var drawer_stack: VBoxContainer
var objectives_drawer: PanelContainer
var power_drawer: PanelContainer
var burn_drawer: PanelContainer

var objective_label: Label
var images_label: Label
var battery_label: Label
var battery_bar: ProgressBar
var skip_mission_button: Button
var map_button: Button
var reset_cam_button: Button

func setup(hud_mode: String) -> void:
	mode = hud_mode
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_bottom_left()
	_build_bottom_center()
	_build_bottom_right()

func _build_top_left() -> void:
	var wrap := VBoxContainer.new()
	wrap.position = Vector2(8, 6)
	wrap.add_theme_constant_override("separation", 6)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)

	var pod := PanelContainer.new()
	pod.add_theme_stylebox_override("panel", UI.metallic_panel(Color("222830"), Color("556070"), 4, 5))
	wrap.add_child(pod)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pod.add_child(row)

	back_button = Button.new()
	back_button.text = "< Mission Select" if mode == "launch" else "< Back"
	back_button.add_theme_font_size_override("font_size", 14)
	UI.style_button(back_button, "amber", 8, 3, 3)
	row.add_child(back_button)

	var met_well := PanelContainer.new()
	met_well.add_theme_stylebox_override("panel", UI.inset_well(UI.LCD_BG, Color("2e4a29"), 3, 4))
	row.add_child(met_well)
	met_label = Label.new()
	met_label.text = "T+ 0y, 0d, 00:00:00"
	met_label.add_theme_font_size_override("font_size", 15)
	met_label.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	met_well.add_child(met_label)

	var met_tag := Label.new()
	met_tag.text = "MET"
	met_tag.add_theme_font_size_override("font_size", 13)
	met_tag.add_theme_color_override("font_color", UI.MUTED)
	row.add_child(met_tag)

	row.add_child(UI.icon("comm_bars", Vector2(20, 18), UI.KSP_GREEN_TEXT))

	sun_badge = Label.new()
	sun_badge.text = "PAD" if mode == "launch" else "SUNLIGHT"
	sun_badge.add_theme_font_size_override("font_size", 13)
	sun_badge.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	row.add_child(sun_badge)

	warp_box = HBoxContainer.new()
	warp_box.add_theme_constant_override("separation", 4)
	warp_box.visible = true
	wrap.add_child(warp_box)

	if mode == "launch":
		var aero_pod := PanelContainer.new()
		aero_pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aero_pod.add_theme_stylebox_override("panel", UI.inset_well(Color(0.06, 0.09, 0.13, 0.85), Color("364559"), 3, 5))
		wrap.add_child(aero_pod)
		aero_label = Label.new()
		aero_label.text = "TWR 0.00  ·  Mach 0.00  ·  Q 0.0 kPa  ·  1.0 G"
		aero_label.add_theme_font_size_override("font_size", 12)
		aero_label.add_theme_color_override("font_color", UI.KSP_CYAN)
		aero_pod.add_child(aero_label)

func _build_top_center() -> void:
	var anchor := VBoxContainer.new()
	anchor.anchor_left = 0.5
	anchor.anchor_right = 0.5
	anchor.offset_left = -220
	anchor.offset_right = 220
	anchor.offset_top = 0
	anchor.add_theme_constant_override("separation", 4)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var pod := PanelContainer.new()
	pod.custom_minimum_size = Vector2(360, 0)
	pod.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pod.add_theme_stylebox_override("panel", UI.metallic_panel(Color("2b323c"), Color("687385"), 5, 6))
	anchor.add_child(pod)

	var pod_row := HBoxContainer.new()
	pod_row.add_theme_constant_override("separation", 8)
	pod.add_child(pod_row)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pod_row.add_child(left_col)

	# 6-digit rolling altimeter bar
	var digit_row := HBoxContainer.new()
	digit_row.add_theme_constant_override("separation", 2)
	left_col.add_child(digit_row)

	var mode_tag := PanelContainer.new()
	mode_tag.add_theme_stylebox_override("panel", UI.inset_well(Color("15283d"), Color("3b78b0"), 2, 3))
	digit_row.add_child(mode_tag)
	var sea_lbl := Label.new()
	sea_lbl.text = "ASL"
	sea_lbl.add_theme_font_size_override("font_size", 11)
	sea_lbl.add_theme_color_override("font_color", UI.KSP_CYAN)
	mode_tag.add_child(sea_lbl)

	for i in 6:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(24, 28)
		cell.add_theme_stylebox_override("panel", UI.inset_well(Color("10141a"), Color("3a424f"), 2, 2))
		digit_row.add_child(cell)
		var dl := Label.new()
		dl.text = "0"
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", 20)
		dl.add_theme_color_override("font_color", UI.WHITE)
		cell.add_child(dl)
		alt_digits.append(dl)

	var unit_cell := PanelContainer.new()
	unit_cell.custom_minimum_size = Vector2(30, 28)
	unit_cell.add_theme_stylebox_override("panel", UI.inset_well(Color("241c12"), UI.KSP_AMBER, 2, 3))
	digit_row.add_child(unit_cell)
	alt_unit_label = Label.new()
	alt_unit_label.text = "m"
	alt_unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alt_unit_label.add_theme_font_size_override("font_size", 16)
	alt_unit_label.add_theme_color_override("font_color", UI.KSP_AMBER)
	unit_cell.add_child(alt_unit_label)

	# Atmosphere density bar
	atmo_gauge = AtmoBar.new()
	atmo_gauge.custom_minimum_size = Vector2(220, 18)
	left_col.add_child(atmo_gauge)

	# Analog vertical speed dial on right of top-center pod
	vspeed_dial = VSpeedDial.new()
	vspeed_dial.custom_minimum_size = Vector2(54, 54)
	pod_row.add_child(vspeed_dial)

	# Compact telemetry readout banner below altimeter
	var status_panel := PanelContainer.new()
	status_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", UI.inset_well(Color(0.06, 0.08, 0.11, 0.82), Color("364252"), 3, 5))
	anchor.add_child(status_panel)

	var status_col := VBoxContainer.new()
	status_col.add_theme_constant_override("separation", 2)
	status_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(status_col)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", UI.KSP_CYAN)
	status_col.add_child(status_label)

	beacon_label = Label.new()
	beacon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beacon_label.add_theme_font_size_override("font_size", 14)
	beacon_label.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	beacon_label.visible = false
	status_col.add_child(beacon_label)

	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 14)
	warning_label.add_theme_color_override("font_color", UI.ORANGE)
	warning_label.visible = false
	status_col.add_child(warning_label)

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 14)
	error_label.add_theme_color_override("font_color", UI.ORANGE)
	error_label.visible = false
	status_col.add_child(error_label)

	save_retry_button = Button.new()
	save_retry_button.text = "Retry campaign save"
	save_retry_button.visible = false
	UI.style_button(save_retry_button, "amber", 10, 4, 3)
	status_col.add_child(save_retry_button)

func _build_top_right() -> void:
	var hbox := HBoxContainer.new()
	hbox.anchor_left = 1.0
	hbox.anchor_right = 1.0
	hbox.offset_left = -430
	hbox.offset_right = -6
	hbox.offset_top = 6
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	drawer_stack = VBoxContainer.new()
	drawer_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_stack.add_theme_constant_override("separation", 6)
	drawer_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(drawer_stack)

	# Objectives Drawer
	objectives_drawer = PanelContainer.new()
	objectives_drawer.visible = mode == "orbit"
	objectives_drawer.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.12, 0.15, 0.19, 0.92), UI.SLATE_BORDER, 4, 8))
	drawer_stack.add_child(objectives_drawer)
	var obj_col := VBoxContainer.new()
	obj_col.add_theme_constant_override("separation", 4)
	objectives_drawer.add_child(obj_col)
	var obj_hdr := Label.new()
	obj_hdr.text = "CONTRACT OBJECTIVES"
	obj_hdr.add_theme_font_size_override("font_size", 13)
	obj_hdr.add_theme_color_override("font_color", UI.KSP_AMBER)
	obj_col.add_child(obj_hdr)
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 14)
	obj_col.add_child(objective_label)
	images_label = Label.new()
	images_label.visible = false
	images_label.add_theme_font_size_override("font_size", 14)
	images_label.add_theme_color_override("font_color", UI.KSP_CYAN)
	obj_col.add_child(images_label)

	# Power & Skip Mission Drawer
	power_drawer = PanelContainer.new()
	power_drawer.visible = mode == "orbit"
	power_drawer.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.12, 0.15, 0.19, 0.92), UI.SLATE_BORDER, 4, 8))
	drawer_stack.add_child(power_drawer)
	var pwr_col := VBoxContainer.new()
	pwr_col.add_theme_constant_override("separation", 5)
	power_drawer.add_child(pwr_col)
	var pwr_hdr := Label.new()
	pwr_hdr.text = "ELECTRIC CHARGE & OPS"
	pwr_hdr.add_theme_font_size_override("font_size", 13)
	pwr_hdr.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	pwr_col.add_child(pwr_hdr)
	battery_label = Label.new()
	battery_label.add_theme_font_size_override("font_size", 14)
	pwr_col.add_child(battery_label)
	battery_bar = ProgressBar.new()
	battery_bar.custom_minimum_size.y = 14
	battery_bar.show_percentage = false
	pwr_col.add_child(battery_bar)
	skip_mission_button = Button.new()
	skip_mission_button.text = "Skip mission time"
	skip_mission_button.add_theme_font_size_override("font_size", 14)
	UI.style_button(skip_mission_button, "green", 10, 5, 3)
	pwr_col.add_child(skip_mission_button)

	# Orbital Burn Drawer
	burn_drawer = PanelContainer.new()
	burn_drawer.visible = mode == "orbit"
	burn_drawer.add_theme_stylebox_override("panel", UI.metallic_panel(Color(0.12, 0.15, 0.19, 0.92), UI.SLATE_BORDER, 4, 8))
	drawer_stack.add_child(burn_drawer)

	# Vertical KSP App Toolbar strip on far right
	var app_bar := PanelContainer.new()
	app_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	app_bar.add_theme_stylebox_override("panel", UI.metallic_panel(Color("262c35"), Color("5b6677"), 4, 3))
	hbox.add_child(app_bar)
	var app_col := VBoxContainer.new()
	app_col.add_theme_constant_override("separation", 3)
	app_bar.add_child(app_col)

	if mode == "orbit":
		var btn_obj := _app_icon_btn("checklist", "Toggle Objectives")
		btn_obj.pressed.connect(func(): objectives_drawer.visible = not objectives_drawer.visible)
		app_col.add_child(btn_obj)

		var btn_pwr := _app_icon_btn("battery", "Toggle Electric Charge & Skip")
		btn_pwr.pressed.connect(func(): power_drawer.visible = not power_drawer.visible)
		app_col.add_child(btn_pwr)

		var btn_dv := Button.new()
		btn_dv.text = "Δv"
		btn_dv.tooltip_text = "Toggle Orbital Burn Planner"
		btn_dv.custom_minimum_size = Vector2(36, 34)
		btn_dv.add_theme_font_size_override("font_size", 14)
		UI.style_button(btn_dv, "slate", 4, 4, 3)
		btn_dv.pressed.connect(func(): burn_drawer.visible = not burn_drawer.visible)
		app_col.add_child(btn_dv)

		map_button = Button.new()
		map_button.text = "Map"
		map_button.tooltip_text = "Map view (M)"
		map_button.custom_minimum_size = Vector2(36, 34)
		map_button.add_theme_font_size_override("font_size", 12)
		UI.style_button(map_button, "blue", 4, 4, 3)
		app_col.add_child(map_button)

	reset_cam_button = Button.new()
	reset_cam_button.text = "Cam"
	reset_cam_button.tooltip_text = "Reset camera view"
	reset_cam_button.custom_minimum_size = Vector2(36, 34)
	reset_cam_button.add_theme_font_size_override("font_size", 12)
	UI.style_button(reset_cam_button, "slate", 4, 4, 3)
	app_col.add_child(reset_cam_button)

func _app_icon_btn(icon_kind: String, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(36, 34)
	b.tooltip_text = tip
	UI.style_button(b, "slate", 4, 4, 3)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(UI.icon(icon_kind, Vector2(20, 20), UI.WHITE))
	b.add_child(center)
	return b

func _build_bottom_left() -> void:
	var col := VBoxContainer.new()
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = 8
	col.offset_right = 216
	col.offset_top = -430
	col.offset_bottom = -8
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	stage_cards_box = VBoxContainer.new()
	stage_cards_box.add_theme_constant_override("separation", 4)
	stage_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage_cards_box)

	if mode == "launch":
		start_button = Button.new()
		start_button.text = "Launch now (Space)"
		start_button.add_theme_font_size_override("font_size", 15)
		UI.style_button(start_button, "green", 10, 6, 4)
		col.add_child(start_button)

		skip_ascent_button = Button.new()
		skip_ascent_button.text = "Skip to Orbit"
		skip_ascent_button.visible = false
		skip_ascent_button.add_theme_font_size_override("font_size", 14)
		UI.style_button(skip_ascent_button, "blue", 10, 5, 4)
		col.add_child(skip_ascent_button)

	# KSP STAGE 001 + PITCH/ROLL/YAW trim block
	var trim_pod := PanelContainer.new()
	trim_pod.custom_minimum_size = Vector2(146, 92)
	trim_pod.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	trim_pod.add_theme_stylebox_override("panel", UI.metallic_panel(Color("272d36"), Color("5a6475"), 4, 6))
	col.add_child(trim_pod)

	var trim_col := VBoxContainer.new()
	trim_col.add_theme_constant_override("separation", 4)
	trim_pod.add_child(trim_col)

	var stg_row := HBoxContainer.new()
	stg_row.add_theme_constant_override("separation", 6)
	trim_col.add_child(stg_row)
	var stg_lbl := Label.new()
	stg_lbl.text = "STAGE"
	stg_lbl.add_theme_font_size_override("font_size", 11)
	stg_lbl.add_theme_color_override("font_color", UI.MUTED)
	stg_row.add_child(stg_lbl)

	var stg_well := PanelContainer.new()
	stg_well.add_theme_stylebox_override("panel", UI.inset_well(UI.LCD_BG, Color("3c4554"), 2, 3))
	stg_row.add_child(stg_well)
	stage_num_label = Label.new()
	stage_num_label.text = "001" if mode == "launch" else "000"
	stage_num_label.add_theme_font_size_override("font_size", 15)
	stage_num_label.add_theme_color_override("font_color", UI.KSP_GREEN_TEXT)
	stg_well.add_child(stage_num_label)

	trim_gauges = TrimReadout.new()
	trim_gauges.custom_minimum_size = Vector2(128, 48)
	trim_col.add_child(trim_gauges)

func _build_bottom_center() -> void:
	navball = NavballControl.new()
	navball.custom_minimum_size = Vector2(210, 198)
	navball.anchor_left = 0.5
	navball.anchor_right = 0.5
	navball.anchor_top = 1.0
	navball.anchor_bottom = 1.0
	navball.offset_left = -105
	navball.offset_right = 105
	navball.offset_top = -198
	navball.offset_bottom = 0
	navball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(navball)

func _build_bottom_right() -> void:
	var crew_wrap := PanelContainer.new()
	crew_wrap.anchor_left = 1.0
	crew_wrap.anchor_right = 1.0
	crew_wrap.anchor_top = 1.0
	crew_wrap.anchor_bottom = 1.0
	crew_wrap.offset_left = -114
	crew_wrap.offset_right = -8
	crew_wrap.offset_top = -128
	crew_wrap.offset_bottom = -8
	crew_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crew_wrap.add_theme_stylebox_override("panel", UI.metallic_panel(Color("222830"), Color("5a6475"), 4, 3))
	crew_wrap.add_child(UI.crew_portrait("flight", "Telemetry Ops", Vector2(100, 114)))
	add_child(crew_wrap)

func set_stage_cards(cards: Array) -> void:
	for child in stage_cards_box.get_children():
		child.queue_free()
	_stage_card_bars.clear()
	for card in cards:
		var p := PanelContainer.new()
		var active: bool = card.get("active", false)
		var border := UI.KSP_AMBER if active else Color("4a5566")
		var bg := Color("2e2418") if active else Color("1c232d")
		p.custom_minimum_size = Vector2(146, 0)
		p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		p.add_theme_stylebox_override("panel", UI.metallic_panel(bg, border, 3, 4))
		stage_cards_box.add_child(p)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		p.add_child(vbox)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)
		var idx := Label.new()
		idx.text = str(card.get("index", 0))
		idx.add_theme_font_size_override("font_size", 13)
		idx.add_theme_color_override("font_color", UI.KSP_AMBER)
		row.add_child(idx)
		row.add_child(UI.icon(str(card.get("icon", "propulsion")), Vector2(16, 16), UI.WHITE))
		var title := Label.new()
		title.text = str(card.get("label", "STAGE"))
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", UI.KSP_CYAN if not active else UI.WHITE)
		row.add_child(title)

		if card.has("fuel"):
			var bar := ProgressBar.new()
			bar.max_value = 1.0
			bar.value = clampf(float(card.get("fuel", 1.0)), 0.0, 1.0)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(130, 6)
			var fill := StyleBoxFlat.new()
			fill.bg_color = UI.KSP_GREEN_TEXT if active else Color("4ba3e3")
			bar.add_theme_stylebox_override("fill", fill)
			vbox.add_child(bar)
			if card.has("key"):
				_stage_card_bars[str(card.key)] = bar

func update_stage_fuel(key: String, ratio: float) -> void:
	if _stage_card_bars.has(key) and is_instance_valid(_stage_card_bars[key]):
		(_stage_card_bars[key] as ProgressBar).value = clampf(ratio, 0.0, 1.0)

func update_aero_readout(twr: float, mach: float, q_pa: float, g_load: float, clamped := false) -> void:
	if aero_label == null:
		return
	var clamp_tag := "  ·  [HOLD-DOWN CLAMPS]" if clamped else ""
	aero_label.text = "TWR %.2f  ·  Mach %.2f  ·  Q %.1f kPa  ·  %.1f G%s" % [twr, mach, q_pa / 1000.0, g_load, clamp_tag]

func update_telemetry(altitude_m: float, speed_mps: float, speed_mode: String, pitch_rad: float, heading_deg: float, throttle: float, g_or_bat: float, v_speed_mps: float, met_seconds: float, is_countdown := false, flight_path_rad := NAN) -> void:
	# Format MET
	var sec := int(absf(met_seconds))
	var days := sec / 86400
	var rem := sec % 86400
	var hrs := rem / 3600
	var mins := (rem % 3600) / 60
	var s := rem % 60
	if is_countdown:
		met_label.text = "T- 0y, 0d, 00:00:%02d" % int(ceil(maxf(0.0, met_seconds)))
	else:
		met_label.text = "T+ 0y, %dd, %02d:%02d:%02d" % [days, hrs, mins, s]

	# Rolling 6-digit altimeter
	var display_val := int(round(maxf(0.0, altitude_m)))
	var unit := "m"
	if altitude_m >= 100000.0:
		display_val = int(round(altitude_m / 1000.0))
		unit = "km"
	var digits_str := "%06d" % clampi(display_val, 0, 999999)
	for i in 6:
		alt_digits[i].text = digits_str.substr(i, 1)
	alt_unit_label.text = unit

	atmo_gauge.density = exp(-maxf(0.0, altitude_m) / 8500.0) if altitude_m < 70000.0 else 0.0
	vspeed_dial.vspeed = v_speed_mps

	navball.speed_mps = speed_mps
	navball.speed_mode = speed_mode
	navball.pitch_rad = pitch_rad
	navball.prograde_pitch_rad = pitch_rad if is_nan(flight_path_rad) else flight_path_rad
	navball.heading_deg = heading_deg
	navball.throttle = throttle
	navball.right_bar = g_or_bat
	navball.queue_redraw()

	trim_gauges.pitch_norm = clampf(pitch_rad / (PI * 0.5), -1.0, 1.0)
	trim_gauges.queue_redraw()
	sync_banners()

func sync_banners() -> void:
	if beacon_label:
		beacon_label.visible = not beacon_label.text.is_empty()
	if warning_label:
		warning_label.visible = not warning_label.text.is_empty()
	if error_label:
		error_label.visible = not error_label.text.is_empty()


class AtmoBar extends Control:
	var density: float = 1.0:
		set(v):
			density = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0c1016"))
		var w := size.x - 4.0
		var h := size.y - 4.0
		var bands := [
			[0.0, 0.25, Color("0d1320")],
			[0.25, 0.50, Color("183561")],
			[0.50, 0.75, Color("2e6bb0")],
			[0.75, 1.0, Color("7cb9eb")]
		]
		for b in bands:
			draw_rect(Rect2(2.0 + w * b[0], 2.0, w * (b[1] - b[0]), h), b[2])
		var font := ThemeDB.fallback_font
		if font:
			draw_string(font, Vector2(0, size.y - 4), "ATMOSPHERE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(1, 1, 1, 0.78))
		var nx := 2.0 + w * density
		draw_line(Vector2(nx, 0), Vector2(nx, size.y), Color.WHITE, 2.2)
		draw_rect(Rect2(Vector2.ZERO, size), Color("46505e"), false, 1.0)


class VSpeedDial extends Control:
	var vspeed: float = 0.0:
		set(v):
			vspeed = v
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		draw_circle(c, r, Color("141920"))
		draw_arc(c, r, 0, TAU, 28, Color("5c6675"), 2.0, true)
		for tick: int in [-3, -2, -1, 0, 1, 2, 3]:
			var a: float = PI + tick * 0.36
			draw_line(c + Vector2(cos(a), sin(a)) * (r * 0.72), c + Vector2(cos(a), sin(a)) * (r * 0.94), Color("9aa6b5"), 1.4)
		var norm := clampf(log(1.0 + absf(vspeed)) / log(1001.0), 0.0, 1.0) * signf(vspeed)
		var needle_a := PI + norm * 1.08
		draw_line(c, c + Vector2(cos(needle_a), sin(needle_a)) * (r * 0.82), Color("f59c24"), 2.2, true)
		draw_circle(c, 3.0, Color.WHITE)


class TrimReadout extends Control:
	var pitch_norm: float = 0.0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var rows := [["PITCH", pitch_norm], ["ROLL", 0.0], ["YAW", 0.0]]
		for i in 3:
			var y := 4.0 + i * 15.0
			if font:
				draw_string(font, Vector2(0, y + 9), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, 40, 9, Color("9da7b3"))
			var bx := 38.0
			var bw := size.x - 42.0
			draw_rect(Rect2(bx, y, bw, 10.0), Color("10151c"))
			draw_rect(Rect2(bx, y, bw, 10.0), Color("3c4554"), false, 1.0)
			var mid := bx + bw * 0.5
			draw_line(Vector2(mid, y), Vector2(mid, y + 10.0), Color("596575"), 1.0)
			var marker := mid + float(rows[i][1]) * (bw * 0.42)
			draw_line(Vector2(marker, y + 1), Vector2(marker, y + 9), Color("f59c24"), 2.2)


class NavballControl extends Control:
	var speed_mps: float = 0.0
	var speed_mode: String = "Surface"
	var pitch_rad: float = PI * 0.5
	var prograde_pitch_rad: float = PI * 0.5
	var heading_deg: float = 90.0
	var throttle: float = 0.0
	var right_bar: float = 1.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var ball_c := Vector2(w * 0.5, h * 0.58)
		var ball_r := 66.0

		# Outer metallic housing
		draw_circle(ball_c, ball_r + 16.0, Color("2a313b"))
		draw_arc(ball_c, ball_r + 16.0, 0, TAU, 48, Color("667182"), 2.5, true)

		# Left Throttle arc gauge & Right G/Battery arc gauge
		draw_arc(ball_c, ball_r + 9.0, PI * 0.68, PI * 1.32, 24, Color("12171e"), 7.0, true)
		if throttle > 0.005:
			draw_arc(ball_c, ball_r + 9.0, PI * 0.68, lerpf(PI * 0.68, PI * 1.32, clampf(throttle, 0.0, 1.0)), 20, Color("f59c24"), 6.0, true)

		draw_arc(ball_c, ball_r + 9.0, -PI * 0.32, PI * 0.32, 24, Color("12171e"), 7.0, true)
		if right_bar > 0.005:
			draw_arc(ball_c, ball_r + 9.0, PI * 0.32, lerpf(PI * 0.32, -PI * 0.32, clampf(right_bar, 0.0, 1.0)), 20, Color("68d43b"), 6.0, true)

		# Sky and ground clipped inside ball circle using polygon slices
		var pitch_offset := clampf((pitch_rad / (PI * 0.5)), -1.0, 1.0) * ball_r * 0.85
		draw_circle(ball_c, ball_r, Color("8a5024"))
		var sky_pts := PackedVector2Array()
		var steps := 36
		var y_hor := clampf(ball_c.y + pitch_offset, ball_c.y - ball_r, ball_c.y + ball_r)
		var dy := clampf((y_hor - ball_c.y) / ball_r, -1.0, 1.0)
		var a_span := acos(dy)
		for i in (steps + 1):
			var a := -PI * 0.5 - a_span + (2.0 * a_span) * float(i) / steps
			sky_pts.append(ball_c + Vector2(cos(a), sin(a)) * ball_r)
		if sky_pts.size() >= 3:
			draw_colored_polygon(sky_pts, Color("1f7ac4"))

		# Horizon line & pitch ladder
		var hw := sqrt(maxf(0.0, ball_r * ball_r - (y_hor - ball_c.y) * (y_hor - ball_c.y)))
		if hw > 2.0:
			draw_line(Vector2(ball_c.x - hw, y_hor), Vector2(ball_c.x + hw, y_hor), Color.WHITE, 2.0)
		for deg: int in [-60, -30, 30, 60]:
			var py: float = ball_c.y + pitch_offset - (float(deg) / 90.0) * ball_r * 0.85
			if absf(py - ball_c.y) < ball_r - 6.0:
				var tick_w := 16.0 if abs(deg) == 30 else 10.0
				draw_line(Vector2(ball_c.x - tick_w, py), Vector2(ball_c.x + tick_w, py), Color(1, 1, 1, 0.78), 1.4)
		draw_line(Vector2(ball_c.x, ball_c.y - ball_r + 2), Vector2(ball_c.x, ball_c.y + ball_r - 2), Color(1, 1, 1, 0.3), 1.0)

		# Prograde marker positioned relative to craft attitude (centered when flying zero-AoA!)
		var rel_pitch := prograde_pitch_rad - pitch_rad
		var pro_y := clampf(ball_c.y - (rel_pitch / (PI * 0.5)) * ball_r * 0.85, ball_c.y - ball_r + 12, ball_c.y + ball_r - 12)
		var pro_c := Vector2(ball_c.x, pro_y)
		var pro_col := Color("c8f542")
		draw_arc(pro_c, 6.5, 0, TAU, 16, pro_col, 1.8, true)
		draw_line(pro_c + Vector2(-6.5, 0), pro_c + Vector2(-11.5, 0), pro_col, 1.8)
		draw_line(pro_c + Vector2(6.5, 0), pro_c + Vector2(11.5, 0), pro_col, 1.8)
		draw_line(pro_c + Vector2(0, -6.5), pro_c + Vector2(0, -11.5), pro_col, 1.8)

		# Fixed KSP amber W level-flight reticle at center
		var ret := Color("ffb01f")
		var rw := PackedVector2Array([
			ball_c + Vector2(-22, 0),
			ball_c + Vector2(-9, 0),
			ball_c + Vector2(-4, 6),
			ball_c + Vector2(0, 1),
			ball_c + Vector2(4, 6),
			ball_c + Vector2(9, 0),
			ball_c + Vector2(22, 0)
		])
		draw_polyline(rw, ret, 2.4, true)
		draw_circle(ball_c, 2.2, ret)

		draw_arc(ball_c, ball_r, 0, TAU, 48, Color("11151b"), 2.5, true)

		var top_rect := Rect2(w * 0.5 - 56, 6, 112, 34)
		draw_rect(top_rect, Color("11161d"))
		draw_rect(top_rect, Color("5b6677"), false, 1.8)
		var font := ThemeDB.fallback_font
		if font:
			draw_string(font, Vector2(top_rect.position.x, top_rect.position.y + 13), speed_mode, HORIZONTAL_ALIGNMENT_CENTER, top_rect.size.x, 11, Color("9ad9ab"))
			var spd_txt := "%.1f m/s" % speed_mps if speed_mps < 1500.0 else "%.2f km/s" % (speed_mps / 1000.0)
			draw_string(font, Vector2(top_rect.position.x, top_rect.position.y + 29), spd_txt, HORIZONTAL_ALIGNMENT_CENTER, top_rect.size.x, 14, Color("86f257"))

			draw_rect(Rect2(w * 0.5 - 82, 26, 24, 14), Color("16212b"))
			draw_string(font, Vector2(w * 0.5 - 82, 37), "RCS", HORIZONTAL_ALIGNMENT_CENTER, 24, 9, Color("6f7d8c"))
			draw_rect(Rect2(w * 0.5 + 58, 26, 24, 14), Color("1f3b24"))
			draw_string(font, Vector2(w * 0.5 + 58, 37), "SAS", HORIZONTAL_ALIGNMENT_CENTER, 24, 9, Color("8ef060"))

			var hdg_rect := Rect2(w * 0.5 - 34, h - 19, 68, 17)
			draw_rect(hdg_rect, Color("10141b"))
			draw_rect(hdg_rect, Color("4d5866"), false, 1.2)
			draw_string(font, Vector2(hdg_rect.position.x, hdg_rect.position.y + 13), "HDG %03d°" % (int(round(fposmod(heading_deg, 360.0))) % 360), HORIZONTAL_ALIGNMENT_CENTER, hdg_rect.size.x, 11, Color("86f257"))
