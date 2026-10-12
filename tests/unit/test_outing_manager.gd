extends GutTest

var girls_day_out: OutingData
var date_night: OutingData


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()

	girls_day_out = load("res://data/outings/girls_day_out.tres") as OutingData
	date_night = load("res://data/outings/date_night.tres") as OutingData


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()


func test_schedule_outing_success() -> void:
	var dep: int = GameClock.now_minutes + 120
	var success: bool = OutingManager.schedule(girls_day_out, dep, "Chloe")
	assert_true(success, "Scheduling should succeed")

	var scheduled: Array = OutingManager.get_scheduled()
	assert_eq(scheduled.size(), 1)
	assert_eq(scheduled[0]["departure_min"], dep)
	assert_eq(scheduled[0]["partner_ref"], "Chloe")


func test_schedule_emits_eventbus_signal() -> void:
	watch_signals(EventBus)
	var dep: int = GameClock.now_minutes + 150
	var success: bool = OutingManager.schedule(girls_day_out, dep, "Chloe")
	assert_true(success)

	assert_signal_emitted(EventBus, "outing_scheduled")
	var params: Array = get_signal_parameters(EventBus, "outing_scheduled")
	assert_eq(params[1], dep)
	assert_eq(params[2], "Chloe")


func test_schedule_rejects_past_or_current_time() -> void:
	assert_false(OutingManager.schedule(girls_day_out, GameClock.now_minutes))
	assert_false(OutingManager.schedule(girls_day_out, GameClock.now_minutes - 10))


func test_schedule_rejects_overlapping_window() -> void:
	# Outing 1: dep = 600, prep = 90 -> window [510, 780]
	var ok1: bool = OutingManager.schedule(girls_day_out, 600, "Chloe")
	assert_true(ok1)

	# Outing 2: dep = 650, prep = 120 -> window [530, 830], overlaps with [510, 780]
	var ok2: bool = OutingManager.schedule(date_night, 650, "Liam")
	assert_false(ok2, "Overlapping outing schedule must be rejected")

	# Outing 3: dep = 900, prep = 90 -> window [810, 1080], no overlap with [510, 780]
	var ok3: bool = OutingManager.schedule(girls_day_out, 900, "Chloe")
	assert_true(ok3, "Non-overlapping outing schedule should be accepted")


func test_prep_starts_via_minute_ticked() -> void:
	# Wake minute is 420. Departure at 600. Prep window 90 min -> prep start at 510.
	watch_signals(OutingManager)
	var ok: bool = OutingManager.schedule(girls_day_out, 600, "Chloe")
	assert_true(ok)
	assert_false(OutingManager.is_prep_active())

	# Advance to 509
	GameClock.advance_minutes(509 - GameClock.now_minutes)
	assert_false(OutingManager.is_prep_active())
	assert_signal_not_emitted(OutingManager, "prep_started")

	# Advance 1 minute to 510 -> prep starts
	GameClock.advance_minutes(1)
	assert_true(OutingManager.is_prep_active())
	assert_eq(OutingManager.active_outing, girls_day_out)
	assert_signal_emitted(OutingManager, "prep_started")
	assert_true(GameClock.has_countdown(&"outing_departure_deadline"))


func test_prep_starts_via_skip() -> void:
	watch_signals(OutingManager)
	OutingManager.schedule(girls_day_out, 600, "Chloe")

	# Skip directly across prep start (420 -> 530)
	GameClock.skip(110)
	assert_true(OutingManager.is_prep_active())
	assert_eq(OutingManager.active_outing, girls_day_out)
	assert_signal_emitted(OutingManager, "prep_started")


func test_departure_deadline_reached_signal() -> void:
	watch_signals(OutingManager)
	OutingManager.schedule(girls_day_out, 600, "Chloe")

	# Advance clock past prep start into prep
	GameClock.advance_minutes(90)  # now 510, prep starts
	assert_signal_not_emitted(OutingManager, "departure_deadline_reached")

	# Advance clock to departure deadline 600
	GameClock.advance_minutes(90)  # now 600
	assert_signal_emitted(OutingManager, "departure_deadline_reached")


func test_get_checklist_during_prep() -> void:
	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(90)  # now 510, prep active

	var checklist: Array[Dictionary] = OutingManager.get_checklist()
	assert_eq(checklist.size(), 4)
	for item: Dictionary in checklist:
		assert_true(item.has("label"))
		assert_true(item.has("score"))
		assert_true(item.has("passed"))
		assert_true(item["score"] >= 0.0 and item["score"] <= 1.0)


func test_affinity_tracking() -> void:
	assert_eq(OutingManager.get_affinity("Chloe"), 0)
	OutingManager.set_affinity("Chloe", 20)
	assert_eq(OutingManager.get_affinity("Chloe"), 20)
	OutingManager.add_affinity("Chloe", 15)
	assert_eq(OutingManager.get_affinity("Chloe"), 35)
	OutingManager.add_affinity("Chloe", -10)
	assert_eq(OutingManager.get_affinity("Chloe"), 25)


func test_to_dict_and_from_dict_json_round_trip_mid_prep() -> void:
	OutingManager.set_affinity("Liam", 10)
	OutingManager.schedule(girls_day_out, 600, "Chloe")

	# Advance clock to mid-prep (540, halfway between 510 and 600)
	GameClock.advance_minutes(120)
	assert_true(OutingManager.is_prep_active())
	assert_true(GameClock.has_countdown(&"outing_departure_deadline"))

	var saved_data: Dictionary = OutingManager.to_dict()

	# Verify JSON serialization safety
	var json_str: String = JSON.stringify(saved_data)
	assert_false(json_str.is_empty())
	var parsed: Variant = JSON.parse_string(json_str)
	assert_not_null(parsed)
	assert_true(parsed is Dictionary)

	# Reset and restore
	OutingManager.reset_state()
	assert_false(OutingManager.is_prep_active())
	assert_false(GameClock.has_countdown(&"outing_departure_deadline"))

	OutingManager.from_dict(parsed as Dictionary)
	assert_true(OutingManager.is_prep_active())
	assert_eq(OutingManager.active_outing.id, &"girls_day_out")
	assert_eq(OutingManager.active_departure_min, 600)
	assert_eq(OutingManager.active_partner_ref, "Chloe")
	assert_eq(OutingManager.get_affinity("Liam"), 10)
	assert_true(GameClock.has_countdown(&"outing_departure_deadline"))
	assert_eq(GameClock.remaining(&"outing_departure_deadline"), 60)
