class_name StatModifier
extends Resource

const STAT_MAX: float = 100.0

@export var stat: Enums.Stat = Enums.Stat.SANITY
@export var kind: Enums.ModifierKind = Enums.ModifierKind.INSTANT
@export var value: float = 0.0
@export var source_id: StringName = &""
@export var duration_min: int = -1
@export var label: String = ""

func is_valid() -> bool:
	if source_id.is_empty():
		return false
	if not Enums.Stat.values().has(stat):
		return false
	if not Enums.ModifierKind.values().has(kind):
		return false
	if duration_min < -1:
		return false
	if kind == Enums.ModifierKind.CAP and (value < 0.0 or value > STAT_MAX):
		return false
	if kind == Enums.ModifierKind.RATE_MUL and value < 0.0:
		return false
	return true

func scaled(k: float) -> StatModifier:
	var copy: StatModifier = duplicate() as StatModifier
	match kind:
		Enums.ModifierKind.INSTANT, Enums.ModifierKind.RATE_ADD:
			copy.value = value * k
		Enums.ModifierKind.RATE_MUL:
			copy.value = 1.0 + (value - 1.0) * k
		Enums.ModifierKind.CAP:
			copy.value = STAT_MAX - (STAT_MAX - value) * k
	return copy

func describe() -> String:
	var stat_key: Variant = Enums.Stat.find_key(stat)
	var stat_name: String = tr(String(stat_key).capitalize()) if stat_key != null else "Unknown"

	match kind:
		Enums.ModifierKind.INSTANT:
			var sign_str: String = "+" if value >= 0.0 else "−"
			return "%s %s%s" % [stat_name, sign_str, _format_value(absf(value))]
		Enums.ModifierKind.RATE_ADD:
			var sign_str: String = "+" if value >= 0.0 else "−"
			return "%s %s%s/h" % [stat_name, sign_str, _format_value(absf(value))]
		Enums.ModifierKind.RATE_MUL:
			return "%s gain ×%s" % [stat_name, _format_value(value)]
		Enums.ModifierKind.CAP:
			return "%s cap %s" % [stat_name, _format_value(value)]
		_:
			return "%s %s" % [stat_name, _format_value(value)]

func to_dict() -> Dictionary:
	return {
		"stat": int(stat),
		"kind": int(kind),
		"value": value,
		"source_id": String(source_id),
		"duration_min": duration_min,
		"label": label,
	}

static func from_dict(data: Dictionary) -> StatModifier:
	var mod: StatModifier = StatModifier.new()
	if data.has("stat"):
		mod.stat = int(data["stat"]) as Enums.Stat
	if data.has("kind"):
		mod.kind = int(data["kind"]) as Enums.ModifierKind
	if data.has("value"):
		mod.value = float(data["value"])
	if data.has("source_id"):
		mod.source_id = StringName(data["source_id"])
	if data.has("duration_min"):
		mod.duration_min = int(data["duration_min"])
	if data.has("label"):
		mod.label = String(data["label"])
	return mod

static func _format_value(v: float) -> String:
	var s: String = "%.2f" % v
	while s.ends_with("0"):
		s = s.trim_suffix("0")
	if s.ends_with("."):
		s = s.trim_suffix(".")
	if s.is_empty():
		return "0"
	return s
