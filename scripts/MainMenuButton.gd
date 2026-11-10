extends Button

var _caption: Label
const MENU_FONT = preload("res://assets/fonts/share_tech_mono/ShareTechMono-Regular.ttf")
const MENU_POINTER = preload("res://assets/ui/menu_pointer.png")

var _marker: TextureRect
var _motion: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(480, 72)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color.WHITE
	focus_style.border_width_bottom = 2
	add_theme_stylebox_override("focus", focus_style)
	_caption = _make_label(text, 48, 432)
	_marker = TextureRect.new()
	_marker.texture = MENU_POINTER
	_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_marker.position = Vector2(0, 16)
	_marker.size = Vector2(40, 40)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.modulate.a = 0.0
	add_child(_marker)
	text = ""
	_update_state()
	mouse_entered.connect(func(): _animate.call_deferred())
	mouse_exited.connect(func(): _animate.call_deferred())
	focus_entered.connect(func(): _animate.call_deferred())
	focus_exited.connect(func(): _animate.call_deferred())

func _make_label(caption: String, x: float, width: float) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = Vector2(x, 0)
	label.size = Vector2(width, 72)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", 40)
	add_child(label)
	return label

func _update_state() -> bool:
	var active := not disabled and (is_hovered() or has_focus())
	var tint := Color("666666") if disabled else Color.WHITE
	_caption.add_theme_color_override("font_color", tint)
	return active

func _animate() -> void:
	var active := _update_state()
	if _motion != null:
		_motion.kill()
	_motion = create_tween().set_parallel(true)
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_caption, "position:x", 68.0 if active else 48.0, 0.18)
	_motion.tween_property(_marker, "position:x", 20.0 if active else 0.0, 0.18)
	_motion.tween_property(_marker, "modulate:a", 1.0 if active else 0.0, 0.18)
