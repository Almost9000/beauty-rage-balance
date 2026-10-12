class_name DogBowls
extends Node3D

signal bowls_filled()
signal food_consumed()

@export var max_portions: int = 2
@export var portions_remaining: int = 0:
	set(val):
		portions_remaining = clampi(val, 0, max_portions)
		has_food = portions_remaining > 0
		_update_visuals()

var has_food: bool = false

@onready var interactable: Interactable = get_node_or_null("Interactable") as Interactable
@onready var food_mesh: Node3D = get_node_or_null("FoodMesh") as Node3D


func _ready() -> void:
	if not is_in_group(&"dog_bowls"):
		add_to_group(&"dog_bowls")

	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	_update_visuals()


func _on_interacted(_actor: Node) -> void:
	fill()


func fill() -> void:
	portions_remaining = max_portions
	bowls_filled.emit()


func consume_food() -> bool:
	if not has_food:
		return false
	portions_remaining -= 1
	food_consumed.emit()
	return true


func is_food_available() -> bool:
	return has_food


func _update_visuals() -> void:
	if food_mesh:
		food_mesh.visible = has_food

	if interactable:
		if has_food:
			interactable.prompt_text = "Bowls full"
			interactable.enabled = false
		else:
			interactable.prompt_text = "Fill dog bowls"
			interactable.enabled = true
