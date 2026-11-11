extends RefCounted

const WHITE := Color("ffffff")
const BLACK := Color("000000")
const ORANGE := Color("ff8811")
const BLUE := Color("279af1")
const PANEL := Color("101214")
const MUTED := Color("a5abb2")

# KSP Metallic & Instrument Palette
const SLATE_BG := Color("171b21")
const SLATE_DARK := Color("1f242c")
const SLATE_MID := Color("2c323c")
const SLATE_LIGHT := Color("3b4350")
const SLATE_BORDER := Color("596373")
const SLATE_SHADOW := Color("0c0f13")
const LCD_BG := Color("0b0f14")
const LCD_CELL := Color("151c24")
const KSP_GREEN := Color("5aa82b")
const KSP_GREEN_HOVER := Color("6ec437")
const KSP_GREEN_DARK := Color("284d15")
const KSP_GREEN_TEXT := Color("a6f26b")
const KSP_BLUE := Color("1f7ec4")
const KSP_BLUE_HOVER := Color("2c96e3")
const KSP_BLUE_DARK := Color("123a5c")
const KSP_CYAN := Color("56c8ff")
const KSP_AMBER := Color("f59c24")
const KSP_RED := Color("c43b2d")
const KSP_RED_HOVER := Color("de4b3b")
const KSP_RED_DARK := Color("541813")
const GOLD := Color("ffd447")
const BLUEPRINT_BG := Color("0b121e")

static func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(12)
	return style

static func metallic_panel(fill: Color = SLATE_MID, border: Color = SLATE_BORDER, corner: int = 4, pad: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(pad)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	return style

static func inset_well(fill: Color = LCD_BG, border: Color = Color("2a323d"), corner: int = 3, pad: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(pad)
	return style

static func style_button(btn: Button, variant: String = "slate", pad_h: int = 12, pad_v: int = 6, corner: int = 4) -> Button:
	var normal_bg := SLATE_MID
	var hover_bg := SLATE_LIGHT
	var press_bg := SLATE_DARK
	var border := SLATE_BORDER
	var hover_border := Color("8592a6")
	var font_col := WHITE
	match variant:
		"green":
			normal_bg = KSP_GREEN_DARK.lerp(KSP_GREEN, 0.65)
			hover_bg = KSP_GREEN_HOVER
			press_bg = KSP_GREEN_DARK
			border = KSP_GREEN_TEXT
			hover_border = WHITE
		"blue":
			normal_bg = KSP_BLUE_DARK.lerp(KSP_BLUE, 0.7)
			hover_bg = KSP_BLUE_HOVER
			press_bg = KSP_BLUE_DARK
			border = KSP_CYAN
			hover_border = WHITE
		"amber":
			normal_bg = Color("6b410d")
			hover_bg = Color("8f5712")
			press_bg = Color("4a2c08")
			border = KSP_AMBER
			hover_border = WHITE
		"red":
			normal_bg = KSP_RED_DARK.lerp(KSP_RED, 0.7)
			hover_bg = KSP_RED_HOVER
			press_bg = KSP_RED_DARK
			border = Color("ff8070")
			hover_border = WHITE
		"tab_active":
			normal_bg = SLATE_LIGHT
			hover_bg = SLATE_LIGHT.lightened(0.08)
			press_bg = SLATE_MID
			border = KSP_GREEN_TEXT
			hover_border = KSP_GREEN_TEXT
		"tab_inactive":
			normal_bg = SLATE_DARK
			hover_bg = SLATE_MID
			press_bg = SLATE_BG
			border = Color("3c4452")
			font_col = MUTED
		"tile":
			normal_bg = Color("232932")
			hover_bg = Color("313a47")
			press_bg = Color("191e26")
			border = Color("4b5565")
			hover_border = KSP_CYAN
		"tile_selected":
			normal_bg = Color("233b22")
			hover_bg = Color("2d4d2b")
			press_bg = Color("1b2e1a")
			border = KSP_GREEN_TEXT
			hover_border = WHITE
	for pair in [["normal", normal_bg, border], ["hover", hover_bg, hover_border], ["pressed", press_bg, KSP_AMBER]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = pair[1]
		sb.border_color = pair[2]
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 2 if pair[0] != "pressed" else 1
		sb.border_width_bottom = 2 if pair[0] != "pressed" else 1
		sb.set_corner_radius_all(corner)
		sb.content_margin_left = pad_h
		sb.content_margin_right = pad_h
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v
		btn.add_theme_stylebox_override(pair[0], sb)
	var dis := StyleBoxFlat.new()
	dis.bg_color = Color("16191e")
	dis.border_color = Color("2b3038")
	dis.set_border_width_all(1)
	dis.set_corner_radius_all(corner)
	dis.content_margin_left = pad_h
	dis.content_margin_right = pad_h
	dis.content_margin_top = pad_v
	dis.content_margin_bottom = pad_v
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", WHITE)
	btn.add_theme_color_override("font_pressed_color", WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("5c6470"))
	return btn

static func icon(kind: String, custom_size := Vector2(24, 24), tint := WHITE) -> Control:
	var ctrl := VectorIcon.new()
	ctrl.kind = kind
	ctrl.tint = tint
	ctrl.custom_minimum_size = custom_size
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ctrl

static func part_preview(item: Dictionary, custom_size := Vector2(56, 56)) -> Control:
	var ctrl := PartIcon.new()
	ctrl.item = item
	ctrl.custom_minimum_size = custom_size
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ctrl

static func crew_portrait(role: String, caption: String, custom_size := Vector2(104, 118)) -> Control:
	var ctrl := PortraitCard.new()
	ctrl.role = role
	ctrl.caption = caption
	ctrl.custom_minimum_size = custom_size
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ctrl

static func mission_emblem(mission_number: int, custom_size := Vector2(44, 44), unlocked := true) -> Control:
	var ctrl := EmblemIcon.new()
	ctrl.mission_number = mission_number
	ctrl.unlocked = unlocked
	ctrl.custom_minimum_size = custom_size
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ctrl

## Builds the KSP-style top metallic bar with campaign clock on left, Funds / Reputation / Science
## digital readouts in the center, and exit/nav controls on the right.
static func build_agency_bar(left_tabs: Array = []) -> Dictionary:
	var bar_panel := PanelContainer.new()
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color("252a32")
	bar_sb.border_color = Color("495261")
	bar_sb.border_width_bottom = 2
	bar_sb.content_margin_left = 10
	bar_sb.content_margin_right = 10
	bar_sb.content_margin_top = 4
	bar_sb.content_margin_bottom = 4
	bar_panel.add_theme_stylebox_override("panel", bar_sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar_panel.add_child(row)

	var left_box := HBoxContainer.new()
	left_box.add_theme_constant_override("separation", 6)
	row.add_child(left_box)

	var tab_buttons: Array[Button] = []
	for t in left_tabs:
		var tb := Button.new()
		tb.text = str(t)
		tb.add_theme_font_size_override("font_size", 15)
		style_button(tb, "tab_active" if tab_buttons.is_empty() else "tab_inactive", 10, 4, 3)
		left_box.add_child(tb)
		tab_buttons.append(tb)

	var clock_well := PanelContainer.new()
	clock_well.add_theme_stylebox_override("panel", inset_well(LCD_BG, Color("38404d"), 3, 5))
	left_box.add_child(clock_well)
	var time_label := Label.new()
	var day_num := 1 + GameManager.completed_missions.size() * 12
	time_label.text = "Year 1, Day %d - 0h, 0m" % day_num
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color("cfd6df"))
	clock_well.add_child(time_label)

	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_l)

	var center_pod := PanelContainer.new()
	center_pod.add_theme_stylebox_override("panel", metallic_panel(Color("1e232b"), Color("4f5969"), 4, 4))
	row.add_child(center_pod)
	var pod_row := HBoxContainer.new()
	pod_row.add_theme_constant_override("separation", 8)
	center_pod.add_child(pod_row)

	# Funds segmented box
	var funds_well := PanelContainer.new()
	funds_well.add_theme_stylebox_override("panel", inset_well(LCD_BG, Color("2e4a29"), 3, 4))
	pod_row.add_child(funds_well)
	var funds_row := HBoxContainer.new()
	funds_row.add_theme_constant_override("separation", 6)
	funds_well.add_child(funds_row)
	funds_row.add_child(icon("funds", Vector2(18, 18), KSP_GREEN_TEXT))
	var funds_label := Label.new()
	funds_label.add_theme_font_size_override("font_size", 17)
	funds_label.add_theme_color_override("font_color", KSP_GREEN_TEXT)
	funds_row.add_child(funds_label)

	# Reputation / Tier gauge
	var rep_well := PanelContainer.new()
	rep_well.add_theme_stylebox_override("panel", inset_well(LCD_BG, Color("4d4624"), 3, 4))
	pod_row.add_child(rep_well)
	var rep_row := HBoxContainer.new()
	rep_row.add_theme_constant_override("separation", 6)
	rep_well.add_child(rep_row)
	rep_row.add_child(icon("star", Vector2(18, 18), GOLD))
	var rep_bar := ReputationMeter.new()
	rep_bar.custom_minimum_size = Vector2(92, 16)
	rep_row.add_child(rep_bar)

	# Science SP box
	var sci_well := PanelContainer.new()
	sci_well.add_theme_stylebox_override("panel", inset_well(LCD_BG, Color("234763"), 3, 4))
	pod_row.add_child(sci_well)
	var sci_row := HBoxContainer.new()
	sci_row.add_theme_constant_override("separation", 6)
	sci_well.add_child(sci_row)
	sci_row.add_child(icon("science", Vector2(18, 18), KSP_CYAN))
	var science_label := Label.new()
	science_label.add_theme_font_size_override("font_size", 17)
	science_label.add_theme_color_override("font_color", KSP_CYAN)
	sci_row.add_child(science_label)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_r)

	var right_box := HBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	row.add_child(right_box)

	return {
		"bar": bar_panel,
		"left_box": left_box,
		"tabs": tab_buttons,
		"time_label": time_label,
		"funds_label": funds_label,
		"rep_meter": rep_bar,
		"science_label": science_label,
		"right_box": right_box
	}

static func format_funds_ksp(millions: float) -> String:
	var credits := int(round(maxf(0.0, millions) * 1000.0))
	return "%07d ($%.2fM)" % [clampi(credits, 0, 9999999), millions]


class ReputationMeter extends Control:
	var progress: float = 0.25:
		set(v):
			progress = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("141920"))
		var segments := 10
		var gap := 2.0
		var seg_w := (size.x - gap * (segments + 1)) / segments
		for i in segments:
			var x := gap + i * (seg_w + gap)
			var frac := float(i + 1) / segments
			var active := frac <= maxf(0.12, progress)
			var col := Color("c9a227").lerp( Color("7ad938"), float(i) / segments ) if active else Color("252c36")
			draw_rect(Rect2(x, 2, seg_w, size.y - 4), col)


class VectorIcon extends Control:
	var kind: String = "star"
	var tint: Color = Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		match kind:
			"funds":
				draw_line(Vector2(c.x - r * 0.7, c.y + r * 0.1), Vector2(c.x - r * 0.25, c.y + r * 0.7), tint, 2.2, true)
				draw_line(Vector2(c.x - r * 0.25, c.y + r * 0.7), Vector2(c.x + r * 0.2, c.y - r * 0.65), tint, 2.2, true)
				draw_line(Vector2(c.x + r * 0.2, c.y - r * 0.65), Vector2(c.x + r * 0.75, c.y - r * 0.65), tint, 2.2, true)
				draw_line(Vector2(c.x - r * 0.5, c.y - r * 0.1), Vector2(c.x + r * 0.45, c.y - r * 0.1), tint, 1.6, true)
			"science":
				draw_circle(c, r * 0.22, tint)
				for angle: float in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
					var pts := PackedVector2Array()
					for s in 25:
						var a := TAU * float(s) / 24.0
						var local := Vector2(cos(a) * r * 0.95, sin(a) * r * 0.38).rotated(angle)
						pts.append(c + local)
					draw_polyline(pts, tint, 1.5, true)
			"star":
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI / 2.0 + i * PI / 5.0
					var rad := r if i % 2 == 0 else r * 0.42
					pts.append(c + Vector2(cos(a), sin(a)) * rad)
				draw_colored_polygon(pts, tint)
			"power":
				var bolt := PackedVector2Array([
					c + Vector2(r * 0.15, -r * 0.95),
					c + Vector2(-r * 0.65, r * 0.08),
					c + Vector2(-r * 0.05, r * 0.08),
					c + Vector2(-r * 0.25, r * 0.95),
					c + Vector2(r * 0.65, -r * 0.12),
					c + Vector2(r * 0.05, -r * 0.12)
				])
				draw_colored_polygon(bolt, tint)
			"avionics":
				var box_r := Rect2(c - Vector2(r * 0.55, r * 0.55), Vector2(r * 1.1, r * 1.1))
				draw_rect(box_r, tint, false, 2.0)
				draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.25), Vector2(r * 0.5, r * 0.5)), tint, true)
				for o: float in [-0.35, 0.0, 0.35]:
					draw_line(c + Vector2(o * r, -r * 0.9), c + Vector2(o * r, -r * 0.55), tint, 1.6)
					draw_line(c + Vector2(o * r, r * 0.55), c + Vector2(o * r, r * 0.9), tint, 1.6)
					draw_line(c + Vector2(-r * 0.9, o * r), c + Vector2(-r * 0.55, o * r), tint, 1.6)
					draw_line(c + Vector2(r * 0.55, o * r), c + Vector2(r * 0.9, o * r), tint, 1.6)
			"adcs", "adcs_prop":
				draw_arc(c, r * 0.85, 0, TAU, 24, tint, 1.8, true)
				var pts := PackedVector2Array()
				for s in 25:
					var a := TAU * float(s) / 24.0
					pts.append(c + Vector2(cos(a) * r * 0.85, sin(a) * r * 0.35))
				draw_polyline(pts, tint, 1.6, true)
				draw_circle(c, r * 0.2, tint)
			"comms":
				draw_arc(c + Vector2(-r * 0.2, r * 0.2), r * 0.75, -PI * 0.85, -PI * 0.05, 16, tint, 2.2, true)
				draw_line(c + Vector2(-r * 0.2, r * 0.2), c + Vector2(r * 0.45, -r * 0.45), tint, 2.0, true)
				draw_arc(c + Vector2(r * 0.1, -r * 0.1), r * 0.55, -PI * 0.45, PI * 0.05, 12, tint, 1.5, true)
				draw_arc(c + Vector2(r * 0.1, -r * 0.1), r * 0.85, -PI * 0.45, PI * 0.05, 12, tint, 1.5, true)
			"propulsion", "launch":
				var body := PackedVector2Array([
					c + Vector2(0, -r * 0.95),
					c + Vector2(r * 0.36, -r * 0.3),
					c + Vector2(r * 0.36, r * 0.45),
					c + Vector2(-r * 0.36, r * 0.45),
					c + Vector2(-r * 0.36, -r * 0.3)
				])
				draw_colored_polygon(body, tint)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.36, r * 0.1), c + Vector2(-r * 0.72, r * 0.55), c + Vector2(-r * 0.36, r * 0.45)]), tint)
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.36, r * 0.1), c + Vector2(r * 0.72, r * 0.55), c + Vector2(r * 0.36, r * 0.45)]), tint)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.22, r * 0.5), c + Vector2(r * 0.22, r * 0.5), c + Vector2(0, r * 0.98)]), Color("ffb340"))
			"instrument", "instruments":
				draw_circle(c, r * 0.78, Color(tint.r, tint.g, tint.b, 0.22))
				draw_arc(c, r * 0.78, 0, TAU, 24, tint, 2.0, true)
				draw_arc(c, r * 0.38, 0, TAU, 18, tint, 1.6, true)
				draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.12, tint)
			"thermal":
				draw_rect(Rect2(c.x - r * 0.2, c.y - r * 0.85, r * 0.4, r * 1.2), tint, false, 1.8)
				draw_circle(c + Vector2(0, r * 0.5), r * 0.38, tint)
				draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.45), Color("ff6b4a"), 2.4)
			"landing":
				draw_rect(Rect2(c.x - r * 0.45, c.y - r * 0.55, r * 0.9, r * 0.55), tint, true)
				draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(-r * 0.8, r * 0.75), tint, 2.2, true)
				draw_line(c + Vector2(r * 0.4, 0), c + Vector2(r * 0.8, r * 0.75), tint, 2.2, true)
				draw_line(c + Vector2(-r * 0.95, r * 0.75), c + Vector2(-r * 0.55, r * 0.75), tint, 2.2)
				draw_line(c + Vector2(r * 0.55, r * 0.75), c + Vector2(r * 0.95, r * 0.75), tint, 2.2)
			"all":
				for gx: int in [-1, 1]:
					for gy: int in [-1, 1]:
						var p := c + Vector2(gx * r * 0.42, gy * r * 0.42)
						draw_rect(Rect2(p - Vector2(r * 0.28, r * 0.28), Vector2(r * 0.56, r * 0.56)), tint, true)
			"wrench":
				draw_line(c + Vector2(-r * 0.65, r * 0.65), c + Vector2(r * 0.35, -r * 0.35), tint, 3.2, true)
				draw_arc(c + Vector2(r * 0.42, -r * 0.42), r * 0.38, PI * 0.15, PI * 1.6, 14, tint, 2.6, true)
			"checklist":
				draw_rect(Rect2(c - Vector2(r * 0.65, r * 0.8), Vector2(r * 1.3, r * 1.6)), tint, false, 1.8)
				for row_y: float in [-0.35, 0.05, 0.45]:
					draw_line(c + Vector2(-r * 0.35, row_y * r), c + Vector2(r * 0.4, row_y * r), tint, 1.8)
			"globe":
				draw_arc(c, r * 0.82, 0, TAU, 24, tint, 1.8, true)
				draw_line(c + Vector2(-r * 0.82, 0), c + Vector2(r * 0.82, 0), tint, 1.4)
				draw_line(c + Vector2(0, -r * 0.82), c + Vector2(0, r * 0.82), tint, 1.4)
			"battery":
				draw_rect(Rect2(c.x - r * 0.7, c.y - r * 0.42, r * 1.25, r * 0.84), tint, false, 1.8)
				draw_rect(Rect2(c.x + r * 0.55, c.y - r * 0.2, r * 0.18, r * 0.4), tint, true)
				draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.26, r * 0.85, r * 0.52), KSP_GREEN_TEXT, true)
			"exit":
				draw_rect(Rect2(c.x - r * 0.75, c.y - r * 0.75, r * 0.9, r * 1.5), tint, false, 2.0)
				draw_line(c + Vector2(-r * 0.15, 0), c + Vector2(r * 0.8, 0), tint, 2.4)
				draw_line(c + Vector2(r * 0.4, -r * 0.38), c + Vector2(r * 0.8, 0), tint, 2.4)
				draw_line(c + Vector2(r * 0.4, r * 0.38), c + Vector2(r * 0.8, 0), tint, 2.4)
			"comm_bars":
				for b in 4:
					var bh := r * (0.4 + b * 0.35)
					var bx := c.x - r * 0.75 + b * r * 0.42
					draw_rect(Rect2(bx, c.y + r * 0.75 - bh, r * 0.28, bh), tint, true)
			_:
				draw_circle(c, r * 0.65, tint)


class PartIcon extends Control:
	var item: Dictionary = {}

	func _draw() -> void:
		var c := size * 0.5
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.13, 0.75))
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("394352"), false, 1.0)
		var id := str(item.get("id", ""))
		var sub := str(item.get("subsystem", ""))
		if id.begins_with("launcher_"):
			draw_rect(Rect2(c.x - w * 0.11, h * 0.24, w * 0.22, h * 0.58), Color("d8dee6"))
			draw_rect(Rect2(c.x - w * 0.11, h * 0.46, w * 0.22, h * 0.06), Color("1d232b"))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x, h * 0.08), Vector2(c.x + w * 0.13, h * 0.24), Vector2(c.x - w * 0.13, h * 0.24)]), Color("e6ecf2"))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.08, h * 0.82), Vector2(c.x + w * 0.08, h * 0.82), Vector2(c.x, h * 0.94)]), Color("ff9c2a"))
			return
		if id.begins_with("bus_"):
			draw_rect(Rect2(c.x - w * 0.26, c.y - h * 0.24, w * 0.52, h * 0.48), Color("d4a437"))
			draw_rect(Rect2(c.x - w * 0.26, c.y - h * 0.24, w * 0.52, h * 0.48), Color("94a0ad"), false, 2.0)
			draw_line(Vector2(c.x - w * 0.26, c.y), Vector2(c.x + w * 0.26, c.y), Color("6f5314"), 1.5)
			return
		match sub:
			"power":
				if float(item.get("powerGenWatts", 0.0)) > 0.0:
					for p: float in [-1.0, 1.0]:
						var rx: float = c.x + (p * w * 0.22) - w * 0.18
						draw_rect(Rect2(rx, c.y - h * 0.28, w * 0.36, h * 0.56), Color("1a4e96"))
						draw_rect(Rect2(rx, c.y - h * 0.28, w * 0.36, h * 0.56), Color("9db4d4"), false, 1.2)
						draw_line(Vector2(rx, c.y), Vector2(rx + w * 0.36, c.y), Color("7ea2cc"), 1.0)
				else:
					draw_rect(Rect2(c.x - w * 0.28, c.y - h * 0.22, w * 0.56, h * 0.44), Color("3c4957"))
					draw_rect(Rect2(c.x - w * 0.22, c.y - h * 0.14, w * 0.44, h * 0.28), Color("68c938"))
			"propulsion":
				draw_rect(Rect2(c.x - w * 0.18, h * 0.18, w * 0.36, h * 0.28), Color("b8c2cc"))
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x - w * 0.12, h * 0.46),
					Vector2(c.x + w * 0.12, h * 0.46),
					Vector2(c.x + w * 0.26, h * 0.82),
					Vector2(c.x - w * 0.26, h * 0.82)
				]), Color("4d5661"))
			"comms":
				draw_arc(c + Vector2(0, h * 0.08), w * 0.28, PI * 1.1, PI * 1.9, 18, Color("d5dde6"), 3.0, true)
				draw_line(c + Vector2(0, h * 0.08), c + Vector2(0, -h * 0.26), Color("9aa6b5"), 2.0)
				draw_circle(c + Vector2(0, -h * 0.26), 3.0, Color("ff9d2e"))
			"instrument":
				draw_rect(Rect2(c.x - w * 0.24, c.y - h * 0.2, w * 0.48, h * 0.42), Color("39424d"))
				draw_circle(c, w * 0.17, Color("17304d"))
				draw_arc(c, w * 0.17, 0, TAU, 20, Color("9cb3c9"), 2.0, true)
				draw_circle(c + Vector2(-w * 0.05, -h * 0.05), w * 0.04, Color("8fd4ff"))
			"adcs":
				draw_rect(Rect2(c.x - w * 0.25, c.y - h * 0.25, w * 0.5, h * 0.5), Color("2c343e"))
				draw_arc(c, w * 0.18, 0, TAU, 20, Color("e3a83b"), 2.5, true)
				draw_circle(c, w * 0.06, Color("cfd8e3"))
			"avionics":
				draw_rect(Rect2(c.x - w * 0.28, c.y - h * 0.24, w * 0.56, h * 0.48), Color("1e5938"))
				draw_rect(Rect2(c.x - w * 0.13, c.y - h * 0.13, w * 0.26, h * 0.26), Color("22272e"))
				for px: float in [-0.2, 0.0, 0.2]:
					draw_rect(Rect2(c.x + px * w - 2, c.y + h * 0.24, 4, 5), Color("d9b44a"))
			"thermal":
				draw_rect(Rect2(c.x - w * 0.28, c.y - h * 0.24, w * 0.56, h * 0.48), Color("d9a528"))
				for lx: float in [-0.14, 0.0, 0.14]:
					draw_line(Vector2(c.x + lx * w, c.y - h * 0.22), Vector2(c.x + lx * w, c.y + h * 0.22), Color("9e7211"), 1.4)
			"landing":
				draw_line(Vector2(c.x - w * 0.28, h * 0.78), Vector2(c.x, h * 0.22), Color("c4cdd6"), 3.0)
				draw_line(Vector2(c.x + w * 0.28, h * 0.78), Vector2(c.x, h * 0.22), Color("c4cdd6"), 3.0)
				draw_rect(Rect2(c.x - w * 0.36, h * 0.76, w * 0.2, h * 0.06), Color("8e99a6"))
				draw_rect(Rect2(c.x + w * 0.16, h * 0.76, w * 0.2, h * 0.06), Color("8e99a6"))
			_:
				draw_circle(c, w * 0.22, Color("6c7a89"))


class EmblemIcon extends Control:
	var mission_number: int = 1
	var unlocked: bool = true

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.44
		var base := Color("1b2a3d") if unlocked else Color("1d2026")
		var rim := Color("7ab8f5") if unlocked else Color("4a515c")
		draw_circle(c, r, base)
		draw_arc(c, r, 0, TAU, 28, rim, 2.0, true)
		draw_arc(c, r * 0.76, 0, TAU, 24, Color(rim.r, rim.g, rim.b, 0.45), 1.0, true)
		# Planet + orbit swoop inside emblem
		draw_circle(c + Vector2(-r * 0.08, r * 0.06), r * 0.34, Color("2e6fb0") if unlocked else Color("383e47"))
		var swoop := PackedVector2Array()
		for i in 19:
			var a := -0.4 + float(i) / 18.0 * (PI + 0.8)
			swoop.append(c + Vector2(cos(a) * r * 0.68, sin(a) * r * 0.26).rotated(-0.45))
		draw_polyline(swoop, Color("f5a623") if unlocked else Color("5f6670"), 1.8, true)
		draw_circle(swoop[swoop.size() - 1], 2.5, Color.WHITE if unlocked else Color("777f8a"))


class PortraitCard extends Control:
	var role: String = "director"
	var caption: String = "Flight Director"

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("161c24"))
		# Background window / cabin
		draw_rect(Rect2(4, 4, w - 8, h - 24), Color("222c38") if role == "director" else Color("1d242d"))
		if role == "flight":
			# Helmet ring behind crew head
			draw_circle(Vector2(w * 0.5, h * 0.46), w * 0.36, Color("aeb8c4"))
			draw_circle(Vector2(w * 0.5, h * 0.46), w * 0.30, Color("1a232e"))
		else:
			# Control room console glow behind director
			draw_rect(Rect2(8, 10, w * 0.36, h * 0.26), Color("173a54"))
			draw_rect(Rect2(w * 0.58, 12, w * 0.32, h * 0.22), Color("244a32"))
		# Shoulders / suit
		var suit_col := Color("dde3ea") if role == "director" else Color("d96b27")
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.18, h - 22),
			Vector2(w * 0.28, h * 0.62),
			Vector2(w * 0.72, h * 0.62),
			Vector2(w * 0.82, h - 22)
		]), suit_col)
		if role == "director":
			# Dark vest + tie
			draw_colored_polygon(PackedVector2Array([
				Vector2(w * 0.30, h - 22),
				Vector2(w * 0.35, h * 0.63),
				Vector2(w * 0.65, h * 0.63),
				Vector2(w * 0.70, h - 22)
			]), Color("262d38"))
		# Kerbal-inspired cylindrical green head
		var head_col := Color("8ec94f")
		draw_rect(Rect2(w * 0.35, h * 0.24, w * 0.30, h * 0.36), head_col)
		draw_circle(Vector2(w * 0.5, h * 0.26), w * 0.15, head_col)
		# Big expressive eyes
		for ex: float in [0.41, 0.59]:
			draw_circle(Vector2(w * ex, h * 0.39), w * 0.085, Color.WHITE)
			draw_circle(Vector2(w * ex, h * 0.39), w * 0.04, Color("1a1e24"))
		# Confident smile
		draw_arc(Vector2(w * 0.5, h * 0.48), w * 0.075, 0.15, PI - 0.15, 12, Color("243818"), 1.8, true)
		# Headset mic for director
		if role == "director":
			draw_arc(Vector2(w * 0.5, h * 0.32), w * 0.17, PI * 0.95, TAU * 0.98, 16, Color("3c4552"), 2.2, true)
			draw_line(Vector2(w * 0.66, h * 0.40), Vector2(w * 0.55, h * 0.52), Color("3c4552"), 1.8)
		# Nameplate strip at bottom
		draw_rect(Rect2(0, h - 20, w, 20), Color("10141a"))
		draw_rect(Rect2(0, 0, w, h), Color("566170"), false, 2.0)
		var font := ThemeDB.fallback_font
		if font:
			draw_string(font, Vector2(4, h - 5), caption, HORIZONTAL_ALIGNMENT_CENTER, w - 8, 11, Color("d8e0ea"))
