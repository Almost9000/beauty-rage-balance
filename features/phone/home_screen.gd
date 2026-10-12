class_name HomeScreen
extends Control

signal app_selected(app_id: StringName)

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var time_label: Label = $MarginContainer/VBoxContainer/ClockWidget/TimeLabel
@onready var date_label: Label = $MarginContainer/VBoxContainer/ClockWidget/DateLabel

var _buttons: Array[Button] = []


func _ready() -> void:
	_update_clock_widget()
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("minute_ticked"):
		if not clock.minute_ticked.is_connected(_on_minute_ticked):
			clock.minute_ticked.connect(_on_minute_ticked)


func _on_minute_ticked(_minute: int) -> void:
	_update_clock_widget()


func _update_clock_widget() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if time_label:
		if clock and clock.has_method("format_time"):
			time_label.text = str(clock.call("format_time"))
		else:
			time_label.text = "07:00"
	if date_label:
		if clock:
			var day_num: int = int(clock.get("day"))
			date_label.text = "Day %d" % day_num
		else:
			date_label.text = "Day 1"


func populate_apps(apps: Array[AppBase]) -> void:
	_buttons.clear()
	if not grid_container:
		return

	for child: Node in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

	for app: AppBase in apps:
		if app == null:
			continue
		var btn: Button = _create_app_button(app)
		grid_container.add_child(btn)
		_buttons.append(btn)


func _create_app_button(app: AppBase) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(74, 88)
	btn.focus_mode = Control.FOCUS_ALL
	btn.flat = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(52, 52)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.2, 0.24, 0.35, 0.95)
	icon_style.set_corner_radius_all(14)
	icon_style.border_width_left = 1
	icon_style.border_width_top = 1
	icon_style.border_width_right = 1
	icon_style.border_width_bottom = 1
	icon_style.border_color = Color(0.4, 0.48, 0.68, 0.8)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	if app.icon != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = app.icon
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(36, 36)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(tex_rect)
	else:
		# Text initials / abbreviation placeholder
		var init_label := Label.new()
		var init_text: String = app.display_name.substr(0, 3).to_upper()
		init_label.text = init_text
		init_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		init_label.add_theme_font_size_override("font_size", 14)
		init_label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
		init_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		init_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(init_label)

	vbox.add_child(icon_panel)

	var name_label := Label.new()
	name_label.text = app.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	btn.add_child(vbox)

	var app_id: StringName = app.app_id
	btn.pressed.connect(func() -> void:
		app_selected.emit(app_id)
	)

	return btn


func get_app_buttons() -> Array[Button]:
	return _buttons.duplicate()
