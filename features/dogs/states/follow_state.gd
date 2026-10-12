class_name FollowState
extends State

@export var follow_duration: float = 6.0
@export var follow_distance: float = 1.6

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0


func physics_update(delta: float) -> void:
	_timer += delta
	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	# Urgent needs interrupt following
	var needs: Dictionary = dog.needs if "needs" in dog else {}
	var profile: DogProfile = dog.profile if "profile" in dog else null
	if profile:
		var context: Dictionary = {
			"current_state": &"Follow",
			"has_food": dog.is_food_available() if dog.has_method("is_food_available") else false,
		}
		var urgent_state: StringName = DogBrain.evaluate_next_state(needs, profile, context)
		if urgent_state != &"Idle" and urgent_state != &"Follow" and urgent_state != &"Wander":
			transition_requested.emit(urgent_state, {})
			return

	if _timer >= follow_duration:
		transition_requested.emit(&"Idle", {})
		return

	var player: Node3D = dog.get_player() if dog.has_method("get_player") else null
	if not player:
		transition_requested.emit(&"Idle", {})
		return

	var dist: float = dog.global_position.distance_to(player.global_position)
	if dist > follow_distance:
		dog.navigate_to(player.global_position)
		if dog.has_method("step_movement"):
			dog.step_movement(delta)
	else:
		dog.stop()
		if dog.has_method("look_towards"):
			dog.look_towards(player.global_position, delta)


func exit() -> void:
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
