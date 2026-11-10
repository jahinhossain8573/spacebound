extends "res://scripts/CampaignScreen.gd"

const AnimatedMenuButton = preload("res://scripts/MainMenuButton.gd")

func _ready() -> void:
	GameManager.state = GameManager.State.MAIN_MENU
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := Label.new()
	title.name = "Title"
	title.text = "Spacebound"
	title.position = Vector2(64, 48)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color("00e5ff"))
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(edge, 64)
	for edge in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 48)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_body = VBoxContainer.new()
	_body.alignment = BoxContainer.ALIGNMENT_END
	_body.add_theme_constant_override("separation", 12)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_body)
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color("ff4d4d"))
	_body.add_child(_error_label)
	_retry = Button.new()
	_retry.text = "Retry save"
	_retry.visible = false
	_retry.pressed.connect(func(): _retry_action.call())
	_body.add_child(_retry)
	_menu_button("New Campaign", _new_campaign)
	_menu_button("Continue", _continue_campaign, FileAccess.file_exists(GameManager.save_path))
	_menu_button("Credits", _credits)

func _menu_button(caption: String, action: Callable, available: bool = true) -> Button:
	var button := AnimatedMenuButton.new()
	button.text = caption
	button.disabled = not available
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(action)
	_body.add_child(button)
	return button
