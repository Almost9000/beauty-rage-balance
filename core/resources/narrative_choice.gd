class_name NarrativeChoice
extends Resource

@export var stance: Enums.Stance = Enums.Stance.PLACATE
@export var text: String = ""
@export var modifiers: Array[StatModifier] = []
@export var set_flags: Dictionary = {}
@export var follow_up: Resource = null # NarrativeEvent


func _init(p_stance: Enums.Stance = Enums.Stance.PLACATE, p_text: String = "") -> void:
	stance = p_stance
	text = p_text
