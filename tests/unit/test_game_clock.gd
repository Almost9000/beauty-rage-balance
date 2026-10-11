extends GutTest

func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()

func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()

func test_default_state_and_helpers() -> void:
	assert_eq(GameClock.now_minutes, 420, "New game starts at wake_minute_of_day (420)")
	assert_eq(GameClock.day, 1, "Initial day should be 1")
	assert_eq(GameClock.hour, 7, "Hour for minute 420 should be 7")
	assert_eq(GameClock.minute_of_day, 420, "Minute of day should be 420")
	assert_eq(GameClock.format_time(), "07:00", "Default format_time should be 07:00")
	assert_eq(GameClock.format_time(425), "07:05", "format_time(425) should be 07:05")
	assert_eq(GameClock.format_time(0), "00:00", "format_time(0) should be 00:00")
	assert_eq(GameClock.format_time(1439), "23:59", "format_time(1439) should be 23:59")
	assert_false(GameClock.is_paused(), "Clock should start unpaused")
	assert_false(GameClock.is_skipping, "Clock should not start in skipping state")

func test_rollover_at_minute_1440_emits_day_started_once() -> void:
	GameClock.now_minutes = 1438

	var day_started_args: Array[int] = []
	GameClock.day_started.connect(func(day: int) -> void: day_started_args.append(day))

	var minute_ticks: Array[int] = []
	GameClock.minute_ticked.connect(func(now: int) -> void: minute_ticks.append(now))

	var hour_changes: Array[int] = []
	GameClock.hour_changed.connect(func(h: int) -> void: hour_changes.append(h))

	# Advance 1 minute -> 1439 (Day 1, 23:59)
	GameClock.advance_minutes(1)
	assert_eq(GameClock.now_minutes, 1439)
	assert_eq(GameClock.day, 1)
	assert_eq(day_started_args.size(), 0, "Day 2 not started yet at 1439")
	assert_eq(minute_ticks, [1439])
	assert_eq(hour_changes.size(), 0)

	# Advance 1 minute -> 1440 (Day 2, 00:00 rollover)
	GameClock.advance_minutes(1)
	assert_eq(GameClock.now_minutes, 1440)
	assert_eq(GameClock.day, 2)
	assert_eq(day_started_args, [2], "Rollover at 1440 emits day_started(2) once")
	assert_eq(minute_ticks, [1439, 1440])
	assert_eq(hour_changes, [0], "Hour changed to 0 at midnight")

	# Advance 1 more minute -> 1441 (Day 2, 00:01)
	GameClock.advance_minutes(1)
	assert_eq(GameClock.now_minutes, 1441)
	assert_eq(day_started_args.size(), 1, "day_started should not fire again on 1441")

func test_skip_multiple_days_emits_day_started_and_contiguous_segments() -> void:
	GameClock.now_minutes = 0 # Start at midnight of day 1 for 3 full days test

	var days_emitted: Array[int] = []
	GameClock.day_started.connect(func(d: int) -> void: days_emitted.append(d))

	var segments: Array[Dictionary] = []
	GameClock.time_skipped.connect(func(from_min: int, to_min: int) -> void:
		segments.append({"from": from_min, "to": to_min})
	)

	var skip_started_called: Array[int] = []
	GameClock.skip_started.connect(func(mins: int) -> void: skip_started_called.append(mins))

	var skip_finished_count: Array[int] = [0]
	GameClock.skip_finished.connect(func() -> void: skip_finished_count[0] += 1)

	GameClock.skip(3 * 1440)

	assert_eq(skip_started_called, [3 * 1440], "skip_started emitted with total minutes")
	assert_eq(skip_finished_count[0], 1, "skip_finished emitted exactly once")
	assert_eq(days_emitted, [2, 3, 4], "skip(3 * 1440) emits three day_started in order [2, 3, 4]")
	assert_eq(GameClock.now_minutes, 4320)
	assert_eq(GameClock.day, 4)

	# Check contiguous segments
	assert_eq(segments.size(), 3, "Three midnight-bound segments should be emitted")
	assert_eq(segments[0]["from"], 0)
	assert_eq(segments[0]["to"], 1440)
	assert_eq(segments[1]["from"], 1440)
	assert_eq(segments[1]["to"], 2880)
	assert_eq(segments[2]["from"], 2880)
	assert_eq(segments[2]["to"], 4320)

	# Validate perfect coverage from 0 to 4320
	for i: int in range(segments.size()):
		if i > 0:
			assert_eq(segments[i]["from"], segments[i - 1]["to"], "Segment %d must be contiguous with %d" % [i, i - 1])

func test_countdown_via_advance_minutes() -> void:
	var fired: Array[Dictionary] = []
	GameClock.countdown_finished.connect(func(id: StringName, payload: Dictionary) -> void:
		fired.append({"id": id, "payload": payload})
	)

	GameClock.create_countdown(&"prep_alert", 422, {"note": "get ready"})
	assert_true(GameClock.has_countdown(&"prep_alert"))
	assert_eq(GameClock.remaining(&"prep_alert"), 2)

	GameClock.advance_minutes(1)
	assert_eq(GameClock.now_minutes, 421)
	assert_eq(GameClock.remaining(&"prep_alert"), 1)
	assert_eq(fired.size(), 0)

	GameClock.advance_minutes(1)
	assert_eq(GameClock.now_minutes, 422)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0]["id"], &"prep_alert")
	assert_eq(fired[0]["payload"]["note"], "get ready")
	assert_false(GameClock.has_countdown(&"prep_alert"), "Countdown should be gone after firing")
	assert_eq(GameClock.remaining(&"prep_alert"), -1)

	# Advancing further should not re-fire
	GameClock.advance_minutes(5)
	assert_eq(fired.size(), 1, "Countdown must fire exactly once")

func test_countdown_via_skip() -> void:
	var fired: Array[Dictionary] = []
	GameClock.countdown_finished.connect(func(id: StringName, payload: Dictionary) -> void:
		fired.append({"id": id, "payload": payload})
	)

	GameClock.create_countdown(&"flash_sale", 500, {"item": "jacket"})
	assert_true(GameClock.has_countdown(&"flash_sale"))
	assert_eq(GameClock.remaining(&"flash_sale"), 80)

	GameClock.skip(100) # From 420 to 520
	assert_eq(GameClock.now_minutes, 520)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0]["id"], &"flash_sale")
	assert_eq(fired[0]["payload"]["item"], "jacket")
	assert_false(GameClock.has_countdown(&"flash_sale"), "Countdown is gone after skip")
	assert_eq(GameClock.remaining(&"flash_sale"), -1)

func test_event_order_at_boundary() -> void:
	# Test exact order: time_skipped -> day_started -> countdown_finished (sorted by deadline then id)
	GameClock.now_minutes = 1400

	GameClock.create_countdown(&"cd_z", 1440, {"label": "z"})
	GameClock.create_countdown(&"cd_a", 1440, {"label": "a"})
	GameClock.create_countdown(&"cd_early", 1420, {"label": "early"})

	var event_log: Array[String] = []

	GameClock.time_skipped.connect(func(from_min: int, to_min: int) -> void:
		event_log.append("time_skipped:%d->%d" % [from_min, to_min])
	)
	GameClock.day_started.connect(func(day: int) -> void:
		event_log.append("day_started:%d" % day)
	)
	GameClock.countdown_finished.connect(func(id: StringName, _payload: Dictionary) -> void:
		event_log.append("countdown_finished:%s" % str(id))
	)

	GameClock.skip(100) # From 1400 to 1500

	var expected_order: Array[String] = [
		"time_skipped:1400->1420",
		"countdown_finished:cd_early",
		"time_skipped:1420->1440",
		"day_started:2",
		"countdown_finished:cd_a",
		"countdown_finished:cd_z",
		"time_skipped:1440->1500",
	]

	assert_eq(event_log, expected_order, "Event sequence at boundary must be time_skipped -> day_started -> countdowns sorted")

func test_pause_reference_counting_and_real_time_input() -> void:
	var pause_events: Array[bool] = []
	GameClock.paused_changed.connect(func(p: bool) -> void: pause_events.append(p))

	assert_false(GameClock.is_paused())

	# Pause reason A
	GameClock.pause(&"dialogue")
	assert_true(GameClock.is_paused())
	assert_true(GameClock.has_pause_reason(&"dialogue"))
	assert_eq(pause_events, [true])

	# Duplicate pause reason A (refcount = 2)
	GameClock.pause(&"dialogue")
	assert_true(GameClock.is_paused())
	assert_eq(pause_events.size(), 1, "paused_changed should not re-emit when already paused")

	# Pause reason B
	GameClock.pause(&"transition")
	assert_true(GameClock.is_paused())
	assert_true(GameClock.has_pause_reason(&"transition"))
	assert_eq(pause_events.size(), 1)

	# Verify real-time input does not advance while paused
	var start_minutes: int = GameClock.now_minutes
	GameClock.advance_real_time(120.0) # 2 real seconds
	assert_eq(GameClock.now_minutes, start_minutes, "Paused clock does not advance from real-time input")

	# Resume reason A once (refcount goes from 2 to 1)
	GameClock.resume(&"dialogue")
	assert_true(GameClock.is_paused(), "Still paused: dialogue has 1 ref and transition is active")
	assert_eq(pause_events.size(), 1)

	# Resume reason A second time (dialogue cleared, transition remains)
	GameClock.resume(&"dialogue")
	assert_false(GameClock.has_pause_reason(&"dialogue"))
	assert_true(GameClock.is_paused(), "Still paused: transition is active")
	assert_eq(pause_events.size(), 1)

	# Resume reason B
	GameClock.resume(&"transition")
	assert_false(GameClock.has_pause_reason(&"transition"))
	assert_false(GameClock.is_paused(), "Unpaused after all reasons resumed")
	assert_eq(pause_events, [true, false])

	# Advance real time while unpaused
	GameClock.advance_real_time(60.0) # 60 seconds with 1.0 min/sec = 60 minutes
	assert_eq(GameClock.now_minutes, start_minutes + 60, "Clock advances normally after unpausing")

func test_nested_skip_rejected() -> void:
	var nested_skip_attempted: Array[bool] = [false]
	var nested_minutes_before: int = 0

	GameClock.time_skipped.connect(func(_from_min: int, _to_min: int) -> void:
		if not nested_skip_attempted[0]:
			nested_skip_attempted[0] = true
			nested_minutes_before = GameClock.now_minutes
			# Attempt nested skip inside handler
			GameClock.skip(50)
	)

	GameClock.skip(100)

	assert_true(nested_skip_attempted[0], "Nested skip handler executed")
	assert_eq(GameClock.now_minutes, 420 + 100, "Nested skip was rejected, only original skip completed")

func test_to_dict_and_from_dict_json_round_trip() -> void:
	GameClock.now_minutes = 850
	GameClock.create_countdown(&"sale", 900, {"item": "shoes", "discount": 20})
	GameClock.create_countdown(&"delivery", 1200, {"order_id": 123})

	var dict: Dictionary = GameClock.to_dict()
	assert_eq(dict["now_minutes"], 850)
	assert_true(dict.has("countdowns"))
	assert_true((dict["countdowns"] as Dictionary).has("sale"))

	# Stringify and parse JSON
	var json_str: String = JSON.stringify(dict)
	assert_gt(json_str.length(), 0)

	var parsed: Variant = JSON.parse_string(json_str)
	assert_not_null(parsed)
	assert_true(parsed is Dictionary)

	# Reset state and verify cleared
	GameClock.reset_state()
	assert_eq(GameClock.now_minutes, 420)
	assert_false(GameClock.has_countdown(&"sale"))

	# Restore from parsed dict
	GameClock.from_dict(parsed as Dictionary)
	assert_eq(GameClock.now_minutes, 850)
	assert_true(GameClock.has_countdown(&"sale"))
	assert_eq(GameClock.remaining(&"sale"), 50)
	assert_eq(GameClock.get_countdown(&"sale")["payload"]["item"], "shoes")
	assert_true(GameClock.has_countdown(&"delivery"))
	assert_eq(GameClock.remaining(&"delivery"), 350)

func test_countdown_replace_and_cancel() -> void:
	GameClock.create_countdown(&"timer", 500)
	assert_true(GameClock.has_countdown(&"timer"))
	assert_eq(GameClock.remaining(&"timer"), 80)

	# Replace with same id
	GameClock.create_countdown(&"timer", 600, {"updated": true})
	assert_true(GameClock.has_countdown(&"timer"))
	assert_eq(GameClock.remaining(&"timer"), 180)
	assert_eq(GameClock.get_countdown(&"timer")["payload"]["updated"], true)

	# Cancel countdown
	var cancelled: bool = GameClock.cancel_countdown(&"timer")
	assert_true(cancelled)
	assert_false(GameClock.has_countdown(&"timer"))
	assert_eq(GameClock.remaining(&"timer"), -1)

	# Cancel non-existent
	var cancel_again: bool = GameClock.cancel_countdown(&"timer")
	assert_false(cancel_again)

func test_time_scale_real_time_accumulation() -> void:
	GameClock.time_scale = 10.0
	# 6.0 real seconds * 1.0 min/sec * 10.0 time_scale = 60.0 game minutes
	GameClock.advance_real_time(6.0)
	assert_eq(GameClock.now_minutes, 480)

func test_scene_router_pause_reason_integration() -> void:
	SceneRouter.reset_state()
	assert_false(GameClock.has_pause_reason(&"transition"))
	GameClock.pause(&"transition")
	assert_true(GameClock.is_paused())
	assert_true(GameClock.has_pause_reason(&"transition"))
	GameClock.resume(&"transition")
	assert_false(GameClock.is_paused())
	assert_false(GameClock.has_pause_reason(&"transition"))
