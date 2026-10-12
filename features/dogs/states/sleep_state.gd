class_name SleepState
extends State

@export var sleep_duration: float = 3.0

var _is_sleeping: bool = false
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_is_sleeping = false
	_timer = 0.0

	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	var bed_pos: Vector3 = dog.get_bed_position() if dog.has_method("get_bed_position") else dog.global_position
	var dist: float = dog.global_position.distance_to(bed_pos)
	if dist <= 1.0:
		dog.stop()
		_is_sleeping = true
	else:
		dog.navigate_to(bed_pos)


func physics_update(delta: float) -> void:
	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	if not _is_sleeping:
		var bed_pos: Vector3 = dog.get_bed_position() if dog.has_method("get_bed_position") else dog.global_position
		var dist: float = dog.global_position.distance_to(bed_pos)
		if dist <= 1.0:
			dog.stop()
			_is_sleeping = true
		else:
			dog.navigate_to(bed_pos)
			if dog.has_method("step_movement"):
				dog.step_movement(delta)
	else:
		_timer += delta
		# While sleeping, restore energy
		if dog.has_method("modify_need"):
			dog.modify_need(&"energy", 35.0 * delta)

		var energy: float = dog.get_need(&"energy") if dog.has_method("get_need") else 100.0
		if energy >= 100.0 or _timer >= sleep_duration:
			if dog.has_method("set_need"):
				dog.set_need(&"energy", 100.0)
			transition_requested.emit(&"Idle", {})


func exit() -> void:
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
