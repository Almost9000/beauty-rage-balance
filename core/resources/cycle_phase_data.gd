class_name CyclePhaseData
extends Resource

@export var phase: Enums.CyclePhase = Enums.CyclePhase.MENSTRUAL
@export var display_name: String = ""
@export var default_days: int = 1
@export var length_days: Vector2i = Vector2i(1, 1)
@export var modifiers: Array[StatModifier] = []
@export var symptom_tags: Array[StringName] = []
@export var narrative_tags: Array[StringName] = []
@export_multiline var description: String = ""

func is_valid() -> bool:
	if not Enums.CyclePhase.values().has(phase):
		return false
	if default_days < 1:
		return false
	if length_days.x < 1 or length_days.y < length_days.x:
		return false
	if default_days < length_days.x or default_days > length_days.y:
		return false
	for mod: StatModifier in modifiers:
		if not mod or not mod.is_valid():
			return false
	return true

func has_tag(tag: StringName) -> bool:
	return symptom_tags.has(tag) or narrative_tags.has(tag)
