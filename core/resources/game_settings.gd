class_name GameSettings
extends Resource

const DEFAULT_SETTINGS_PATH: String = "res://data/settings/default_game_settings.tres"

static var _current_instance: GameSettings = null

@export_range(12, 40) var cycle_length_days: int = 28:
	set(val):
		var clamped: int = clampi(val, 12, 40)
		if cycle_length_days != clamped:
			cycle_length_days = clamped
			emit_changed()

@export_range(0.0, 1.0) var symptom_intensity: float = 1.0:
	set(val):
		var clamped: float = clampf(val, 0.0, 1.0)
		if not is_equal_approx(symptom_intensity, clamped):
			symptom_intensity = clamped
			emit_changed()

@export_range(0.01, 60.0) var minutes_per_real_second: float = 1.0:
	set(val):
		var clamped: float = maxf(0.01, val)
		if not is_equal_approx(minutes_per_real_second, clamped):
			minutes_per_real_second = clamped
			emit_changed()

@export_range(0, 1439) var wake_minute_of_day: int = 420:
	set(val):
		var clamped: int = clampi(val, 0, 1439)
		if wake_minute_of_day != clamped:
			wake_minute_of_day = clamped
			emit_changed()

static func current() -> GameSettings:
	if _current_instance == null:
		if ResourceLoader.exists(DEFAULT_SETTINGS_PATH):
			var loaded_res: Resource = load(DEFAULT_SETTINGS_PATH)
			if loaded_res is GameSettings:
				_current_instance = loaded_res.duplicate() as GameSettings
		if _current_instance == null:
			_current_instance = GameSettings.new()
	return _current_instance

static func reset_current() -> void:
	_current_instance = null

func to_dict() -> Dictionary:
	return {
		"cycle_length_days": cycle_length_days,
		"symptom_intensity": symptom_intensity,
		"minutes_per_real_second": minutes_per_real_second,
		"wake_minute_of_day": wake_minute_of_day,
	}

func from_dict(data: Dictionary, _version: int = 1) -> void:
	if data.has("cycle_length_days"):
		cycle_length_days = int(data["cycle_length_days"])
	if data.has("symptom_intensity"):
		symptom_intensity = float(data["symptom_intensity"])
	if data.has("minutes_per_real_second"):
		minutes_per_real_second = float(data["minutes_per_real_second"])
	if data.has("wake_minute_of_day"):
		wake_minute_of_day = int(data["wake_minute_of_day"])
