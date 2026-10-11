class_name StatusConfig
extends Resource

const DEFAULT_CONFIG_PATH: String = "res://data/config/status_config.tres"

# First-guess values: to balance at M1 audit
@export var sanity_start: float = 80.0
@export var sanity_base_rate: float = -1.5 # points per game hour

@export var health_start: float = 90.0
@export var health_base_rate: float = -1.0 # points per game hour

@export var hygiene_start: float = 80.0
@export var hygiene_base_rate: float = -2.0 # points per game hour

@export var rage_start: float = 10.0
@export var rage_base_rate: float = -0.5 # points per game hour

func get_start_value(stat: Enums.Stat) -> float:
	match stat:
		Enums.Stat.SANITY:
			return sanity_start
		Enums.Stat.HEALTH:
			return health_start
		Enums.Stat.HYGIENE:
			return hygiene_start
		Enums.Stat.RAGE:
			return rage_start
		_:
			return 0.0

func get_base_rate(stat: Enums.Stat) -> float:
	match stat:
		Enums.Stat.SANITY:
			return sanity_base_rate
		Enums.Stat.HEALTH:
			return health_base_rate
		Enums.Stat.HYGIENE:
			return hygiene_base_rate
		Enums.Stat.RAGE:
			return rage_base_rate
		_:
			return 0.0

static func load_default() -> StatusConfig:
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		var res: Resource = load(DEFAULT_CONFIG_PATH)
		if res is StatusConfig:
			return res.duplicate() as StatusConfig
	return StatusConfig.new()
