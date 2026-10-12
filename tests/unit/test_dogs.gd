extends GutTest

var maja_profile: DogProfile
var cipa_profile: DogProfile
var dog_scene: PackedScene
var maja_scene: PackedScene
var cipa_scene: PackedScene
var bowls_scene: PackedScene
var front_door_scene: PackedScene


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	SceneRouter.reset_state()

	maja_profile = load("res://data/dogs/maja.tres") as DogProfile
	cipa_profile = load("res://data/dogs/cipa.tres") as DogProfile
	dog_scene = load("res://features/dogs/dog.tscn") as PackedScene
	maja_scene = load("res://features/dogs/maja.tscn") as PackedScene
	cipa_scene = load("res://features/dogs/cipa.tscn") as PackedScene
	bowls_scene = load("res://features/dogs/dog_bowls.tscn") as PackedScene
	front_door_scene = load("res://features/prep/front_door.tscn") as PackedScene


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	SceneRouter.reset_state()


# ---------------------------------------------------------
# 1. Profile Verification
# ---------------------------------------------------------

func test_dog_profiles_exist_and_differ() -> void:
	assert_not_null(maja_profile, "Maja profile should load")
	assert_not_null(cipa_profile, "Čipa profile should load")

	assert_eq(maja_profile.id, &"maja")
	assert_eq(maja_profile.display_name, "Maja")
	assert_eq(cipa_profile.id, &"cipa")
	assert_eq(cipa_profile.display_name, "Čipa")

	# Profiles must differ in personalities / decay rates
	assert_gt(cipa_profile.speed, maja_profile.speed, "Čipa is faster than Maja")
	assert_gt(cipa_profile.bladder_decay_per_hour, maja_profile.bladder_decay_per_hour, "Čipa has faster bladder decay")
	assert_gt(cipa_profile.energy_decay_per_hour, maja_profile.energy_decay_per_hour, "Čipa has faster energy decay")
	assert_gt(cipa_profile.affection_decay_per_hour, maja_profile.affection_decay_per_hour, "Čipa needs more affection")


# ---------------------------------------------------------
# 2. Pure Decision Logic Tests
# ---------------------------------------------------------

func test_evaluate_next_state_cuddle_priority() -> void:
	var needs: Dictionary = {"hunger": 90.0, "bladder": 90.0, "affection": 10.0, "energy": 10.0}
	var state: StringName = DogBrain.evaluate_next_state(needs, maja_profile, {"is_cuddling": true})
	assert_eq(state, &"Cuddle", "Cuddle takes top priority regardless of urgent needs")


func test_evaluate_next_state_low_energy_triggers_sleep() -> void:
	var needs: Dictionary = {"hunger": 0.0, "bladder": 0.0, "affection": 100.0, "energy": 15.0}
	var state: StringName = DogBrain.evaluate_next_state(needs, maja_profile)
	assert_eq(state, &"Sleep", "Energy at or below threshold triggers SleepState")


func test_evaluate_next_state_hunger_with_and_without_food() -> void:
	var needs: Dictionary = {"hunger": 80.0, "bladder": 0.0, "affection": 100.0, "energy": 100.0}

	# Hungry + food available -> Eat
	var state_with_food: StringName = DogBrain.evaluate_next_state(needs, maja_profile, {"has_food": true})
	assert_eq(state_with_food, &"Eat", "Hungry dog with food transitions to Eat")

	# Hungry + no food -> Request
	var state_no_food: StringName = DogBrain.evaluate_next_state(needs, maja_profile, {"has_food": false})
	assert_eq(state_no_food, &"Request", "Hungry dog with no food transitions to Request")


func test_evaluate_next_state_urgent_bladder_and_affection() -> void:
	# Full bladder -> Request
	var bladder_needs: Dictionary = {"hunger": 0.0, "bladder": 85.0, "affection": 100.0, "energy": 100.0}
	var state_bladder: StringName = DogBrain.evaluate_next_state(bladder_needs, maja_profile)
	assert_eq(state_bladder, &"Request", "Full bladder triggers Request")

	# Low affection -> Request
	var affection_needs: Dictionary = {"hunger": 0.0, "bladder": 0.0, "affection": 20.0, "energy": 100.0}
	var state_affection: StringName = DogBrain.evaluate_next_state(affection_needs, maja_profile)
	assert_eq(state_affection, &"Request", "Low affection triggers Request")


func test_evaluate_next_state_idle_wander_follow_defaults() -> void:
	var normal_needs: Dictionary = {"hunger": 10.0, "bladder": 10.0, "affection": 90.0, "energy": 90.0}

	var state_default: StringName = DogBrain.evaluate_next_state(normal_needs, maja_profile)
	assert_eq(state_default, &"Idle", "Normal needs default to Idle")

	var state_wander: StringName = DogBrain.evaluate_next_state(normal_needs, maja_profile, {"wander": true})
	assert_eq(state_wander, &"Wander", "Context wander triggers Wander")

	var state_follow: StringName = DogBrain.evaluate_next_state(normal_needs, maja_profile, {"follow_player": true})
	assert_eq(state_follow, &"Follow", "Context follow triggers Follow")


func test_evaluate_request_reason() -> void:
	var needs_hunger: Dictionary = {"hunger": 75.0, "bladder": 10.0, "affection": 90.0}
	assert_eq(DogBrain.evaluate_request_reason(needs_hunger, maja_profile), &"hunger")

	var needs_bladder: Dictionary = {"hunger": 10.0, "bladder": 80.0, "affection": 90.0}
	assert_eq(DogBrain.evaluate_request_reason(needs_bladder, maja_profile), &"bladder")

	var needs_affection: Dictionary = {"hunger": 10.0, "bladder": 10.0, "affection": 20.0}
	assert_eq(DogBrain.evaluate_request_reason(needs_affection, maja_profile), &"affection")


# ---------------------------------------------------------
# 3. Time Integration & Bladder Overflow Simulation
# ---------------------------------------------------------

func test_simulate_needs_decay_over_one_hour() -> void:
	var initial: Dictionary = {"hunger": 10.0, "bladder": 20.0, "affection": 90.0, "energy": 80.0}
	var res: Dictionary = DogBrain.simulate_needs(initial, maja_profile, 60)
	var end_needs: Dictionary = res["needs"]

	assert_almost_eq(end_needs["hunger"], 10.0 + maja_profile.hunger_decay_per_hour, 0.01)
	assert_almost_eq(end_needs["bladder"], 20.0 + maja_profile.bladder_decay_per_hour, 0.01)
	assert_almost_eq(end_needs["affection"], 90.0 - maja_profile.affection_decay_per_hour, 0.01)
	assert_almost_eq(end_needs["energy"], 80.0 - maja_profile.energy_decay_per_hour, 0.01)
	assert_eq(res["accidents"], 0, "No accidents below 100 bladder")


func test_simulate_needs_bladder_overflow_generates_accidents() -> void:
	# Maja bladder decay = 8/h. In 15 hours, gains 120. Starting from 90 -> total 210 -> 2 accidents! Remainder 10.
	var initial: Dictionary = {"hunger": 0.0, "bladder": 90.0, "affection": 100.0, "energy": 100.0}
	var res: Dictionary = DogBrain.simulate_needs(initial, maja_profile, 15 * 60)

	assert_eq(res["accidents"], 2, "15 hours should produce 2 accidents")
	assert_almost_eq(res["needs"]["bladder"], 10.0, 0.01, "Remainder bladder should be 10")


func test_dog_integrate_time_and_ticks_equivalence() -> void:
	var dog1: Dog = dog_scene.instantiate() as Dog
	dog1.profile = maja_profile
	add_child_autoqfree(dog1)
	dog1.needs = {"hunger": 0.0, "bladder": 20.0, "affection": 80.0, "energy": 80.0}

	var dog2: Dog = dog_scene.instantiate() as Dog
	dog2.profile = maja_profile
	add_child_autoqfree(dog2)
	dog2.needs = {"hunger": 0.0, "bladder": 20.0, "affection": 80.0, "energy": 80.0}

	# dog1 integrated via 60 1-minute steps
	for _i in range(60):
		dog1.integrate_time(1)

	# dog2 integrated via single 60-minute skip
	dog2.integrate_time(60)

	assert_almost_eq(dog1.needs["hunger"], dog2.needs["hunger"], 0.01)
	assert_almost_eq(dog1.needs["bladder"], dog2.needs["bladder"], 0.01)
	assert_almost_eq(dog1.needs["affection"], dog2.needs["affection"], 0.01)
	assert_almost_eq(dog1.needs["energy"], dog2.needs["energy"], 0.01)


# ---------------------------------------------------------
# 4. Care Actions: Bowls & Feeding
# ---------------------------------------------------------

func test_dog_bowls_fill_and_consume() -> void:
	var bowls: DogBowls = bowls_scene.instantiate() as DogBowls
	add_child_autoqfree(bowls)

	assert_false(bowls.has_food, "Bowls initially empty")
	assert_eq(bowls.interactable.prompt_text, "Fill dog bowls")

	bowls.fill()
	assert_true(bowls.has_food, "Bowls filled after fill()")
	assert_eq(bowls.portions_remaining, 2)
	assert_true(bowls.is_food_available())
	assert_false(bowls.interactable.enabled, "Interactable disabled when full")

	# Consume first portion
	assert_true(bowls.consume_food())
	assert_eq(bowls.portions_remaining, 1)
	assert_true(bowls.has_food)

	# Consume second portion
	assert_true(bowls.consume_food())
	assert_eq(bowls.portions_remaining, 0)
	assert_false(bowls.has_food)
	assert_true(bowls.interactable.enabled, "Interactable re-enabled when empty")
	assert_eq(bowls.interactable.prompt_text, "Fill dog bowls")


func test_dog_feed_resets_hunger() -> void:
	var dog: Dog = dog_scene.instantiate() as Dog
	dog.profile = maja_profile
	add_child_autoqfree(dog)

	dog.set_need(&"hunger", 85.0)
	assert_almost_eq(dog.get_need(&"hunger"), 85.0, 0.01)

	dog.feed()
	assert_almost_eq(dog.get_need(&"hunger"), 0.0, 0.01, "Feeding resets hunger to 0")


# ---------------------------------------------------------
# 5. Care Actions: Petting & Cuddle Buffs
# ---------------------------------------------------------

func test_dog_pet_boosts_affection_and_grants_player_sanity() -> void:
	var dog: Dog = dog_scene.instantiate() as Dog
	dog.profile = maja_profile
	add_child_autoqfree(dog)

	StatusManager.set_value(Enums.Stat.SANITY, 50.0)
	var initial_sanity: float = StatusManager.get_value(Enums.Stat.SANITY)

	dog.set_need(&"affection", 20.0)
	dog.pet()

	assert_almost_eq(dog.get_need(&"affection"), 100.0, 0.01, "Petting boosts affection to 100")
	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), initial_sanity + 10.0, 0.01, "Instant +10 Sanity applied")

	# Verify 30-min RATE_ADD buff (+1.0/h) with source "dog:maja:cuddle"
	var mods: Array[StatModifier] = StatusManager.get_modifiers(Enums.Stat.SANITY)
	var found_buff: bool = false
	for m: StatModifier in mods:
		if m.source_id == &"dog:maja:cuddle" and m.kind == Enums.ModifierKind.RATE_ADD and is_equal_approx(m.value, 1.0):
			found_buff = true
			assert_eq(m.duration_min, 30)
			break
	assert_true(found_buff, "30-min RATE_ADD buff with source dog:maja:cuddle found on StatusManager")


# ---------------------------------------------------------
# 6. Care Actions: Front Door Walking Option
# ---------------------------------------------------------

func test_front_door_walk_dogs_action() -> void:
	var door: FrontDoor = front_door_scene.instantiate() as FrontDoor
	add_child_autoqfree(door)

	var maja: Dog = maja_scene.instantiate() as Dog
	add_child_autoqfree(maja)
	maja.set_need(&"bladder", 80.0)
	maja.set_need(&"energy", 90.0)

	var cipa: Dog = cipa_scene.instantiate() as Dog
	add_child_autoqfree(cipa)
	cipa.set_need(&"bladder", 90.0)
	cipa.set_need(&"energy", 80.0)

	door.update_prompt()
	assert_true(door.interactable.prompt_text.contains("Walk the dogs"), "Prompt offers dog walk when dogs present")

	StatusManager.set_value(Enums.Stat.HEALTH, 50.0)
	StatusManager.set_value(Enums.Stat.HYGIENE, 80.0)
	var initial_health: float = StatusManager.get_value(Enums.Stat.HEALTH)
	var initial_hygiene: float = StatusManager.get_value(Enums.Stat.HYGIENE)
	var start_min: int = GameClock.now_minutes

	door.walk_dogs(null, 20)

	assert_eq(GameClock.now_minutes - start_min, 20, "GameClock skipped 20 minutes")
	assert_almost_eq(maja.get_need(&"bladder"), 0.0, 0.01, "Maja bladder reset to 0")
	assert_almost_eq(cipa.get_need(&"bladder"), 0.0, 0.01, "Čipa bladder reset to 0")
	assert_lt(maja.get_need(&"energy"), 90.0, "Maja energy reduced")
	assert_lt(cipa.get_need(&"energy"), 80.0, "Čipa energy reduced")

	# Player health (+15) and hygiene (-10)
	# Note: 20 min of decay also passes during skip!
	assert_gt(StatusManager.get_value(Enums.Stat.HEALTH), initial_health + 10.0, "Health increased by ~15")
	assert_lt(StatusManager.get_value(Enums.Stat.HYGIENE), initial_hygiene - 8.0, "Hygiene decreased by ~10")


# ---------------------------------------------------------
# 7. Neglect Mechanics: Bladder Accidents & Whining Penalty
# ---------------------------------------------------------

func test_bladder_over_100_spawns_accident_and_resets() -> void:
	var spawner := ClutterSpawner.new()
	add_child_autoqfree(spawner)

	var dog: Dog = dog_scene.instantiate() as Dog
	dog.profile = maja_profile
	add_child_autoqfree(dog)

	dog.set_need(&"bladder", 99.0)
	assert_eq(spawner.get_clutter_count(), 0)

	# Adding bladder over 100 via integrate_time
	dog.integrate_time(30) # at 8/h -> +4 bladder -> overflows 100!

	assert_almost_eq(dog.get_need(&"bladder"), 3.0, 0.05, "Bladder wraps around after accident")
	assert_gt(spawner.get_clutter_count(), 0, "Dog accident clutter spawned in scene")


func test_affection_neglect_applies_whining_penalty_until_petted() -> void:
	var dog: Dog = dog_scene.instantiate() as Dog
	dog.profile = maja_profile
	add_child_autoqfree(dog)

	# Affection above threshold
	dog.set_need(&"affection", 60.0)
	dog.dog_brain._evaluate_urgencies()

	var mods: Array[StatModifier] = StatusManager.get_modifiers(Enums.Stat.SANITY)
	var has_whine: bool = false
	for m: StatModifier in mods:
		if m.source_id == &"dog:maja:whine":
			has_whine = true
	assert_false(has_whine, "No whining penalty when affection is healthy")

	# Drop affection below threshold (threshold is 30)
	dog.set_need(&"affection", 20.0)
	dog.dog_brain._evaluate_urgencies()

	assert_eq(dog.dog_brain.current_state.name, &"Request", "Dog enters Request state on low affection")

	mods = StatusManager.get_modifiers(Enums.Stat.SANITY)
	has_whine = false
	for m: StatModifier in mods:
		if m.source_id == &"dog:maja:whine" and is_equal_approx(m.value, -1.0):
			has_whine = true
	assert_true(has_whine, "Whining penalty of -1.0/h registered on StatusManager")

	# Petting the dog resolves the whining penalty
	dog.pet()
	mods = StatusManager.get_modifiers(Enums.Stat.SANITY)
	has_whine = false
	for m: StatModifier in mods:
		if m.source_id == &"dog:maja:whine":
			has_whine = true
	assert_false(has_whine, "Whining penalty removed upon petting the dog")


func test_threshold_crossing_emits_eventbus_signal() -> void:
	var dog: Dog = dog_scene.instantiate() as Dog
	dog.profile = maja_profile
	add_child_autoqfree(dog)

	watch_signals(EventBus)

	# Initially at 0 hunger (not urgent)
	dog.set_need(&"hunger", 50.0)
	assert_signal_not_emitted(EventBus, "dog_need_changed", "No signal when staying below threshold")

	# Cross threshold (70.0)
	dog.set_need(&"hunger", 75.0)
	assert_signal_emitted_with_parameters(EventBus, "dog_need_changed", [&"maja", &"hunger", 75.0])

	# Further increase above threshold does not emit again
	dog.set_need(&"hunger", 85.0)
	assert_signal_emit_count(EventBus, "dog_need_changed", 1)

	# Crossing back down emits
	dog.set_need(&"hunger", 20.0)
	assert_signal_emit_count(EventBus, "dog_need_changed", 2)


# ---------------------------------------------------------
# 8. Level State Save & Restore Round-Trip
# ---------------------------------------------------------

func test_apartment_dogs_save_and_restore_round_trip() -> void:
	var apt_scene: PackedScene = load("res://levels/apartment/apartment.tscn") as PackedScene
	var apt: Apartment = apt_scene.instantiate() as Apartment
	add_child_autoqfree(apt)

	# Modify dog needs in scene
	var dogs: Array[Node] = apt.find_child("Dogs", true, false).get_children()
	var maja: Dog = null
	for d: Node in dogs:
		if d is Dog and d.profile.id == &"maja":
			maja = d
	assert_not_null(maja, "Maja found in apartment")
	maja.set_need(&"hunger", 45.0)
	maja.set_need(&"bladder", 50.0)

	var state: Dictionary = apt.save_state()
	assert_true(state.has("dogs"), "Apartment saved state contains dogs")
	assert_true(state["dogs"].has("maja"))
	assert_almost_eq(state["dogs"]["maja"]["needs"]["hunger"], 45.0, 0.01)

	# Simulate leaving apartment and returning 2 hours later
	GameClock.skip(120)

	# Instantiate a new apartment and restore
	var apt2: Apartment = apt_scene.instantiate() as Apartment
	add_child_autoqfree(apt2)

	var dogs2: Array[Node] = apt2.find_child("Dogs", true, false).get_children()
	var maja2: Dog = null
	for d: Node in dogs2:
		if d is Dog and d.profile.id == &"maja":
			maja2 = d
	assert_not_null(maja2)

	# Needs should have integrated 2 hours of decay: hunger +10, bladder +16
	assert_almost_eq(maja2.get_need(&"hunger"), 45.0 + maja_profile.hunger_decay_per_hour * 2.0, 0.1)
	assert_almost_eq(maja2.get_need(&"bladder"), 50.0 + maja_profile.bladder_decay_per_hour * 2.0, 0.1)
