class_name Interactable
extends Area3D

signal interacted(actor: Node)

@export var prompt_text: String = ""
@export var enabled: bool = true

func _init() -> void:
	collision_layer = 4
	collision_mask = 0

func interact(actor: Node) -> void:
	if not enabled:
		return
	interacted.emit(actor)
