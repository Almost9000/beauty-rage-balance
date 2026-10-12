class_name EatState
extends State

@export var eat_duration: float = 2.0

var _is_eating: bool = false
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_is_eating = false
	_timer = 0.0

	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	var bowls: Node3D = dog.get_bowls() if dog.has_method("get_bowls") else null
	if not bowls:
		transition_requested.emit(&"Idle", {})
		return

	dog.navigate_to(bowls.global_position)


func physics_update(delta: float) -> void:
	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	var bowls: Node3D = dog.get_bowls() if dog.has_method("get_bowls") else null
	if not bowls:
		transition_requested.emit(&"Idle", {})
		return

	if not _is_eating:
		var dist: float = dog.global_position.distance_to(bowls.global_position)
		if dist <= 1.0:
			dog.stop()
			if dog.has_method("look_towards"):
				dog.look_towards(bowls.global_position, delta)
			_is_eating = true
		else:
			dog.navigate_to(bowls.global_position)
			if dog.has_method("step_movement"):
				dog.step_movement(delta)
	else:
		_timer += delta
		if _timer >= eat_duration:
			if bowls.has_method("consume_food"):
				bowls.consume_food()
			if dog.has_method("feed"):
				dog.feed()
			transition_requested.emit(&"Idle", {})


func exit() -> void:
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
