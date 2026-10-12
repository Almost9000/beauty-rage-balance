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
	_setup_outfit_section()
	_setup_makeup_section()
	_setup_outings_section()
	_setup_cleaning_section()
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
		_sync_makeup_sliders_from_look()

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

		if _capture_frame == 8:
			if OS.get_environment("BRB_EQUIP_DRESS") == "1":
				var inv: Node = get_node_or_null("/root/InventoryManager")
				if inv and inv.has_method("equip"):
					var dress_res: Resource = load("res://data/clothing/dress/dress_peasant_ensemble.tres")
					if dress_res:
						inv.call("equip", dress_res)

		if _capture_frame == 12:
			if OS.get_environment("BRB_WALK_ANIM") == "1":
				var player: Node = get_tree().root.find_child("Player", true, false)
				if player and player.get("avatar"):
					var av: Node = player.get("avatar")
					if av and av.get("animation_player"):
						var ap: AnimationPlayer = av.get("animation_player") as AnimationPlayer
						if ap:
							ap.play("Walk")
							ap.seek(0.6, true)

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

func _setup_outfit_section() -> void:
	var outfit_section: Container = add_section("Outfit")
	add_watch(outfit_section, "Top", _get_debug_equipped_top)
	add_watch(outfit_section, "Bottom", _get_debug_equipped_bottom)
	add_watch(outfit_section, "Dress", _get_debug_equipped_dress)
	add_watch(outfit_section, "Shoes", _get_debug_equipped_shoes)

	add_button(outfit_section, "Equip: Peasant Tunic (Top)", _on_equip_top_pressed)
	add_button(outfit_section, "Equip: Peasant Skirt (Bottom)", _on_equip_bottom_pressed)
	add_button(outfit_section, "Equip: Peasant Boots (Shoes)", _on_equip_shoes_pressed)
	add_button(outfit_section, "Equip: Peasant Ensemble (Dress)", _on_equip_dress_pressed)
	add_button(outfit_section, "Unequip All", _on_unequip_all_pressed)
	add_button(outfit_section, "Reset Starting Outfit", _on_reset_outfit_pressed)

func _get_inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")

func _get_debug_equipped_top() -> String:
	return _get_debug_slot_name(Enums.Slot.TOP)

func _get_debug_equipped_bottom() -> String:
	return _get_debug_slot_name(Enums.Slot.BOTTOM)

func _get_debug_equipped_dress() -> String:
	return _get_debug_slot_name(Enums.Slot.DRESS)

func _get_debug_equipped_shoes() -> String:
	return _get_debug_slot_name(Enums.Slot.SHOES)

func _get_debug_slot_name(slot: Enums.Slot) -> String:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("get_equipped"):
		var item: ClothingItem = inv.call("get_equipped", slot) as ClothingItem
		if item:
			return item.display_name
	return "(none)"

func _on_equip_top_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("equip"):
		var item: ClothingItem = load("res://data/clothing/top/top_peasant_tunic.tres") as ClothingItem
		if item:
			inv.call("equip", item)

func _on_equip_bottom_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("equip"):
		var item: ClothingItem = load("res://data/clothing/bottom/bottom_peasant_skirt.tres") as ClothingItem
		if item:
			inv.call("equip", item)

func _on_equip_shoes_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("equip"):
		var item: ClothingItem = load("res://data/clothing/shoes/shoes_peasant_boots.tres") as ClothingItem
		if item:
			inv.call("equip", item)

func _on_equip_dress_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("equip"):
		var item: ClothingItem = load("res://data/clothing/dress/dress_peasant_ensemble.tres") as ClothingItem
		if item:
			inv.call("equip", item)

func _on_unequip_all_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("unequip"):
		for slot in Enums.Slot.values():
			inv.call("unequip", slot)

func _on_reset_outfit_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("reset_state"):
		inv.call("reset_state")

var _makeup_sliders: Dictionary = {}
var _makeup_slider_labels: Dictionary = {}

func _setup_makeup_section() -> void:
	var makeup_section: Container = add_section("Makeup")
	add_watch(makeup_section, "Current Look", func() -> String:
		var inv: Node = _get_inventory_manager()
		if inv and "current_look" in inv and inv.current_look != null:
			var look: MakeupLook = inv.current_look as MakeupLook
			var name_str: String = look.display_name if not look.display_name.is_empty() else String(look.id)
			return "%s (score: %.2f)" % [name_str, look.score()]
		return "(none)"
	)

	add_button(makeup_section, "Apply Natural Look", _on_apply_natural_look_pressed)
	add_button(makeup_section, "Apply Glam Look", _on_apply_glam_look_pressed)
	add_button(makeup_section, "Clear Look", _on_clear_look_pressed)

	_setup_makeup_slider(makeup_section, "Base Opacity", Enums.MakeupLayer.BASE)
	_setup_makeup_slider(makeup_section, "Blush Opacity", Enums.MakeupLayer.BLUSH)
	_setup_makeup_slider(makeup_section, "Eyeshadow Opacity", Enums.MakeupLayer.EYESHADOW)
	_setup_makeup_slider(makeup_section, "Eyeliner Opacity", Enums.MakeupLayer.EYELINER)
	_setup_makeup_slider(makeup_section, "Lipstick Opacity", Enums.MakeupLayer.LIPSTICK)

func _setup_makeup_slider(parent: Container, label_title: String, layer: Enums.MakeupLayer) -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = "%s: 0.00" % label_title
	vbox.add_child(lbl)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.0
	slider.value_changed.connect(func(val: float) -> void:
		lbl.text = "%s: %.2f" % [label_title, val]
		_on_makeup_slider_changed(layer, val)
	)
	vbox.add_child(slider)
	parent.add_child(vbox)

	_makeup_sliders[layer] = slider
	_makeup_slider_labels[layer] = { "label": lbl, "title": label_title }

func _on_makeup_slider_changed(layer: Enums.MakeupLayer, val: float) -> void:
	var inv: Node = _get_inventory_manager()
	if inv and "current_look" in inv and inv.current_look != null:
		var look: MakeupLook = inv.current_look as MakeupLook
		if look.has_layer(layer):
			look.get_layer(layer)["opacity"] = val
		elif look.layers.has(int(layer)):
			look.layers[int(layer)]["opacity"] = val

	var tree: SceneTree = get_tree()
	if tree:
		var avatar: Node = tree.root.find_child("Avatar", true, false)
		if avatar:
			var fm: FaceMakeup = avatar.find_child("FaceMakeup", true, false) as FaceMakeup
			if fm:
				fm.set_layer_opacity(layer, val)

func _sync_makeup_sliders_from_look() -> void:
	var inv: Node = _get_inventory_manager()
	var look: MakeupLook = inv.current_look if (inv and "current_look" in inv) else null
	for layer_variant: Variant in _makeup_sliders.keys():
		var layer: Enums.MakeupLayer = layer_variant as Enums.MakeupLayer
		var slider: HSlider = _makeup_sliders[layer]
		var info: Dictionary = _makeup_slider_labels[layer]
		var lbl: Label = info["label"]
		var title: String = info["title"]
		var val: float = 0.0
		if look != null and look.has_layer(layer):
			val = float(look.get_layer(layer).get("opacity", 0.0))
		slider.set_value_no_signal(val)
		lbl.text = "%s: %.2f" % [title, val]

func _on_apply_natural_look_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("set_look"):
		var look: MakeupLook = load("res://data/looks/natural.tres") as MakeupLook
		if look:
			inv.call("set_look", look.duplicate())
			_sync_makeup_sliders_from_look()

func _on_apply_glam_look_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("set_look"):
		var look: MakeupLook = load("res://data/looks/glam.tres") as MakeupLook
		if look:
			inv.call("set_look", look.duplicate())
			_sync_makeup_sliders_from_look()

func _on_clear_look_pressed() -> void:
	var inv: Node = _get_inventory_manager()
	if inv and inv.has_method("clear_look"):
		inv.call("clear_look")
		_sync_makeup_sliders_from_look()


func _setup_outings_section() -> void:
	var section: Container = add_section("Outings")

	add_button(section, "Schedule Girls' Day Out (+2h)", _on_schedule_girls_day_out_pressed)
	add_button(section, "Schedule Date Night (+2h)", _on_schedule_date_night_pressed)
	add_button(section, "Skip to Prep Start", _on_skip_to_prep_start_pressed)
	add_button(section, "Skip to Departure", _on_skip_to_departure_pressed)
	add_button(section, "Depart Outing Now", _on_depart_outing_pressed)
	add_button(section, "Skip Past Grace End (+40m)", _on_skip_past_grace_pressed)

	add_watch(section, "Active Outing", func() -> String:
		var om: Node = get_node_or_null("/root/OutingManager")
		if om and om.get("active_outing") != null:
			var out: OutingData = om.get("active_outing") as OutingData
			return out.display_name if out else "None"
		return "None"
	)

	add_watch(section, "Prep Active", func() -> String:
		var om: Node = get_node_or_null("/root/OutingManager")
		if om and bool(om.call("is_prep_active")):
			return "Yes"
		return "No"
	)

	add_watch(section, "Countdown to Departure", func() -> String:
		var clock: Node = get_node_or_null("/root/GameClock")
		if clock and bool(clock.call("has_countdown", &"outing_departure_deadline")):
			var rem: int = int(clock.call("remaining", &"outing_departure_deadline"))
			return "%02d:%02d (%d min)" % [rem / 60, rem % 60, rem]
		return "--"
	)

	add_watch(section, "Evaluation", func() -> String:
		var om: Node = get_node_or_null("/root/OutingManager")
		if om and bool(om.call("is_prep_active")):
			var ev: Dictionary = om.call("evaluate")
			var res_str: String = "FAIL"
			match ev.get("result", Enums.OutingResult.FAIL):
				Enums.OutingResult.PASS: res_str = "PASS"
				Enums.OutingResult.PARTIAL: res_str = "PARTIAL"
				Enums.OutingResult.FAIL: res_str = "FAIL"
			return "Score: %d%% (%s) | Late: %d min" % [int(round(float(ev.get("score", 0.0)) * 100.0)), res_str, int(ev.get("lateness_min", 0))]
		return "--"
	)

	add_watch(section, "Checklist State", func() -> String:
		var om: Node = get_node_or_null("/root/OutingManager")
		if om and bool(om.call("is_prep_active")):
			var items: Array[Dictionary] = om.call("get_checklist")
			if items.is_empty():
				return "No checks"
			var lines: PackedStringArray = []
			for it: Dictionary in items:
				var status: String = "[PASS]" if bool(it.get("passed", false)) else "[FAIL]"
				lines.append("%s %s: %d%%" % [status, it.get("label", ""), int(round(float(it.get("score", 0.0)) * 100.0))])
			return "\n" + "\n".join(lines)
		return "No active prep"
	)


func _on_schedule_girls_day_out_pressed() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	var clock: Node = get_node_or_null("/root/GameClock")
	if om and clock:
		var outing: OutingData = load("res://data/outings/girls_day_out.tres") as OutingData
		if outing:
			var dep: int = int(clock.get("now_minutes")) + 120
			om.call("schedule", outing, dep, "Chloe")
			_refresh_watches()


func _on_schedule_date_night_pressed() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	var clock: Node = get_node_or_null("/root/GameClock")
	if om and clock:
		var outing: OutingData = load("res://data/outings/date_night.tres") as OutingData
		if outing:
			var dep: int = int(clock.get("now_minutes")) + 120
			om.call("schedule", outing, dep, "Liam")
			_refresh_watches()


func _on_skip_to_prep_start_pressed() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	var clock: Node = get_node_or_null("/root/GameClock")
	if om and clock:
		var scheduled: Array = om.call("get_scheduled")
		for entry_val: Variant in scheduled:
			if entry_val is Dictionary:
				var entry: Dictionary = entry_val as Dictionary
				if not bool(entry.get("prep_started", false)):
					var out: OutingData = entry.get("outing") as OutingData
					var dep: int = int(entry.get("departure_min", 0))
					var prep_start: int = dep - out.prep_window_min
					var now_m: int = int(clock.get("now_minutes"))
					if prep_start > now_m:
						clock.call("skip", prep_start - now_m)
						_refresh_watches()
						return


func _on_skip_to_departure_pressed() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	var clock: Node = get_node_or_null("/root/GameClock")
	if om and clock:
		var dep: int = int(om.get("active_departure_min"))
		var now_m: int = int(clock.get("now_minutes"))
		if dep > now_m:
			clock.call("skip", dep - now_m)
			_refresh_watches()


func _on_depart_outing_pressed() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	if om and bool(om.call("is_prep_active")):
		om.call("depart")
		_refresh_watches()


func _on_skip_past_grace_pressed() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	var clock: Node = get_node_or_null("/root/GameClock")
	if om and clock and bool(om.call("is_prep_active")):
		var dep: int = int(om.get("active_departure_min"))
		var out: OutingData = om.get("active_outing") as OutingData
		var grace: int = out.late_grace_min if out else 30
		var grace_end: int = dep + grace
		var now_m: int = int(clock.get("now_minutes"))
		if grace_end >= now_m:
			clock.call("skip", (grace_end - now_m) + 1)
		_refresh_watches()


func _setup_cleaning_section() -> void:
	var section: Container = add_section("Cleaning")
	add_watch(section, "Clutter Count", _get_debug_clutter_count)
	add_watch(section, "Comfort Score", _get_debug_comfort_score)
	add_button(section, "Spawn 5 Clutter", _on_spawn_5_clutter_pressed)
	add_button(section, "Clear All Clutter", _on_clear_all_clutter_pressed)

func _get_debug_clutter_count() -> String:
	var count: int = 0
	var tree: SceneTree = get_tree()
	if tree:
		for node: Node in tree.get_nodes_in_group(&"clutter"):
			if node is Node3D and not node.is_queued_for_deletion():
				count += 1
	return str(count)

func _get_debug_comfort_score() -> String:
	var tree: SceneTree = get_tree()
	if tree:
		var comfort_nodes: Array[Node] = tree.get_nodes_in_group(&"comfort_score")
		if not comfort_nodes.is_empty():
			var cs: Node = comfort_nodes[0]
			if "current_comfort" in cs:
				var c_val: float = float(cs.current_comfort)
				var r_val: float = 0.0
				if cs.has_method("get_current_rate"):
					r_val = float(cs.call("get_current_rate"))
				return "%.2f (rate: %+.2f/h)" % [c_val, r_val]
	return "--"

func _on_spawn_5_clutter_pressed() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var spawners: Array[Node] = tree.get_nodes_in_group(&"clutter_spawner")
	if spawners.is_empty():
		return
	var spawner: Node = spawners[0]
	if spawner and spawner.has_method("spawn"):
		for _i in range(5):
			spawner.call("spawn")
	_refresh_watches()

func _on_clear_all_clutter_pressed() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	for node: Node in tree.get_nodes_in_group(&"clutter"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_refresh_watches()


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
