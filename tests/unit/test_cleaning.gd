extends GutTest

const APARTMENT_SCENE_PATH := "res://levels/apartment/apartment.tscn"

func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	SceneRouter.reset_state()

func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	SceneRouter.reset_state()

func test_comfort_formula_static() -> void:
	# compute_comfort(total_weight, tolerance)
	assert_almost_eq(ComfortScore.compute_comfort(0.0, 8.0), 1.0, 1e-4, "0 weight -> 1.0 comfort")
	assert_almost_eq(ComfortScore.compute_comfort(4.0, 8.0), 0.5, 1e-4, "Half tolerance -> 0.5 comfort")
	assert_almost_eq(ComfortScore.compute_comfort(8.0, 8.0), 0.0, 1e-4, "At tolerance -> 0.0 comfort")
	assert_almost_eq(ComfortScore.compute_comfort(12.0, 8.0), 0.0, 1e-4, "Above tolerance -> clamped 0.0")
	assert_almost_eq(ComfortScore.compute_comfort(0.0, 0.0), 0.0, 1e-4, "0 tolerance -> 0.0 safe")

	# compute_rate(comfort, messy_rate, tidy_rate)
	assert_almost_eq(ComfortScore.compute_rate(1.0, -2.0, 1.0), 1.0, 1e-4, "Comfort 1.0 -> tidy_rate (+1.0/h)")
	assert_almost_eq(ComfortScore.compute_rate(0.0, -2.0, 1.0), -2.0, 1e-4, "Comfort 0.0 -> messy_rate (-2.0/h)")
	assert_almost_eq(ComfortScore.compute_rate(0.5, -2.0, 1.0), -0.5, 1e-4, "Comfort 0.5 -> linear lerp (-0.5/h)")

func test_comfort_score_node_applies_sanity_rate_modifier() -> void:
	var cs: ComfortScore = ComfortScore.new()
	cs.tolerance = 8.0
	cs.tidy_rate = 1.0
	cs.messy_rate = -2.0
	add_child_autoqfree(cs)

	var mods: Array[StatModifier] = StatusManager.get_modifiers(Enums.Stat.SANITY)
	var comfort_mod: StatModifier = null
	for m: StatModifier in mods:
		if m.source_id == &"apartment_comfort":
			comfort_mod = m
			break

	assert_not_null(comfort_mod, "Should have apartment_comfort modifier in StatusManager")
	assert_eq(comfort_mod.kind, Enums.ModifierKind.RATE_ADD)
	assert_almost_eq(comfort_mod.value, 1.0, 1e-4, "Clean apartment starts at tidy_rate")

func test_comfort_score_updates_with_clutter() -> void:
	var cs: ComfortScore = ComfortScore.new()
	cs.tolerance = 8.0
	cs.tidy_rate = 1.0
	cs.messy_rate = -2.0
	add_child_autoqfree(cs)

	# Add clutter with weight 4.0
	var c1: Clutter = Clutter.new()
	c1.weight = 4.0
	add_child_autoqfree(c1)

	var comfort: float = cs.update_comfort()
	assert_almost_eq(comfort, 0.5, 1e-4, "Comfort with 4/8 weight should be 0.5")

	var mods: Array[StatModifier] = StatusManager.get_modifiers(Enums.Stat.SANITY)
	var comfort_mod: StatModifier = null
	for m: StatModifier in mods:
		if m.source_id == &"apartment_comfort":
			comfort_mod = m
			break
	assert_not_null(comfort_mod)
	assert_almost_eq(comfort_mod.value, -0.5, 1e-4, "Modifier value should be -0.5/h")

	# Add second clutter with weight 4.0 (total = 8.0)
	var c2: Clutter = Clutter.new()
	c2.weight = 4.0
	add_child_autoqfree(c2)

	comfort = cs.update_comfort()
	assert_almost_eq(comfort, 0.0, 1e-4, "Comfort with 8/8 weight should be 0.0")

	mods = StatusManager.get_modifiers(Enums.Stat.SANITY)
	for m: StatModifier in mods:
		if m.source_id == &"apartment_comfort":
			comfort_mod = m
			break
	assert_almost_eq(comfort_mod.value, -2.0, 1e-4, "Modifier value should be -2.0/h at comfort 0.0")

func test_clutter_clean_action_advances_time_applies_reward_emits_signal_and_frees() -> void:
	GameClock.now_minutes = 500
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)

	var dishes_scene: PackedScene = load("res://features/cleaning/dishes.tscn")
	assert_not_null(dishes_scene, "dishes.tscn should load")

	var clutter: Clutter = dishes_scene.instantiate() as Clutter
	assert_not_null(clutter)
	add_child_autoqfree(clutter)

	watch_signals(EventBus)

	var start_min: int = GameClock.now_minutes
	var start_sanity: float = StatusManager.get_value(Enums.Stat.SANITY)

	clutter.clean()

	# Assert time advanced by clean_time_min (5 min)
	assert_eq(GameClock.now_minutes, start_min + 5, "Clock should advance by clean_time_min")

	# Assert reward applied (+2.0 sanity instant minus natural decay during skip of 5 min at base -1.5/h)
	var expected_sanity: float = start_sanity + 2.0 - (5.0 * (1.5 / 60.0))
	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), expected_sanity, 1e-3, "Sanity should reflect reward minus decay")


	# Assert signal emitted
	assert_signal_emitted_with_parameters(EventBus, "clutter_cleaned", [&"dishes", 1.0])

	# Assert node queued for deletion
	assert_true(clutter.is_queued_for_deletion(), "Cleaned clutter should be queued for deletion")

func test_clutter_scenes_exist_and_properties() -> void:
	var scenes: Dictionary = {
		&"dishes": "res://features/cleaning/dishes.tscn",
		&"laundry": "res://features/cleaning/laundry.tscn",
		&"trash": "res://features/cleaning/trash.tscn",
		&"dog_accident": "res://features/cleaning/dog_accident.tscn"
	}

	for type: StringName in scenes:
		var scene: PackedScene = load(scenes[type])
		assert_not_null(scene, "Scene for %s should exist" % type)
		var inst: Clutter = scene.instantiate() as Clutter
		assert_not_null(inst, "Instance of %s should be Clutter" % type)
		add_child_autoqfree(inst)

		assert_eq(inst.clutter_type, type)
		assert_gt(inst.weight, 0.0)
		assert_gt(inst.clean_time_min, 0)
		assert_not_null(inst.interactable, "Should have Interactable child")
		assert_true(inst.interactable.prompt_text.begins_with("Clean "), "Prompt text should start with Clean")

func test_spawner_marker_availability_and_max_count() -> void:
	var markers_parent: Node3D = Node3D.new()
	add_child_autoqfree(markers_parent)

	for i in range(3):
		var m: Marker3D = Marker3D.new()
		m.name = "Marker_%d" % i
		m.position = Vector3(float(i) * 5.0, 0.0, 0.0)
		markers_parent.add_child(m)

	var spawner: ClutterSpawner = ClutterSpawner.new()
	spawner.markers_container = markers_parent
	spawner.max_count = 3
	add_child_autoqfree(spawner)

	assert_eq(spawner.get_all_markers().size(), 3)
	assert_eq(spawner.get_free_markers().size(), 3)

	# Spawn 1
	var c1: Clutter = spawner.spawn()
	assert_not_null(c1)
	assert_eq(spawner.get_free_markers().size(), 2)

	# Spawn 2
	var c2: Clutter = spawner.spawn()
	assert_not_null(c2)
	assert_eq(spawner.get_free_markers().size(), 1)

	# Spawn 3
	var c3: Clutter = spawner.spawn()
	assert_not_null(c3)
	assert_eq(spawner.get_free_markers().size(), 0)

	# Spawn 4 should fail due to no free markers / max_count
	var c4: Clutter = spawner.spawn()
	assert_null(c4, "Cannot spawn when all markers occupied or max count reached")

	# Delete one clutter
	c1.queue_free()
	# Wait one frame for free queue
	await get_tree().process_frame
	assert_eq(spawner.get_free_markers().size(), 1)

	var c5: Clutter = spawner.spawn()
	assert_not_null(c5, "Can spawn again after a marker is freed")

func test_spawner_programmatic_spawn_at_position() -> void:
	var spawner: ClutterSpawner = ClutterSpawner.new()
	spawner.max_count = 10
	add_child_autoqfree(spawner)

	var target_pos: Vector3 = Vector3(12.0, 0.5, -4.0)
	var clutter: Clutter = spawner.spawn(&"dog_accident", target_pos)

	assert_not_null(clutter)
	assert_eq(clutter.clutter_type, &"dog_accident")
	assert_almost_eq(clutter.global_position.x, target_pos.x, 0.05)
	assert_almost_eq(clutter.global_position.y, target_pos.y, 0.05)
	assert_almost_eq(clutter.global_position.z, target_pos.z, 0.05)

func test_spawner_elapsed_time_simulation_fixed_seed() -> void:
	var markers_parent: Node3D = Node3D.new()
	add_child_autoqfree(markers_parent)

	for i in range(10):
		var m: Marker3D = Marker3D.new()
		m.name = "Marker_%d" % i
		m.position = Vector3(float(i) * 3.0, 0.0, 0.0)
		markers_parent.add_child(m)

	var spawner: ClutterSpawner = ClutterSpawner.new()
	spawner.markers_container = markers_parent
	spawner.spawn_rate_per_hour = 1.0 # 100% chance per hour
	spawner.max_count = 10
	spawner.rng.seed = 4242
	add_child_autoqfree(spawner)

	# 180 minutes = 3 hours. At 1.0 rate, exactly 3 should spawn
	var spawned: int = spawner.simulate_elapsed_time(180)
	assert_eq(spawned, 3, "At 1.0 rate, 180 min should spawn 3 clutter")
	assert_eq(spawner.get_clutter_count(), 3)

	# Simulate another 600 minutes (10 hours) with max_count = 5
	spawner.max_count = 5
	spawner.simulate_elapsed_time(600)
	assert_eq(spawner.get_clutter_count(), 5, "Should cap at max_count 5")

func test_apartment_level_state_save_and_restore() -> void:
	var apt_scene: PackedScene = load(APARTMENT_SCENE_PATH)
	assert_not_null(apt_scene)

	var apt1: Apartment = apt_scene.instantiate() as Apartment
	add_child_autoqfree(apt1)

	# Wait a frame for setup
	await get_tree().process_frame

	var spawner: ClutterSpawner = apt1.clutter_spawner
	assert_not_null(spawner)

	# Clear any clutter and spawn 2 known items
	spawner.clear_all()
	await get_tree().process_frame

	var c1: Clutter = spawner.spawn(&"dishes", Vector3(1.0, 0.0, 2.0))
	var c2: Clutter = spawner.spawn(&"laundry", Vector3(-2.0, 0.0, 3.0))
	assert_not_null(c1)
	assert_not_null(c2)

	GameClock.now_minutes = 600
	var saved: Dictionary = apt1.save_state()

	assert_true(saved.has("clutter"))
	assert_eq((saved["clutter"] as Array).size(), 2)
	assert_eq(int(saved["left_at_minute"]), 600)

	var stored: Dictionary = SceneRouter.get_level_state("apartment")
	assert_eq((stored["clutter"] as Array).size(), 2)

	# Free apartment 1
	apt1.queue_free()
	await get_tree().process_frame

	# Advance clock by 0 minutes (no extra spawns)
	var apt2: Apartment = apt_scene.instantiate() as Apartment
	add_child_autoqfree(apt2)
	await get_tree().process_frame

	assert_eq(apt2.clutter_spawner.get_clutter_count(), 2, "Restored apartment should have exactly 2 clutter items")

func test_apartment_elapsed_time_on_restore() -> void:
	SceneRouter.reset_state()
	# Store state leaving at minute 600 with 1 dish
	var initial_state: Dictionary = {
		"clutter": [
			{"type": "dishes", "position": [1.0, 0.0, 2.0]}
		],
		"left_at_minute": 600
	}
	SceneRouter.store_level_state("apartment", initial_state)

	# Time is now 780 (3 hours later)
	GameClock.now_minutes = 780

	var apt_scene: PackedScene = load(APARTMENT_SCENE_PATH)
	var apt: Apartment = apt_scene.instantiate() as Apartment
	var spawner: ClutterSpawner = apt.get_node("ClutterSpawner") as ClutterSpawner
	spawner.spawn_rate_per_hour = 1.0 # 100% rate to test deterministic spawns
	spawner.rng.seed = 9999
	add_child_autoqfree(apt)
	await get_tree().process_frame

	# 1 initial + 3 elapsed hours = 4 clutter items
	assert_eq(spawner.get_clutter_count(), 4, "Should restore 1 and spawn 3 for 3 elapsed hours")

func test_comfort_modifier_removed_on_level_exit() -> void:
	var apt_scene: PackedScene = load(APARTMENT_SCENE_PATH)
	var apt: Apartment = apt_scene.instantiate() as Apartment
	add_child_autoqfree(apt)
	await get_tree().process_frame

	# Modifier must be present
	var mods: Array[StatModifier] = StatusManager.get_modifiers(Enums.Stat.SANITY)
	var found: bool = false
	for m: StatModifier in mods:
		if m.source_id == &"apartment_comfort":
			found = true
			break
	assert_true(found, "Apartment comfort modifier must be active while in apartment")

	# Exit level
	apt.queue_free()
	await get_tree().process_frame

	# Modifier must be removed
	mods = StatusManager.get_modifiers(Enums.Stat.SANITY)
	found = false
	for m: StatModifier in mods:
		if m.source_id == &"apartment_comfort":
			found = true
			break
	assert_false(found, "Apartment comfort modifier must be removed after exiting apartment")


func test_scene_router_flush_level_state() -> void:
	watch_signals(SceneRouter)
	SceneRouter.request_flush()
	assert_signal_emitted(SceneRouter, "flush_level_state")

func test_apartment_scene_composes_spawner_comfort_and_container() -> void:
	var apt_scene: PackedScene = load(APARTMENT_SCENE_PATH)
	var apt: Node = apt_scene.instantiate()
	add_child_autoqfree(apt)

	assert_is(apt, Apartment, "Apartment should be instance of Apartment class")
	assert_is(apt, LevelRoot, "Apartment should also be instance of LevelRoot")

	var spawner: Node = apt.get_node_or_null("ClutterSpawner")
	assert_not_null(spawner, "ClutterSpawner node should exist")
	assert_is(spawner, ClutterSpawner)

	var comfort: Node = apt.get_node_or_null("ComfortScore")
	assert_not_null(comfort, "ComfortScore node should exist")
	assert_is(comfort, ComfortScore)

	var container: Node = apt.get_node_or_null("ClutterContainer")
	assert_not_null(container, "ClutterContainer node should exist")
