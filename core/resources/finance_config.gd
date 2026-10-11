class_name FinanceConfig
extends Resource

const DEFAULT_CONFIG_PATH: String = "res://data/config/finance_config.tres"

@export var starting_cents: int = 25000
@export var rent_cents: int = 60000
@export var rent_interval_days: int = 30
@export var first_rent_day: int = 30
@export var income_cents: int = 35000
@export var income_interval_days: int = 7
@export var debt_modifier: StatModifier = null

func get_debt_modifier() -> StatModifier:
	if debt_modifier != null:
		return debt_modifier.duplicate() as StatModifier
	var mod: StatModifier = StatModifier.new()
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = -1.0
	mod.source_id = &"finance_debt"
	mod.duration_min = -1
	mod.label = "Debt stress"
	return mod

static func load_default() -> FinanceConfig:
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		var res: Resource = load(DEFAULT_CONFIG_PATH)
		if res is FinanceConfig:
			return res.duplicate() as FinanceConfig
	return FinanceConfig.new()
