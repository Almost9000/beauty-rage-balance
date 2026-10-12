extends GutTest

var shower_scene: PackedScene


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	InventoryManager.reset_state()
	shower_scene = load("res://features/prep/shower.tscn") as PackedScene


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	InventoryManager.reset_state()


func test_shower_action_advances_time_and_boosts_stats() -> void:
	var shower: Shower = shower_scene.instantiate() as Shower
	add_child_autoqfree(shower)

	# Set lower hygiene and sanity so increases don't hit max clamp
	StatusManager.set_value(Enums.Stat.HYGIENE, 30.0)
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)

	var start_min: int = GameClock.now_minutes
	var start_hygiene: float = StatusManager.get_value(Enums.Stat.HYGIENE)
	var start_sanity: float = StatusManager.get_value(Enums.Stat.SANITY)

	# Execute shower action without UI
	shower.execute_action()

	# Note: GameClock.skip(15) also simulates decay during those 15 minutes!
	# Hygiene base decay is -2.0/h -> in 15 min it decays ~0.5.
	# With +40 instant boost, net hygiene should be around start_hygiene + 39.5.
	var end_min: int = GameClock.now_minutes
	var end_hygiene: float = StatusManager.get_value(Enums.Stat.HYGIENE)
	var end_sanity: float = StatusManager.get_value(Enums.Stat.SANITY)

	assert_eq(end_min - start_min, 15, "Game clock jumped exactly 15 minutes")
	assert_gt(end_hygiene, start_hygiene + 35.0, "Hygiene significantly increased")
	assert_gt(end_sanity, start_sanity + 5.0, "Sanity increased")


func test_shower_custom_duration_and_effects() -> void:
	var shower: Shower = shower_scene.instantiate() as Shower
	shower.duration_min = 30
	shower.effects.clear()

	var custom_mod := StatModifier.new()
	custom_mod.stat = Enums.Stat.HYGIENE
	custom_mod.kind = Enums.ModifierKind.INSTANT
	custom_mod.value = 50.0
	custom_mod.source_id = &"prep_shower_custom"
	shower.effects.append(custom_mod)

	add_child_autoqfree(shower)

	StatusManager.set_value(Enums.Stat.HYGIENE, 20.0)
	var start_min: int = GameClock.now_minutes
	var start_hygiene: float = StatusManager.get_value(Enums.Stat.HYGIENE)

	shower.execute_action()

	assert_eq(GameClock.now_minutes - start_min, 30, "Clock skipped custom 30 min")
	assert_gt(StatusManager.get_value(Enums.Stat.HYGIENE), start_hygiene + 45.0, "Custom effect applied")


func test_shower_clears_makeup_look() -> void:
	var shower: Shower = shower_scene.instantiate() as Shower
	add_child_autoqfree(shower)

	var look := MakeupLook.new()
	look.id = &"test_look"
	InventoryManager.set_look(look)
	assert_not_null(InventoryManager.current_look, "Makeup look is active before shower")

	shower.execute_action()

	assert_null(InventoryManager.current_look, "Shower cleared the makeup look")
