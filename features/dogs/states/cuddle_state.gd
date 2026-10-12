class_name CuddleState
extends State

@export var duration: float = 2.5

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()


func update(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		transition_requested.emit(&"Idle", {})


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
