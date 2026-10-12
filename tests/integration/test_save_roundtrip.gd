extends GutTest

func before_each() -> void:
	SaveManager.delete_save()
	_cleanup_bak_file()
	_reset_all_managers()


func after_each() -> void:
	SaveManager.delete_save()
	_cleanup_bak_file()
	_reset_all_managers()


func _cleanup_bak_file() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save_01.json.bak"):
		dir.remove("save_01.json.bak")


func _reset_all_managers() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	NarrativeManager.reset_state()
	SceneRouter.reset_state()
	DayDirector.reset_state()
	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("reset_state"):
		phone.call("reset_state")


func test_save_and_load_full_roundtrip() -> void:
	# 1. Mutate each manager with non-default state
	GameSettings.current().cycle_length_days = 26
	GameSettings.current().symptom_intensity = 0.75
	GameSettings.current().minutes_per_real_second = 2.0
	GameSettings.current().wake_minute_of_day = 450

	GameClock.now_minutes = 750
	GameClock.create_countdown(&"test_timer", 820, {"source": "unit_test"})

	StatusManager.set_value(Enums.Stat.SANITY, 45.0)
	StatusManager.set_value(Enums.Stat.HEALTH, 82.0)
	StatusManager.set_value(Enums.Stat.HYGIENE, 60.0)
	StatusManager.set_value(Enums.Stat.RAGE, 35.0)

	var mod := StatModifier.new()
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = -0.5
	mod.duration_min = 120
	mod.source_id = &"test_stress"
	mod.label = "Test Stress"
	StatusManager.add_modifier(mod)

	CycleManager.cycle_start_day = 5
	CycleManager.current_phase = Enums.CyclePhase.OVULATORY

	FinanceManager.wallet_cents = 43210
	FinanceManager.spend(1500, &"coffee", "Morning Espresso")

	var dress: ClothingItem = load("res://data/clothing/dress/dress_peasant_ensemble.tres") as ClothingItem
	if dress:
		InventoryManager.add_owned(dress)
		InventoryManager.equip(dress)

	var cosmetic: CosmeticItem = load("res://data/cosmetics/lipstick/lipstick_crimson_velvet.tres") as CosmeticItem
	if cosmetic:
		InventoryManager.add_owned_cosmetic(cosmetic)

	var top_item: Resource = load("res://data/clothing/top/top_chic_blouse.tres")
	if top_item:
		InventoryManager.add_delivery(top_item, 2)

	var outing_data: OutingData = load("res://data/outings/girls_day_out.tres") as OutingData
	if outing_data:
		OutingManager.set_affinity("Chloe", 42)
		OutingManager.schedule(outing_data, 900, "Chloe")

	NarrativeManager.set_flag(&"self_respect", 3)
	NarrativeManager.set_flag(&"work_boundary_set", 1)
	NarrativeManager.fired_events.append(&"family_marriage")
	NarrativeManager.last_event_minute = 650

	SceneRouter.current_level_id = "apartment"
	SceneRouter.store_level_state("apartment", {"clutter_cleared": 4, "test_key": "test_val"})
	SceneRouter.store_level_state("thrift_store", {"visited_today": true})

	DayDirector.current_beat = DayDirector.Beat.EVENING
	DayDirector.current_day = 3
	DayDirector.is_thrift_day = false
	DayDirector.pressure_triggered_today = true
	DayDirector.clutter_cleaned_count = 5
	DayDirector.clutter_cleaned_weight = 6.5
	DayDirector.clutter_types_cleaned = [&"dishes", &"trash"]
	DayDirector.dog_walks_count = 2
	DayDirector.dog_feedings_count = 3
	DayDirector.dog_pets_count = 4
	DayDirector.outing_result_today = {
		"id": "girls_day_out",
		"name": "Girls' Day Out",
		"result": int(Enums.OutingResult.PASS),
		"score": 0.85
	}
	DayDirector.narrative_choices_today = [{
		"event_id": "work_day_off",
		"speaker": "Dan",
		"stance": int(Enums.Stance.ASSERT),
		"stance_name": "ASSERT",
		"text": "Today is my day off."
	}]

	CycleManager.force_phase(Enums.CyclePhase.OVULATORY)

	# 2. Save game to JSON
	var save_result: bool = SaveManager.save_game()
	assert_true(save_result, "save_game() should succeed")
	assert_true(SaveManager.has_save(), "has_save() should be true after saving")

	# Snapshot what was saved
	var exp_settings: Dictionary = GameSettings.current().to_dict()
	var exp_clock: Dictionary = GameClock.to_dict()
	var exp_status: Dictionary = StatusManager.to_dict()
	var exp_cycle: Dictionary = CycleManager.to_dict()
	var exp_finance: Dictionary = FinanceManager.to_dict()
	var exp_inventory: Dictionary = InventoryManager.to_dict()
	var exp_outing: Dictionary = OutingManager.to_dict()
	var exp_narrative: Dictionary = NarrativeManager.to_dict()
	var exp_router: Dictionary = SceneRouter.to_dict()
	var exp_day: Dictionary = DayDirector.to_dict()

	# 3. Reset everything
	_reset_all_managers()
	assert_ne(GameClock.to_dict(), exp_clock, "Clock state should be reset")
	assert_ne(FinanceManager.to_dict(), exp_finance, "Finance state should be reset")
	assert_ne(NarrativeManager.to_dict(), exp_narrative, "Narrative state should be reset")

	# 4. Load game from JSON
	var load_result: bool = SaveManager.load_game(false)
	assert_true(load_result, "load_game() should return true")

	# 5. Verify full equality on all manager state dictionaries
	assert_eq(GameSettings.current().to_dict(), exp_settings, "Settings should match after load")
	assert_eq(GameClock.to_dict(), exp_clock, "GameClock should match after load")
	assert_eq(StatusManager.to_dict(), exp_status, "StatusManager should match after load")
	assert_eq(CycleManager.to_dict(), exp_cycle, "CycleManager should match after load")
	assert_eq(FinanceManager.to_dict(), exp_finance, "FinanceManager should match after load")
	assert_eq(InventoryManager.to_dict(), exp_inventory, "InventoryManager should match after load")
	assert_eq(OutingManager.to_dict(), exp_outing, "OutingManager should match after load")
	assert_eq(NarrativeManager.to_dict(), exp_narrative, "NarrativeManager should match after load")
	assert_eq(SceneRouter.to_dict(), exp_router, "SceneRouter should match after load")
	assert_eq(DayDirector.to_dict(), exp_day, "DayDirector should match after load")


func test_corrupt_file_handling() -> void:
	var corrupt_json: String = "NOT_A_VALID_JSON_STRING {[[ broken"
	var file := FileAccess.open("user://save_01.json", FileAccess.WRITE)
	assert_not_null(file, "Should open save_01.json for writing corrupt data")
	file.store_string(corrupt_json)
	file.close()

	assert_true(SaveManager.has_save())

	var load_ok: bool = SaveManager.load_game(false)
	assert_false(load_ok, "load_game should fail gracefully on corrupt file")

	assert_true(FileAccess.file_exists("user://save_01.json.bak"), ".bak file should be created for corrupt save")
	var bak_file := FileAccess.open("user://save_01.json.bak", FileAccess.READ)
	assert_not_null(bak_file)
	var bak_text: String = bak_file.get_as_text()
	bak_file.close()
	assert_eq(bak_text, corrupt_json, ".bak file should contain original corrupt content")


func test_missing_save_file() -> void:
	SaveManager.delete_save()
	assert_false(SaveManager.has_save(), "has_save should be false when no save exists")
	var load_ok: bool = SaveManager.load_game(false)
	assert_false(load_ok, "load_game should return false when no save exists")


func test_human_readable_json_formatting() -> void:
	SaveManager.save_game()
	assert_true(SaveManager.has_save())

	var file := FileAccess.open("user://save_01.json", FileAccess.READ)
	assert_not_null(file)
	var text: String = file.get_as_text()
	file.close()

	assert_true(text.contains("\n"), "Save file should be formatted with newlines")
	assert_true(text.contains("\"version\":"), "Save file should contain version field")
	assert_true(text.contains("\"game_clock\":"), "Save file should contain game_clock field")
	assert_true(text.contains("\"status_manager\":"), "Save file should contain status_manager field")
	assert_true(text.contains("\"day_director\":"), "Save file should contain day_director field")
