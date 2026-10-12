class_name Apartment
extends LevelRoot

@onready var clutter_spawner: ClutterSpawner = get_node_or_null("ClutterSpawner") as ClutterSpawner
@onready var comfort_score: ComfortScore = get_node_or_null("ComfortScore") as ComfortScore
@onready var clutter_container: Node3D = get_node_or_null("ClutterContainer") as Node3D

func _ready() -> void:
	super._ready()
	_resolve_components()
	_connect_router()
	_restore_or_init_state()

func _resolve_components() -> void:
	if not clutter_spawner:
		clutter_spawner = get_node_or_null("ClutterSpawner") as ClutterSpawner
	if not comfort_score:
		comfort_score = get_node_or_null("ComfortScore") as ComfortScore
	if not clutter_container:
		clutter_container = get_node_or_null("ClutterContainer") as Node3D

func _connect_router() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router:
		if router.has_signal("flush_level_state"):
			if not router.flush_level_state.is_connected(_on_flush_level_state):
				router.flush_level_state.connect(_on_flush_level_state)
		if router.has_signal("level_changing"):
			if not router.level_changing.is_connected(_on_level_changing):
				router.level_changing.connect(_on_level_changing)

func _restore_or_init_state() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	var state: Dictionary = {}
	if router and router.has_method("get_level_state"):
		state = router.call("get_level_state", "apartment")

	if not state.is_empty():
		_restore_from_state(state)

	if comfort_score:
		comfort_score.update_comfort()

func _restore_from_state(state: Dictionary) -> void:
	if state.has("clutter") and clutter_spawner:
		# Clear existing clutter in container
		var existing: Array[Node] = []
		if clutter_container:
			existing = clutter_container.get_children()
		elif is_inside_tree():
			existing = get_tree().get_nodes_in_group(&"clutter")

		for node: Node in existing:
			if node is Clutter and is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()

		var clutter_items: Array = state.get("clutter", [])
		for item_raw: Variant in clutter_items:
			if item_raw is Dictionary:
				var item: Dictionary = item_raw as Dictionary
				var type_name: StringName = StringName(item.get("type", "dishes"))
				var pos_raw: Variant = item.get("position", Vector3.ZERO)
				var pos: Vector3 = Vector3.ZERO
				if pos_raw is Array and (pos_raw as Array).size() >= 3:
					pos = Vector3(pos_raw[0], pos_raw[1], pos_raw[2])
				elif pos_raw is Dictionary:
					pos = Vector3(pos_raw.get("x", 0.0), pos_raw.get("y", 0.0), pos_raw.get("z", 0.0))
				elif pos_raw is Vector3:
					pos = pos_raw
				clutter_spawner.spawn(type_name, pos)

	if state.has("dog_bowls"):
		var b_data: Dictionary = state["dog_bowls"]
		var bowls_nodes: Array[Node] = []
		if is_inside_tree():
			bowls_nodes = get_tree().get_nodes_in_group(&"dog_bowls")
		else:
			var b_node: Node = find_child("DogBowls", true, false)
			if b_node:
				bowls_nodes.append(b_node)
		if not bowls_nodes.is_empty():
			var b: Node = bowls_nodes[0]
			if "portions_remaining" in b:
				b.set("portions_remaining", int(b_data.get("portions", 0)))

	var elapsed: int = 0
	if state.has("left_at_minute"):
		var left_at: int = int(state.get("left_at_minute", 0))
		var clock: Node = get_node_or_null("/root/GameClock")
		var now_m: int = int(clock.get("now_minutes")) if clock else left_at
		elapsed = maxi(0, now_m - left_at)

	if state.has("dogs"):
		var dogs_dict: Dictionary = state["dogs"]
		var dogs: Array[Node] = []
		if is_inside_tree():
			dogs = get_tree().get_nodes_in_group(&"dogs")
		else:
			var dogs_node: Node = find_child("Dogs", true, false)
			if dogs_node:
				dogs = dogs_node.get_children()

		for d: Node in dogs:
			var dog_id: String = ""
			if "profile" in d and d.profile != null:
				dog_id = String(d.profile.id)
			elif "name" in d:
				dog_id = String(d.name).to_lower()

			if dogs_dict.has(dog_id):
				var d_data: Dictionary = dogs_dict[dog_id]
				if d.has_method("from_dict"):
					d.call("from_dict", d_data)
				elif "needs" in d and d_data.has("needs"):
					d.needs = d_data["needs"].duplicate()

				if elapsed > 0 and d.has_method("integrate_time"):
					d.call("integrate_time", elapsed)

	if elapsed > 0 and clutter_spawner:
		clutter_spawner.simulate_elapsed_time(elapsed)

func save_state() -> Dictionary:
	var clutter_data: Array[Dictionary] = []
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"clutter"):
			if node is Clutter and is_instance_valid(node) and not node.is_queued_for_deletion():
				var c: Clutter = node as Clutter
				clutter_data.append({
					"type": String(c.clutter_type),
					"position": [c.global_position.x, c.global_position.y, c.global_position.z]
				})
	elif clutter_container:
		for child: Node in clutter_container.get_children():
			if child is Clutter and is_instance_valid(child) and not child.is_queued_for_deletion():
				var c: Clutter = child as Clutter
				clutter_data.append({
					"type": String(c.clutter_type),
					"position": [c.global_position.x, c.global_position.y, c.global_position.z]
				})

	var dogs_data: Dictionary = {}
	var dogs: Array[Node] = []
	if is_inside_tree():
		dogs = get_tree().get_nodes_in_group(&"dogs")
	else:
		var dogs_node: Node = find_child("Dogs", true, false)
		if dogs_node:
			dogs = dogs_node.get_children()

	for d: Node in dogs:
		if is_instance_valid(d) and not d.is_queued_for_deletion():
			var dog_id: String = ""
			if "profile" in d and d.profile != null:
				dog_id = String(d.profile.id)
			elif "name" in d:
				dog_id = String(d.name).to_lower()
			if not dog_id.is_empty():
				if d.has_method("to_dict"):
					dogs_data[dog_id] = d.call("to_dict")
				elif "needs" in d:
					dogs_data[dog_id] = {
						"needs": d.needs.duplicate(),
						"position": [d.global_position.x, d.global_position.y, d.global_position.z]
					}

	var bowls_data: Dictionary = {}
	var bowls_nodes: Array[Node] = []
	if is_inside_tree():
		bowls_nodes = get_tree().get_nodes_in_group(&"dog_bowls")
	else:
		var b_node: Node = find_child("DogBowls", true, false)
		if b_node:
			bowls_nodes.append(b_node)

	if not bowls_nodes.is_empty():
		var b: Node = bowls_nodes[0]
		bowls_data = {
			"has_food": bool(b.get("has_food")),
			"portions": int(b.get("portions_remaining")),
		}

	var clock: Node = get_node_or_null("/root/GameClock")
	var now_m: int = int(clock.get("now_minutes")) if clock else 0

	var state: Dictionary = {
		"clutter": clutter_data,
		"left_at_minute": now_m,
		"dogs": dogs_data,
		"dog_bowls": bowls_data,
	}

	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("store_level_state"):
		router.call("store_level_state", "apartment", state)

	return state

func _on_flush_level_state() -> void:
	save_state()

func _on_level_changing(from_id: String, _to_id: String) -> void:
	if from_id == "apartment" or from_id.is_empty():
		save_state()
