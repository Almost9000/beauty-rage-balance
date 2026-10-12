class_name ClutterSpawner
extends Node3D

const NATURAL_TYPES: Array[StringName] = [&"dishes", &"laundry", &"trash"]

@export var spawn_rate_per_hour: float = 0.5
@export var max_count: int = 10
@export var clutter_container: Node3D = null
@export var markers_container: Node3D = null
@export var clutter_scenes: Dictionary = {}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if not is_in_group(&"clutter_spawner"):
		add_to_group(&"clutter_spawner")

	if clutter_scenes.is_empty():
		_init_default_scenes()

	_resolve_nodes()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if clock.has_signal("hour_ticked"):
			clock.connect("hour_ticked", _on_hour_ticked)
		elif clock.has_signal("hour_changed"):
			clock.connect("hour_changed", _on_hour_ticked)

		if clock.has_signal("time_skipped"):
			clock.connect("time_skipped", _on_time_skipped)

func _init_default_scenes() -> void:
	clutter_scenes[&"dishes"] = load("res://features/cleaning/dishes.tscn")
	clutter_scenes[&"laundry"] = load("res://features/cleaning/laundry.tscn")
	clutter_scenes[&"trash"] = load("res://features/cleaning/trash.tscn")
	clutter_scenes[&"dog_accident"] = load("res://features/cleaning/dog_accident.tscn")

func _resolve_nodes() -> void:
	if not clutter_container:
		if get_parent() and get_parent().has_node("ClutterContainer"):
			clutter_container = get_parent().get_node("ClutterContainer") as Node3D
		else:
			clutter_container = self

	if not markers_container:
		if get_parent() and get_parent().has_node("ClutterSpawns"):
			markers_container = get_parent().get_node("ClutterSpawns") as Node3D
		elif is_inside_tree() and get_tree().current_scene:
			markers_container = get_tree().current_scene.find_child("ClutterSpawns", true, false) as Node3D

func get_all_markers() -> Array[Marker3D]:
	_resolve_nodes()
	var markers: Array[Marker3D] = []
	if markers_container:
		for child: Node in markers_container.get_children():
			if child is Marker3D:
				markers.append(child as Marker3D)
	return markers

func get_free_markers() -> Array[Marker3D]:
	var free: Array[Marker3D] = []
	var markers: Array[Marker3D] = get_all_markers()
	var active_clutter: Array[Node] = []
	if is_inside_tree():
		active_clutter = get_tree().get_nodes_in_group(&"clutter")
	elif clutter_container:
		for child: Node in clutter_container.get_children():
			if child is Clutter and not child.is_queued_for_deletion():
				active_clutter.append(child)

	for m: Marker3D in markers:
		var occupied: bool = false
		for c: Node in active_clutter:
			if c is Node3D and not c.is_queued_for_deletion():
				var dist: float = (c as Node3D).global_position.distance_to(m.global_position)
				if dist < 0.5:
					occupied = true
					break
		if not occupied:
			free.append(m)
	return free

func get_clutter_count() -> int:
	var count: int = 0
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"clutter"):
			if node is Clutter and not node.is_queued_for_deletion():
				count += 1
	elif clutter_container:
		for child: Node in clutter_container.get_children():
			if child is Clutter and not child.is_queued_for_deletion():
				count += 1
	return count

func spawn(type: StringName = &"", at_position: Variant = null) -> Clutter:
	if get_clutter_count() >= max_count:
		return null

	var chosen_type: StringName = type
	if chosen_type.is_empty():
		chosen_type = NATURAL_TYPES[rng.randi() % NATURAL_TYPES.size()]

	var target_pos: Vector3 = Vector3.ZERO
	if at_position is Vector3:
		target_pos = at_position
	elif at_position is Node3D:
		target_pos = (at_position as Node3D).global_position
	else:
		var free_markers: Array[Marker3D] = get_free_markers()
		if free_markers.is_empty():
			return null
		var marker: Marker3D = free_markers[rng.randi() % free_markers.size()]
		target_pos = marker.global_position

	_resolve_nodes()
	if clutter_scenes.is_empty():
		_init_default_scenes()

	var scene: PackedScene = null
	if clutter_scenes.has(chosen_type):
		scene = clutter_scenes[chosen_type] as PackedScene
	elif clutter_scenes.has(String(chosen_type)):
		scene = clutter_scenes[String(chosen_type)] as PackedScene

	if not scene:
		push_error("ClutterSpawner: No scene available for clutter type '%s'" % chosen_type)
		return null

	var inst: Node = scene.instantiate()
	var clutter: Clutter = inst as Clutter
	if not clutter:
		push_error("ClutterSpawner: Instantiated scene is not a Clutter instance")
		inst.queue_free()
		return null

	clutter.clutter_type = chosen_type
	var parent_node: Node = clutter_container if clutter_container else self
	parent_node.add_child(clutter)
	clutter.global_position = target_pos
	return clutter

func simulate_elapsed_time(minutes: int) -> int:
	var hours: int = minutes / 60
	var spawned_count: int = 0
	for _i in range(hours):
		if get_clutter_count() >= max_count:
			break
		if rng.randf() < spawn_rate_per_hour:
			var c: Clutter = spawn()
			if c:
				spawned_count += 1
	return spawned_count

func _on_hour_ticked(_hour: int = 0) -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and bool(clock.get("is_skipping")):
		return
	if rng.randf() < spawn_rate_per_hour:
		spawn()

func _on_time_skipped(from_min: int, to_min: int) -> void:
	var diff: int = to_min - from_min
	if diff > 0:
		simulate_elapsed_time(diff)

func clear_all() -> void:
	var nodes: Array[Node] = []
	if is_inside_tree():
		nodes = get_tree().get_nodes_in_group(&"clutter")
	elif clutter_container:
		nodes = clutter_container.get_children()

	for node: Node in nodes:
		if node is Clutter and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
