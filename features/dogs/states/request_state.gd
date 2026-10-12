class_name RequestState
extends State

var _whine_modifier_active: bool = false
var _bark_timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_bark_timer = 0.0
	_check_and_apply_penalties()


func exit() -> void:
	_remove_penalties()
	var dog: Node = _get_dog()
	if dog and dog.has_method("stop"):
		dog.stop()


func physics_update(delta: float) -> void:
	var dog: Node = _get_dog()
	if not dog:
		transition_requested.emit(&"Idle", {})
		return

	var needs: Dictionary = dog.needs if "needs" in dog else {}
	var profile: DogProfile = dog.profile if "profile" in dog else null
	if not profile:
		transition_requested.emit(&"Idle", {})
		return

	var context: Dictionary = {
		"current_state": &"Request",
		"has_food": dog.is_food_available() if dog.has_method("is_food_available") else false,
	}

	# Check if another urgent state takes precedence (like Eat if food is now available)
	var next_state: StringName = DogBrain.evaluate_next_state(needs, profile, context)
	if next_state != &"Request":
		transition_requested.emit(next_state, {})
		return

	# Re-check whine penalty in case affection dropped while in request for another reason
	_check_and_apply_penalties()

	# Face or move towards player
	var player: Node3D = dog.get_player() if dog.has_method("get_player") else null
	if player:
		var dist: float = dog.global_position.distance_to(player.global_position)
		if dist > 2.0:
			dog.navigate_to(player.global_position)
			if dog.has_method("step_movement"):
				dog.step_movement(delta)
		else:
			dog.stop()
			if dog.has_method("look_towards"):
				dog.look_towards(player.global_position, delta)
	else:
		dog.stop()


func _check_and_apply_penalties() -> void:
	var dog: Node = _get_dog()
	if not dog:
		return
	var profile: DogProfile = dog.profile if "profile" in dog else null
	var needs: Dictionary = dog.needs if "needs" in dog else {}
	if not profile:
		return

	var is_affection_low: bool = needs.get("affection", 100.0) <= profile.affection_threshold
	if is_affection_low and not _whine_modifier_active:
		var sm: Node = dog.get_node_or_null("/root/StatusManager")
		if sm and sm.has_method("add_modifier"):
			var mod := StatModifier.new()
			mod.stat = Enums.Stat.SANITY
			mod.kind = Enums.ModifierKind.RATE_ADD
			mod.value = -1.0
			mod.duration_min = -1
			mod.source_id = StringName("dog:%s:whine" % profile.id)
			mod.label = "%s is whining" % profile.display_name
			sm.call("add_modifier", mod)
			_whine_modifier_active = true
	elif not is_affection_low and _whine_modifier_active:
		_remove_penalties()


func _remove_penalties() -> void:
	if not _whine_modifier_active:
		return
	var dog: Node = _get_dog()
	if dog and "profile" in dog and dog.profile != null:
		var sm: Node = dog.get_node_or_null("/root/StatusManager")
		if sm and sm.has_method("remove_by_source"):
			sm.call("remove_by_source", StringName("dog:%s:whine" % dog.profile.id))
	_whine_modifier_active = false


func _get_dog() -> Node:
	if state_machine and state_machine.get_parent():
		return state_machine.get_parent()
	return null
