class_name NarrativeEvent
extends Resource

@export var id: StringName = &""
@export var conditions: Array[NarrativeCondition] = []
@export var once: bool = false
@export var priority: int = 0
@export var channel: StringName = &"IN_PERSON" # &"IN_PERSON", &"PHONE_CALL"
@export var speaker: String = ""
@export var lines: Array[String] = []
@export var choices: Array[NarrativeChoice] = []


func evaluate_conditions(context: Dictionary = {}) -> bool:
	for cond: NarrativeCondition in conditions:
		if cond and not cond.evaluate(context):
			return false
	return true
