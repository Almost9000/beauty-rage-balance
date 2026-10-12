extends GutTest

func before_each() -> void:
	SaveManager.delete_save()
	_reset_all_managers()


func after_each() -> void:
	SaveManager.delete_save()
	_reset_all_managers()


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


func test_beat_progression_full_day_to_day_two() -> void:
	# 1. Day 1 Wake -> Free
	DayDirector.start_day(1)
	assert_eq(DayDirector.current_day, 1)
	assert_eq(DayDirector.current_beat, DayDirector.Beat.FREE)
	assert_false(DayDirector.is_thrift_day, "Day 1 should be an outing day")

	# Verify default outing scheduled on Day 1
	assert_not_null(OutingManager.get_next_scheduled_outing(), "Default outing should be scheduled on Day 1")

	# 2. Advance time towards prep (departure is at 960, prep_window is 90 -> starts at 870)
	GameClock.now_minutes = 869
	GameClock.advance_minutes(1) # 870
	assert_eq(DayDirector.current_beat, DayDirector.Beat.PREP, "Beat should transition to PREP at 870 min")

	# 3. Depart outing
	OutingManager.depart()
	assert_eq(DayDirector.current_beat, DayDirector.Beat.EVENING, "Beat should transition to EVENING after outing resolves")
	assert_false(DayDirector.outing_result_today.is_empty(), "Outing result should be recorded")

	# 4. Night Summary
	var summary: Dictionary = DayDirector.trigger_night_summary()
	assert_eq(DayDirector.current_beat, DayDirector.Beat.NIGHT_SUMMARY)
	assert_not_null(summary)
	assert_eq(summary["day"], 1)

	# 5. Sleep to Day 2
	var health_before: float = StatusManager.get_stat(Enums.Stat.HEALTH)
	var sanity_before: float = StatusManager.get_stat(Enums.Stat.SANITY)

	DayDirector.proceed_to_sleep()

	assert_eq(DayDirector.current_day, 2, "Day 2 should have started")
	assert_eq(DayDirector.current_beat, DayDirector.Beat.FREE, "Beat should return to FREE on Day 2")
	assert_true(DayDirector.is_thrift_day, "Day 2 should be flagged as a thrift day")

	# Verify sleep buffs applied
	assert_gt(StatusManager.get_stat(Enums.Stat.HEALTH), health_before - 1.0, "Health should receive sleep buff")
	assert_gt(StatusManager.get_stat(Enums.Stat.SANITY), sanity_before - 1.0, "Sanity should receive sleep buff")

	# Verify autosave written
	assert_true(SaveManager.has_save(), "Autosave should have been written after sleep")


func test_pressure_event_triggers_at_14_00() -> void:
	DayDirector.start_day(1)
	assert_false(DayDirector.pressure_triggered_today)

	var narrative_requested_ids: Array[StringName] = []
	EventBus.narrative_requested.connect(func(event_id: StringName) -> void:
		narrative_requested_ids.append(event_id)
	)

	# Clock starts at 480 (08:00). Advance to 839 (13:59)
	GameClock.now_minutes = 839
	assert_false(DayDirector.pressure_triggered_today)
	assert_eq(narrative_requested_ids.size(), 0)

	# Advance 1 minute to 840 (14:00)
	GameClock.advance_minutes(1)
	assert_true(DayDirector.pressure_triggered_today, "Pressure event should be triggered at 840 min (14:00)")
	assert_true(narrative_requested_ids.has(&"daily_pressure"), "EventBus should have received daily_pressure request")


func test_passout_forced_sleep_at_02_00() -> void:
	DayDirector.start_day(1)
	StatusManager.set_value(Enums.Stat.HEALTH, 90.0)

	# Advance time to 01:59 AM of Day 2 (minute 1440 + 119 = 1559)
	GameClock.now_minutes = 1559
	assert_eq(GameClock.get_day(), 2)
	assert_eq(GameClock.minute_of_day, 119)

	var health_before: float = StatusManager.get_stat(Enums.Stat.HEALTH)

	# Advance 1 minute to 02:00 AM (minute 120 of day 2)
	GameClock.advance_minutes(1)

	# Pass-out should have fired
	assert_eq(GameClock.minute_of_day, 600, "Clock should have skipped to passout wake minute (10:00 AM / 600 min)")
	assert_almost_eq(StatusManager.get_stat(Enums.Stat.HEALTH), 68.4, 0.5, "Health penalty and decay should be applied on passout")
	assert_true(SaveManager.has_save(), "Autosave should have been written after pass-out")


func test_night_summary_data_calculation() -> void:
	DayDirector.start_day(1)

	# Clean clutter
	EventBus.clutter_cleaned.emit(&"dishes", 1.5)
	EventBus.clutter_cleaned.emit(&"trash", 2.0)

	# Finances
	FinanceManager.spend(2500, &"coffee_shop", "Latte & pastry")
	FinanceManager.earn(5000, &"freelance", "Freelance edit")

	# Dog care
	DayDirector.record_dog_walk()
	DayDirector.record_dog_feeding()
	DayDirector.record_dog_pet()
	DayDirector.record_dog_pet()

	# Narrative choice
	DayDirector.narrative_choices_today.append({
		"event_id": "work_day_off",
		"speaker": "Dan",
		"stance": int(Enums.Stance.ASSERT),
		"stance_name": "ASSERT",
		"text": "Today is my day off."
	})

	var data: Dictionary = DayDirector.get_night_summary_data()

	assert_eq(data["day"], 1)
	assert_eq(data["clutter"]["count"], 2)
	assert_almost_eq(data["clutter"]["weight"], 3.5, 0.001)

	var fin: Dictionary = data["finance"]
	assert_eq(fin["spent_cents"], 2500)
	assert_eq(fin["earned_cents"], 5000)
	assert_eq(fin["net_cents"], 2500)

	var dogs: Dictionary = data["dog_care"]
	assert_eq(dogs["walks"], 1)
	assert_eq(dogs["feedings"], 1)
	assert_eq(dogs["pets"], 2)

	assert_eq(data["narrative"].size(), 1)
	assert_eq(data["narrative"][0]["speaker"], "Dan")


func test_bed_earliest_time_validation() -> void:
	DayDirector.start_day(1)

	# 12:00 PM (720 min) -> cannot sleep
	GameClock.now_minutes = 720
	assert_false(DayDirector.can_sleep(), "Should not be able to sleep at 12:00 PM")

	# 20:59 PM (1259 min) -> cannot sleep
	GameClock.now_minutes = 1259
	assert_false(DayDirector.can_sleep(), "Should not be able to sleep at 20:59 PM")

	# 21:00 PM (1260 min) -> bedtime earliest reached
	GameClock.now_minutes = 1260
	assert_true(DayDirector.can_sleep(), "Should be able to sleep at 21:00 PM")

	# 23:30 PM (1410 min) -> can sleep
	GameClock.now_minutes = 1410
	assert_true(DayDirector.can_sleep(), "Should be able to sleep at 23:30 PM")

	# 01:00 AM (60 min) -> can sleep
	GameClock.now_minutes = 1500
	assert_true(DayDirector.can_sleep(), "Should be able to sleep after midnight")
