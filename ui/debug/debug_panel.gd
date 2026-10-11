extends CanvasLayer

const WATCH_INTERVAL: float = 0.25

var _watches: Array[Dictionary] = []
var _watch_timer: float = 0.0

@onready var _panel_root: Control = $PanelRoot
@onready var _sections_container: VBoxContainer = $PanelRoot/MarginContainer/VBoxContainer/ScrollContainer/SectionsContainer

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	if not InputMap.has_action("debug_toggle"):
		InputMap.add_action("debug_toggle")
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = KEY_F3
		InputMap.action_add_event("debug_toggle", event)

	_panel_root.visible = false
	_setup_world_section()
	_setup_time_section()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle_panel()
		get_viewport().set_input_as_handled()

func toggle_panel() -> void:
	_panel_root.visible = not _panel_root.visible
	if _panel_root.visible:
		_refresh_watches()

func _process(delta: float) -> void:
	if not _panel_root.visible:
		return

	_watch_timer += delta
	if _watch_timer >= WATCH_INTERVAL:
		_watch_timer = 0.0
		_refresh_watches()

func _setup_world_section() -> void:
	var world_section: Container = add_section("World")
	add_button(world_section, "Reload Level", _on_reload_level_pressed)
	add_button(world_section, "Go to Apartment", _on_go_to_apartment_pressed)
	add_watch(world_section, "Current Level", _get_current_level_id)

func _on_reload_level_pressed() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene and not current_scene.scene_file_path.is_empty():
		var scene_router: Node = get_node_or_null("/root/SceneRouter")
		if scene_router and scene_router.has_method("change_level"):
			scene_router.change_level(current_scene.scene_file_path)

func _on_go_to_apartment_pressed() -> void:
	var scene_router: Node = get_node_or_null("/root/SceneRouter")
	if scene_router and scene_router.has_method("change_level"):
		scene_router.change_level("res://levels/apartment/apartment.tscn")

func _get_current_level_id() -> String:
	var scene_router: Node = get_node_or_null("/root/SceneRouter")
	if scene_router:
		return str(scene_router.get("current_level_id"))
	return ""

func _setup_time_section() -> void:
	var time_section: Container = add_section("Time")
	add_watch(time_section, "Day / Time", _get_debug_time_string)
	add_watch(time_section, "Paused", _get_debug_paused_string)
	add_watch(time_section, "Time Scale", _get_debug_scale_string)
	add_button(time_section, "+1 h (Skip)", _on_skip_one_hour_pressed)
	add_button(time_section, "+1 d (Skip)", _on_skip_one_day_pressed)
	add_button(time_section, "Pause / Resume", _on_toggle_pause_pressed)
	add_button(time_section, "Scale x1", func() -> void: _set_time_scale(1.0))
	add_button(time_section, "Scale x10", func() -> void: _set_time_scale(10.0))
	add_button(time_section, "Scale x60", func() -> void: _set_time_scale(60.0))

func _get_game_clock() -> Node:
	return get_node_or_null("/root/GameClock")

func _get_debug_time_string() -> String:
	var clock: Node = _get_game_clock()
	if clock:
		return "Day %d, %s (%d m)" % [int(clock.get("day")), str(clock.call("format_time")), int(clock.get("now_minutes"))]
	return "--"

func _get_debug_paused_string() -> String:
	var clock: Node = _get_game_clock()
	if clock and clock.has_method("is_paused"):
		return "Yes" if clock.is_paused() else "No"
	return "--"

func _get_debug_scale_string() -> String:
	var clock: Node = _get_game_clock()
	if clock:
		return "%.1fx" % float(clock.get("time_scale"))
	return "--"

func _on_skip_one_hour_pressed() -> void:
	var clock: Node = _get_game_clock()
	if clock and clock.has_method("skip"):
		clock.skip(60)

func _on_skip_one_day_pressed() -> void:
	var clock: Node = _get_game_clock()
	if clock and clock.has_method("skip"):
		clock.skip(1440)

func _on_toggle_pause_pressed() -> void:
	var clock: Node = _get_game_clock()
	if clock and clock.has_method("has_pause_reason"):
		if clock.has_pause_reason(&"debug"):
			clock.resume(&"debug")
		else:
			clock.pause(&"debug")

func _set_time_scale(scale: float) -> void:
	var clock: Node = _get_game_clock()
	if clock:
		clock.set("time_scale", scale)

func add_section(title: String) -> Container:
	var section_panel: VBoxContainer = VBoxContainer.new()
	section_panel.name = title.validate_node_name()

	var title_label: Label = Label.new()
	title_label.text = "=== " + title + " ==="
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_panel.add_child(title_label)

	var items_container: VBoxContainer = VBoxContainer.new()
	items_container.name = "Items"
	section_panel.add_child(items_container)

	var separator: HSeparator = HSeparator.new()
	section_panel.add_child(separator)

	_sections_container.add_child(section_panel)
	return items_container

func add_button(section: Container, label: String, callable: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.pressed.connect(callable)
	section.add_child(btn)
	return btn

func add_watch(section: Container, label: String, callable: Callable) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()

	var name_label: Label = Label.new()
	name_label.text = label + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.text = "--"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(value_label)

	section.add_child(hbox)

	_watches.append({
		"callable": callable,
		"value_label": value_label,
	})

	if _panel_root.visible:
		_update_watch_entry(_watches.size() - 1)

func _refresh_watches() -> void:
	for i: int in range(_watches.size() - 1, -1, -1):
		var entry: Dictionary = _watches[i]
		var val_label: Label = entry.get("value_label") as Label
		var callable: Callable = entry.get("callable") as Callable
		if not is_instance_valid(val_label):
			_watches.remove_at(i)
			continue
		if callable.is_valid():
			var val: Variant = callable.call()
			val_label.text = str(val)

func _update_watch_entry(idx: int) -> void:
	if idx < 0 or idx >= _watches.size():
		return
	var entry: Dictionary = _watches[idx]
	var val_label: Label = entry.get("value_label") as Label
	var callable: Callable = entry.get("callable") as Callable
	if is_instance_valid(val_label) and callable.is_valid():
		val_label.text = str(callable.call())

func _on_close_button_pressed() -> void:
	toggle_panel()
