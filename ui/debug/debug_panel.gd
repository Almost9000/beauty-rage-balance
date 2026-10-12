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
	_setup_stats_section()
	_setup_cycle_section()
	_setup_money_section()
	_capture_path = OS.get_environment("BRB_CAPTURE_SCREENSHOT")

var _capture_path: String = ""
var _capture_frame: int = 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle_panel()
		get_viewport().set_input_as_handled()

func toggle_panel() -> void:
	_panel_root.visible = not _panel_root.visible
	if _panel_root.visible:
		_refresh_watches()

func _process(delta: float) -> void:
	if not _capture_path.is_empty():
		var router: Node = get_node_or_null("/root/SceneRouter")
		if router and bool(router.get("_is_transitioning")):
			return

		_capture_frame += 1
		if _capture_frame == 1:
			var res_env: String = OS.get_environment("BRB_RESOLUTION")
			if not res_env.is_empty():
				var parts: PackedStringArray = res_env.split("x")
				if parts.size() == 2:
					var target_size: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
					DisplayServer.window_set_size(target_size)
					get_viewport().size = target_size

		if _capture_frame == 5:
			if OS.get_environment("BRB_EXPAND_MODIFIERS") == "1":
				var hud: Node = get_tree().root.find_child("HUD", true, false)
				if hud and hud.has_method("set_modifiers_expanded"):
					hud.call("set_modifiers_expanded", true)

		if _capture_frame >= 20:
			var vp: Viewport = get_viewport()
			if vp:
				var img: Image = vp.get_texture().get_image()
				if img and not img.is_empty():
					img.save_png(_capture_path)
					print("Saved automated screenshot to: ", _capture_path, " size: ", img.get_size())
			_capture_path = ""
			get_tree().quit()
			return

	if not _panel_root.visible:
		return

	_watch_timer += delta
	if _watch_timer >= WATCH_INTERVAL:
		_watch_timer = 0.0
		_refresh_watches()

var _camera_focus_button: Button = null
var _camera_focused_vanity: bool = false

func _setup_world_section() -> void:
	var world_section: Container = add_section("World")
	add_button(world_section, "Reload Level", _on_reload_level_pressed)
	add_button(world_section, "Go to Apartment", _on_go_to_apartment_pressed)
	add_watch(world_section, "Current Level", _get_current_level_id)
	_camera_focus_button = add_button(world_section, "Camera: focus vanity marker", _on_toggle_camera_focus_vanity_pressed)

func _on_toggle_camera_focus_vanity_pressed() -> void:
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return

	var camera_rig: Node = current_scene.find_child("CameraRig", true, false)
	if not camera_rig:
		push_warning("DebugPanel: CameraRig not found in current scene")
		return

	var vanity_marker: Node3D = current_scene.find_child("vanity", true, false) as Node3D
	if not vanity_marker:
		push_warning("DebugPanel: Station marker 'vanity' not found")
		return

	if not _camera_focused_vanity:
		if camera_rig.has_method("focus"):
			camera_rig.call("focus", vanity_marker, 0.4)
			_camera_focused_vanity = true
			if _camera_focus_button:
				_camera_focus_button.text = "Camera: release vanity marker"
	else:
		if camera_rig.has_method("release"):
			camera_rig.call("release", 0.4)
			_camera_focused_vanity = false
			if _camera_focus_button:
				_camera_focus_button.text = "Camera: focus vanity marker"

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
	add_button(time_section, "+7 d (Skip)", _on_skip_seven_days_pressed)
	add_button(time_section, "+28 d (Skip)", _on_skip_twenty_eight_days_pressed)
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

func _on_skip_seven_days_pressed() -> void:
	var clock: Node = _get_game_clock()
	if clock and clock.has_method("skip"):
		clock.skip(7 * 1440)

func _on_skip_twenty_eight_days_pressed() -> void:
	var clock: Node = _get_game_clock()
	if clock and clock.has_method("skip"):
		clock.skip(28 * 1440)

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

func _setup_stats_section() -> void:
	var stats_section: Container = add_section("Stats")
	add_watch(stats_section, "Sanity", func() -> String: return _get_stat_watch_string(Enums.Stat.SANITY))
	add_watch(stats_section, "Health", func() -> String: return _get_stat_watch_string(Enums.Stat.HEALTH))
	add_watch(stats_section, "Hygiene", func() -> String: return _get_stat_watch_string(Enums.Stat.HYGIENE))
	add_watch(stats_section, "Rage", func() -> String: return _get_stat_watch_string(Enums.Stat.RAGE))
	add_button(stats_section, "Sanity = 50", func() -> void: _set_debug_stat(Enums.Stat.SANITY, 50.0))
	add_button(stats_section, "Health = 50", func() -> void: _set_debug_stat(Enums.Stat.HEALTH, 50.0))
	add_button(stats_section, "Hygiene = 50", func() -> void: _set_debug_stat(Enums.Stat.HYGIENE, 50.0))
	add_button(stats_section, "Rage = 50", func() -> void: _set_debug_stat(Enums.Stat.RAGE, 50.0))
	add_button(stats_section, "Sanity = 100", func() -> void: _set_debug_stat(Enums.Stat.SANITY, 100.0))
	add_button(stats_section, "Health = 100", func() -> void: _set_debug_stat(Enums.Stat.HEALTH, 100.0))
	add_button(stats_section, "Hygiene = 100", func() -> void: _set_debug_stat(Enums.Stat.HYGIENE, 100.0))
	add_button(stats_section, "Rage = 0", func() -> void: _set_debug_stat(Enums.Stat.RAGE, 0.0))
	add_button(stats_section, "Rage = 100", func() -> void: _set_debug_stat(Enums.Stat.RAGE, 100.0))
	add_button(stats_section, "Add Test +5/h (Sanity)", _on_add_test_pos_mod_pressed)
	add_button(stats_section, "Add Test -5/h (Sanity)", _on_add_test_neg_mod_pressed)
	add_button(stats_section, "Clear Test Modifiers", _on_clear_test_mods_pressed)

func _get_status_manager() -> Node:
	return get_node_or_null("/root/StatusManager")

func _get_stat_watch_string(stat: Enums.Stat) -> String:
	var sm: Node = _get_status_manager()
	if sm and sm.has_method("get_value") and sm.has_method("get_effective_rate") and sm.has_method("get_max"):
		var val: float = float(sm.call("get_value", stat))
		var max_val: float = float(sm.call("get_max", stat))
		var rate: float = float(sm.call("get_effective_rate", stat))
		return "%.1f / %.1f (%+.2f/h)" % [val, max_val, rate]
	return "--"

func _set_debug_stat(stat: Enums.Stat, val: float) -> void:
	var sm: Node = _get_status_manager()
	if sm and sm.has_method("set_value"):
		sm.call("set_value", stat, val)

func _on_add_test_pos_mod_pressed() -> void:
	var sm: Node = _get_status_manager()
	if sm and sm.has_method("add_modifier"):
		var mod: StatModifier = StatModifier.new()
		mod.stat = Enums.Stat.SANITY
		mod.kind = Enums.ModifierKind.RATE_ADD
		mod.value = 5.0
		mod.source_id = &"debug_test_pos"
		mod.duration_min = 60
		mod.label = "Debug +5/h"
		sm.call("add_modifier", mod)

func _on_add_test_neg_mod_pressed() -> void:
	var sm: Node = _get_status_manager()
	if sm and sm.has_method("add_modifier"):
		var mod: StatModifier = StatModifier.new()
		mod.stat = Enums.Stat.SANITY
		mod.kind = Enums.ModifierKind.RATE_ADD
		mod.value = -5.0
		mod.source_id = &"debug_test_neg"
		mod.duration_min = 60
		mod.label = "Debug -5/h"
		sm.call("add_modifier", mod)

func _on_clear_test_mods_pressed() -> void:
	var sm: Node = _get_status_manager()
	if sm and sm.has_method("remove_by_source"):
		sm.call("remove_by_source", &"debug_test")
		sm.call("remove_by_source", &"debug_test_pos")
		sm.call("remove_by_source", &"debug_test_neg")

func _setup_cycle_section() -> void:
	var cycle_section: Container = add_section("Cycle")
	add_watch(cycle_section, "Phase", _get_debug_cycle_phase_string)
	add_watch(cycle_section, "Day in Phase", _get_debug_cycle_day_string)
	add_watch(cycle_section, "Cycle Length", _get_debug_cycle_length_string)
	add_watch(cycle_section, "Intensity", _get_debug_cycle_intensity_string)
	add_button(cycle_section, "Force Menstrual", func() -> void: _force_debug_phase(Enums.CyclePhase.MENSTRUAL))
	add_button(cycle_section, "Force Follicular", func() -> void: _force_debug_phase(Enums.CyclePhase.FOLLICULAR))
	add_button(cycle_section, "Force Ovulatory", func() -> void: _force_debug_phase(Enums.CyclePhase.OVULATORY))
	add_button(cycle_section, "Force Luteal", func() -> void: _force_debug_phase(Enums.CyclePhase.LUTEAL))
	add_button(cycle_section, "Intensity 0.0", func() -> void: _set_debug_intensity(0.0))
	add_button(cycle_section, "Intensity 0.5", func() -> void: _set_debug_intensity(0.5))
	add_button(cycle_section, "Intensity 1.0", func() -> void: _set_debug_intensity(1.0))
	add_button(cycle_section, "Cycle Length 28d", func() -> void: _set_debug_cycle_length(28))
	add_button(cycle_section, "Cycle Length 12d", func() -> void: _set_debug_cycle_length(12))

func _get_cycle_manager() -> Node:
	return get_node_or_null("/root/CycleManager")

func _get_debug_cycle_phase_string() -> String:
	var cm: Node = _get_cycle_manager()
	if cm:
		var p_val: Variant = cm.get("current_phase")
		if p_val != null:
			var phase_key: Variant = Enums.CyclePhase.find_key(int(p_val))
			return str(phase_key) if phase_key != null else str(p_val)
	return "--"

func _get_debug_cycle_day_string() -> String:
	var cm: Node = _get_cycle_manager()
	if cm:
		var dip: int = int(cm.get("day_in_phase"))
		var dun: int = int(cm.get("days_until_next_phase"))
		return "Day %d (next in %d d)" % [dip, dun]
	return "--"

func _get_debug_cycle_length_string() -> String:
	return "%d days" % GameSettings.current().cycle_length_days

func _get_debug_cycle_intensity_string() -> String:
	return "%.1f" % GameSettings.current().symptom_intensity

func _force_debug_phase(phase: Enums.CyclePhase) -> void:
	var cm: Node = _get_cycle_manager()
	if cm and cm.has_method("force_phase"):
		cm.call("force_phase", phase)

func _set_debug_intensity(val: float) -> void:
	GameSettings.current().symptom_intensity = val

func _set_debug_cycle_length(days: int) -> void:
	GameSettings.current().cycle_length_days = days

func _setup_money_section() -> void:
	var money_section: Container = add_section("Money")
	add_watch(money_section, "Wallet", _get_debug_wallet_string)
	add_button(money_section, "+€100", _on_add_100_pressed)
	add_button(money_section, "−€100 (Bill)", _on_sub_100_bill_pressed)
	add_button(money_section, "+€500", _on_add_500_pressed)
	add_button(money_section, "−€500 (Bill)", _on_sub_500_bill_pressed)
	add_button(money_section, "Charge Rent Now", _on_charge_rent_pressed)

func _get_finance_manager() -> Node:
	return get_node_or_null("/root/FinanceManager")

func _get_debug_wallet_string() -> String:
	var fm: Node = _get_finance_manager()
	if fm:
		var c_val: Variant = fm.get("wallet_cents")
		if c_val != null:
			return Money.format(int(c_val))
	return "--"

func _on_add_100_pressed() -> void:
	var fm: Node = _get_finance_manager()
	if fm and fm.has_method("earn"):
		fm.call("earn", 10000, &"debug", "Debug +€100")

func _on_sub_100_bill_pressed() -> void:
	var fm: Node = _get_finance_manager()
	if fm and fm.has_method("charge_bill"):
		fm.call("charge_bill", 10000, &"debug", "Debug −€100")

func _on_add_500_pressed() -> void:
	var fm: Node = _get_finance_manager()
	if fm and fm.has_method("earn"):
		fm.call("earn", 50000, &"debug", "Debug +€500")

func _on_sub_500_bill_pressed() -> void:
	var fm: Node = _get_finance_manager()
	if fm and fm.has_method("charge_bill"):
		fm.call("charge_bill", 50000, &"debug", "Debug −€500")

func _on_charge_rent_pressed() -> void:
	var fm: Node = _get_finance_manager()
	if fm and fm.has_method("charge_rent"):
		fm.call("charge_rent")

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
