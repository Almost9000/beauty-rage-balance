class_name Dog
extends CharacterBody3D

@export var profile: DogProfile

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@onready var dog_brain: DogBrain = get_node_or_null("DogBrain") as DogBrain
@onready var interactable: Interactable = get_node_or_null("Interactable") as Interactable
@onready var visual_container: Node3D = get_node_or_null("Visual") as Node3D

var needs: Dictionary = {
	"hunger": 0.0,
	"bladder": 0.0,
	"affection": 100.0,
	"energy": 100.0,
}

var _prev_threshold_states: Dictionary = {
	"hunger": false,
	"bladder": false,
	"affection": false,
	"energy": false,
}

var _cached_destination: Vector3 = Vector3.ZERO


func _ready() -> void:
	if not is_in_group(&"dogs"):
		add_to_group(&"dogs")

	collision_layer = 8   # Layer 4: dogs
	collision_mask = 3    # Layer 1 (world) + Layer 2 (player)

	if profile:
		_setup_from_profile()

	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	_update_threshold_states_initial()


func _setup_from_profile() -> void:
	if not profile:
		return

	if interactable:
		interactable.prompt_text = "Pet %s" % profile.display_name

	if visual_container and profile.mesh_scene and visual_container.get_child_count() == 0:
		var inst: Node = profile.mesh_scene.instantiate()
		visual_container.add_child(inst)

	if visual_container and profile.scale != Vector3.ONE:
		visual_container.scale = profile.scale


func _on_interacted(_actor: Node) -> void:
	pet()


func _update_threshold_states_initial() -> void:
	if not profile:
		return
	_prev_threshold_states["hunger"] = float(needs.get("hunger", 0.0)) >= profile.hunger_threshold
	_prev_threshold_states["bladder"] = float(needs.get("bladder", 0.0)) >= profile.bladder_threshold
	_prev_threshold_states["affection"] = float(needs.get("affection", 100.0)) <= profile.affection_threshold
	_prev_threshold_states["energy"] = float(needs.get("energy", 100.0)) <= profile.energy_threshold


# ---------------------------------------------------------
# Needs API
# ---------------------------------------------------------

func get_need(need_name: StringName) -> float:
	return float(needs.get(String(need_name), 0.0))


func set_need(need_name: StringName, value: float) -> void:
	var key: String = String(need_name)
	needs[key] = clampf(value, 0.0, 100.0)
	_check_threshold_crossings()


func modify_need(need_name: StringName, delta: float) -> void:
	var key: String = String(need_name)
	var current: float = float(needs.get(key, 0.0))
	set_need(need_name, current + delta)


func integrate_time(delta_minutes: int) -> Dictionary:
	if not profile:
		return {"needs": needs.duplicate(), "accidents": 0}

	var sim: Dictionary = DogBrain.simulate_needs(needs, profile, delta_minutes)
	var updated_needs: Dictionary = sim.get("needs", {})
	for k: String in updated_needs:
		needs[k] = updated_needs[k]

	var accidents: int = int(sim.get("accidents", 0))
	for _i in range(accidents):
		spawn_accident(false)

	_check_threshold_crossings()
	return sim


func _check_threshold_crossings() -> void:
	if not profile:
		return

	var bus: Node = get_node_or_null("/root/EventBus")

	# Hunger: crossed threshold upwards or downwards
	var hunger_urgent: bool = float(needs.get("hunger", 0.0)) >= profile.hunger_threshold
	if hunger_urgent != _prev_threshold_states.get("hunger", false):
		_prev_threshold_states["hunger"] = hunger_urgent
		if bus and bus.has_signal("dog_need_changed"):
			bus.emit_signal("dog_need_changed", profile.id, &"hunger", float(needs["hunger"]))

	# Bladder: crossed threshold upwards or downwards
	var bladder_urgent: bool = float(needs.get("bladder", 0.0)) >= profile.bladder_threshold
	if bladder_urgent != _prev_threshold_states.get("bladder", false):
		_prev_threshold_states["bladder"] = bladder_urgent
		if bus and bus.has_signal("dog_need_changed"):
			bus.emit_signal("dog_need_changed", profile.id, &"bladder", float(needs["bladder"]))

	# Affection: crossed threshold downwards (urgent) or upwards (satisfied)
	var affection_urgent: bool = float(needs.get("affection", 100.0)) <= profile.affection_threshold
	if affection_urgent != _prev_threshold_states.get("affection", false):
		_prev_threshold_states["affection"] = affection_urgent
		if bus and bus.has_signal("dog_need_changed"):
			bus.emit_signal("dog_need_changed", profile.id, &"affection", float(needs["affection"]))

	# Energy: crossed threshold downwards (tired) or upwards (rested)
	var energy_urgent: bool = float(needs.get("energy", 100.0)) <= profile.energy_threshold
	if energy_urgent != _prev_threshold_states.get("energy", false):
		_prev_threshold_states["energy"] = energy_urgent
		if bus and bus.has_signal("dog_need_changed"):
			bus.emit_signal("dog_need_changed", profile.id, &"energy", float(needs["energy"]))


# ---------------------------------------------------------
# Care Actions
# ---------------------------------------------------------

func pet() -> void:
	if not profile:
		return

	set_need(&"affection", 100.0)

	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm:
		# Remove whining penalty if present
		if sm.has_method("remove_by_source"):
			sm.call("remove_by_source", StringName("dog:%s:whine" % profile.id))

		# Instant +10 Sanity
		if sm.has_method("add_modifier"):
			var inst := StatModifier.new()
			inst.stat = Enums.Stat.SANITY
			inst.kind = Enums.ModifierKind.INSTANT
			inst.value = 10.0
			inst.source_id = StringName("dog:%s:cuddle_instant" % profile.id)
			sm.call("add_modifier", inst)

			# 30-min RATE_ADD +1.0/h buff
			var buff := StatModifier.new()
			buff.stat = Enums.Stat.SANITY
			buff.kind = Enums.ModifierKind.RATE_ADD
			buff.value = 1.0
			buff.duration_min = 30
			buff.source_id = StringName("dog:%s:cuddle" % profile.id)
			buff.label = "Cuddle with %s" % profile.display_name
			sm.call("add_modifier", buff)

	if dog_brain:
		dog_brain.transition_to(&"Cuddle")


func feed() -> void:
	set_need(&"hunger", 0.0)


func walk() -> void:
	set_need(&"bladder", 0.0)
	modify_need(&"energy", -25.0)


func reset_bladder() -> void:
	set_need(&"bladder", 0.0)


func spawn_accident(reset_bladder_need: bool = true) -> void:
	if reset_bladder_need:
		set_need(&"bladder", 0.0)
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var spawners: Array[Node] = tree.get_nodes_in_group(&"clutter_spawner")
	if not spawners.is_empty():
		var sp: Node = spawners[0]
		if sp.has_method("spawn"):
			sp.call("spawn", &"dog_accident", global_position)


# ---------------------------------------------------------
# Navigation & Environment queries
# ---------------------------------------------------------

func navigate_to(target_pos: Vector3) -> void:
	_cached_destination = target_pos
	if nav_agent:
		nav_agent.target_position = target_pos


func has_reached_destination() -> bool:
	if nav_agent and not nav_agent.is_navigation_finished():
		return false
	return global_position.distance_to(_cached_destination) <= 0.6


func step_movement(delta: float) -> void:
	var move_speed: float = profile.speed if profile else 2.0
	var next_pos: Vector3 = _cached_destination
	if nav_agent and not nav_agent.is_navigation_finished():
		next_pos = nav_agent.get_next_path_position()

	var diff: Vector3 = next_pos - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		var dir: Vector3 = diff.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		look_towards(next_pos, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_inside_tree():
		move_and_slide()


func look_towards(target_pos: Vector3, delta: float) -> void:
	var diff: Vector3 = target_pos - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		var target_angle: float = atan2(diff.x, diff.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


func get_random_nav_point() -> Vector3:
	var tree: SceneTree = get_tree()
	if not tree:
		return global_position

	# Try to find NavigationRegion3D and get map
	var nav_regions: Array[Node] = tree.get_nodes_in_group(&"nav_regions")
	if nav_regions.is_empty() and tree.current_scene:
		var reg: Node = tree.current_scene.find_child("NavigationRegion3D", true, false)
		if reg:
			nav_regions.append(reg)

	if not nav_regions.is_empty():
		var reg: NavigationRegion3D = nav_regions[0] as NavigationRegion3D
		if reg:
			var map: RID = reg.get_navigation_map()
			var p: Vector3 = NavigationServer3D.map_get_random_point(map, 1, false)
			if p != Vector3.ZERO:
				return p

	# Fallback: wander relative to current position within room bounds
	var offset: Vector3 = Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
	return global_position + offset


func get_player() -> Node3D:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	var players: Array[Node] = tree.get_nodes_in_group(&"player")
	if not players.is_empty():
		return players[0] as Node3D
	return null


func get_bowls() -> DogBowls:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	var bowls_nodes: Array[Node] = tree.get_nodes_in_group(&"dog_bowls")
	if not bowls_nodes.is_empty():
		return bowls_nodes[0] as DogBowls
	return null


func is_food_available() -> bool:
	var b: DogBowls = get_bowls()
	return b != null and b.is_food_available()


func get_bed_position() -> Vector3:
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		var stations: Node = tree.current_scene.find_child("Stations", true, false)
		if stations and stations.has_node("dog_bed"):
			var bed_marker: Marker3D = stations.get_node("dog_bed") as Marker3D
			if bed_marker:
				return bed_marker.global_position
	return global_position


# ---------------------------------------------------------
# State Serialization
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"needs": needs.duplicate(),
		"position": [global_position.x, global_position.y, global_position.z],
	}


func from_dict(data: Dictionary) -> void:
	if data.has("needs") and data["needs"] is Dictionary:
		var loaded_needs: Dictionary = data["needs"] as Dictionary
		for k: String in loaded_needs:
			needs[k] = float(loaded_needs[k])
	if data.has("position"):
		var p_raw: Variant = data["position"]
		if p_raw is Array and (p_raw as Array).size() >= 3:
			global_position = Vector3(p_raw[0], p_raw[1], p_raw[2])
	_check_threshold_crossings()
