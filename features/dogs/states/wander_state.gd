class_name WanderState
extends State

@export var max_wander_time: float = 8.0

var _timer: float = 0.0
var _destination: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	if dog.has_method("get_random_nav_point"):
		_destination = dog.get_random_nav_point()
	else:
		_destination = dog.global_position

	if dog.has_method("navigate_to"):
		dog.navigate_to(_destination)


func physics_update(delta: float) -> void:
	_timer += delta
	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	# Urgent needs interrupt wandering
	var needs: Dictionary = dog.needs if "needs" in dog else {}
	var profile: DogProfile = dog.profile if "profile" in dog else null
	if profile:
		var context: Dictionary = {
			"current_state": &"Wander",
			"has_food": dog.is_food_available() if dog.has_method("is_food_available") else false,
		}
		var urgent_state: StringName = DogBrain.evaluate_next_state(needs, profile, context)
		if urgent_state != &"Idle" and urgent_state != &"Wander":
			transition_requested.emit(urgent_state, {})
			return

	if _timer >= max_wander_time:
		transition_requested.emit(&"Idle", {})
		return

	if dog.has_method("has_reached_destination") and dog.has_reached_destination():
		transition_requested.emit(&"Idle", {})
		return

	if dog.has_method("step_movement"):
		dog.step_movement(delta)


func exit() -> void:
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
