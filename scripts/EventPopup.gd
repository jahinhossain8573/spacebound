extends Control
signal choice_selected(choice: String)
signal closed
var _body: VBoxContainer
var _outcome: bool = false

func setup(event: Dictionary, can_avoid: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(edge, 24)
	panel.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	margin.add_child(_body)
	var title := Label.new()
	title.text = "%s  /  %s" % [event.severity.to_upper(), event.title]
	title.add_theme_color_override("font_color", {"Minor":Color("ffb300"), "Major":Color("ff913d"), "Critical":Color("ff4d4d"), "Positive":Color("55d785")}[event.severity])
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(title)
	var description := Label.new()
	description.text = event.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(description)
	if event.choices.is_empty():
		_add_button("Continue", "continue", true)
	else:
		for choice in event.choices:
			_add_button(choice.label, choice.outcome, choice.outcome != "avoid" or can_avoid)

func _add_button(label: String, choice: String, enabled: bool) -> void:
	var button := Button.new()
	button.text = label
	button.disabled = not enabled
	if not enabled: button.tooltip_text = "Requires propulsion and at least 10 m/s of delta-v."
	button.pressed.connect(func():
		if _outcome: closed.emit()
		else: choice_selected.emit(choice)
	)
	_body.add_child(button)

func show_outcome(message: String) -> void:
	_outcome = true
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)
	_add_button("Continue", "done", true)
