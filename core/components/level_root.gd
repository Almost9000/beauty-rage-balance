class_name LevelRoot
extends Node3D

func _ready() -> void:
	_place_player()

func _place_player() -> void:
	var spawn_id: StringName = &"default"
	var scene_router: Node = get_node_or_null("/root/SceneRouter")
	if scene_router and scene_router.has_method("consume_spawn_id"):
		spawn_id = scene_router.consume_spawn_id()
	if spawn_id.is_empty():
		spawn_id = &"default"

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return

	var player: Node3D = players[0] as Node3D
	if not player:
		return

	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(&"spawn_points")
	var target_marker: Marker3D = null
	var default_marker: Marker3D = null

	for node: Node in spawn_points:
		if node is Marker3D:
			if node.name == spawn_id:
				target_marker = node
				break
			if node.name == &"default":
				default_marker = node

	var chosen: Marker3D = target_marker if target_marker != null else default_marker
	if chosen:
		player.global_transform = chosen.global_transform
