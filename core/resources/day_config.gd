class_name DayConfig
extends Resource

const DEFAULT_CONFIG_PATH: String = "res://data/config/day_config.tres"

@export var wake_minute: int = 480               # 08:00
@export var pressure_minute: int = 840           # 14:00
@export var bedtime_earliest_minute: int = 1260  # 21:00
@export var passout_minute_of_day: int = 120     # 02:00 next day
@export var sleep_health_bonus: float = 30.0
@export var sleep_sanity_bonus: float = 20.0
@export var passout_health_penalty: float = -20.0
@export var passout_wake_minute: int = 600       # 10:00
@export var default_outing_departure_minute: int = 960 # 16:00


static func load_default() -> DayConfig:
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		var res: Resource = load(DEFAULT_CONFIG_PATH)
		if res is DayConfig:
			return res.duplicate() as DayConfig
	return DayConfig.new()
