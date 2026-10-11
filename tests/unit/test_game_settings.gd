extends GutTest

func before_each() -> void:
	GameSettings.reset_current()

func after_each() -> void:
	GameSettings.reset_current()

func test_default_values() -> void:
	var settings: GameSettings = GameSettings.new()
	assert_eq(settings.cycle_length_days, 28)
	assert_almost_eq(settings.symptom_intensity, 1.0, 0.0001)
	assert_almost_eq(settings.minutes_per_real_second, 1.0, 0.0001)
	assert_eq(settings.wake_minute_of_day, 420)

func test_clamping() -> void:
	var settings: GameSettings = GameSettings.new()

	settings.cycle_length_days = 5
	assert_eq(settings.cycle_length_days, 12, "cycle_length_days below minimum should clamp to 12")

	settings.cycle_length_days = 50
	assert_eq(settings.cycle_length_days, 40, "cycle_length_days above maximum should clamp to 40")

	settings.symptom_intensity = -0.5
	assert_almost_eq(settings.symptom_intensity, 0.0, 0.0001, "symptom_intensity below 0 should clamp to 0.0")

	settings.symptom_intensity = 2.0
	assert_almost_eq(settings.symptom_intensity, 1.0, 0.0001, "symptom_intensity above 1 should clamp to 1.0")

	settings.minutes_per_real_second = -1.0
	assert_almost_eq(settings.minutes_per_real_second, 0.01, 0.0001, "minutes_per_real_second <= 0 should clamp to 0.01")

	settings.wake_minute_of_day = -10
	assert_eq(settings.wake_minute_of_day, 0, "wake_minute_of_day below 0 should clamp to 0")

	settings.wake_minute_of_day = 2000
	assert_eq(settings.wake_minute_of_day, 1439, "wake_minute_of_day above 1439 should clamp to 1439")

func test_changed_signal_emitted() -> void:
	var settings: GameSettings = GameSettings.new()
	watch_signals(settings)

	settings.cycle_length_days = 30
	assert_signal_emitted(settings, "changed", "Modifying cycle_length_days should emit changed")

	settings.symptom_intensity = 0.8
	assert_signal_emit_count(settings, "changed", 2, "Modifying symptom_intensity should emit changed")

	settings.minutes_per_real_second = 2.0
	assert_signal_emit_count(settings, "changed", 3, "Modifying minutes_per_real_second should emit changed")

	settings.wake_minute_of_day = 480
	assert_signal_emit_count(settings, "changed", 4, "Modifying wake_minute_of_day should emit changed")

	# Setting identical value should not emit changed
	settings.cycle_length_days = 30
	assert_signal_emit_count(settings, "changed", 4, "Setting identical value should not emit changed")

func test_serialization_dict() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.cycle_length_days = 32
	settings.symptom_intensity = 0.75
	settings.minutes_per_real_second = 0.5
	settings.wake_minute_of_day = 450

	var dict: Dictionary = settings.to_dict()
	assert_eq(dict["cycle_length_days"], 32)
	assert_almost_eq(float(dict["symptom_intensity"]), 0.75, 0.0001)
	assert_almost_eq(float(dict["minutes_per_real_second"]), 0.5, 0.0001)
	assert_eq(dict["wake_minute_of_day"], 450)

	var restored: GameSettings = GameSettings.new()
	restored.from_dict(dict)
	assert_eq(restored.cycle_length_days, 32)
	assert_almost_eq(restored.symptom_intensity, 0.75, 0.0001)
	assert_almost_eq(restored.minutes_per_real_second, 0.5, 0.0001)
	assert_eq(restored.wake_minute_of_day, 450)

func test_current_singleton_and_reset() -> void:
	var s1: GameSettings = GameSettings.current()
	assert_not_null(s1)
	assert_eq(s1.cycle_length_days, 28)

	s1.cycle_length_days = 35
	var s2: GameSettings = GameSettings.current()
	assert_eq(s2.cycle_length_days, 35, "current() should return same active instance")

	GameSettings.reset_current()
	var s3: GameSettings = GameSettings.current()
	assert_eq(s3.cycle_length_days, 28, "reset_current() should reload fresh defaults")
