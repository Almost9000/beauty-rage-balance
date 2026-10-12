class_name IdleState
extends State

@export var min_duration: float = 2.0
@export var max_duration: float = 5.0

var _timer: float = 0.0
var _target_duration: float = 3.0


func enter(_msg: Dictionary = {}) -> void:
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()
	_target_duration = randf_range(min_duration, max_duration)
	_timer = 0.0


func update(delta: float) -> void:
	_timer += delta
	if _timer >= _target_duration:
		_decide_next()


func _decide_next() -> void:
	var dog: Node = _get_dog()
	if not dog:
		return

	var needs: Dictionary = dog.needs if "needs" in dog else {}
	var profile: DogProfile = dog.profile if "profile" in dog else null
	if not profile:
		return

	var context: Dictionary = {
		"current_state": &"Idle",
		"has_food": dog.is_food_available() if dog.has_method("is_food_available") else false,
	}

	# Decide next behavior: check needs first
	var next_state: StringName = DogBrain.evaluate_next_state(needs, profile, context)
	if next_state != &"Idle":
		transition_requested.emit(next_state, {})
		return

	# Randomly pick wander or follow if player is nearby
	var r: float = randf()
	if r < 0.6:
		transition_requested.emit(&"Wander", {})
	elif r < 0.85 and dog.has_method("get_player") and dog.get_player() != null:
		transition_requested.emit(&"Follow", {})
	else:
		_timer = 0.0
		_target_duration = randf_range(min_duration, max_duration)


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
