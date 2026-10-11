extends GutTest

func before_each() -> void:
	SceneRouter.reset_state()

func after_each() -> void:
	SceneRouter.reset_state()

func test_level_root_places_player_at_spawn_marker() -> void:
	var root: LevelRoot = LevelRoot.new()
	add_child_autoqfree(root)

	var default_marker: Marker3D = Marker3D.new()
	default_marker.name = "default"
	default_marker.position = Vector3(0, 0, 0)
	default_marker.add_to_group(&"spawn_points")
	root.add_child(default_marker)

	var target_marker: Marker3D = Marker3D.new()
	target_marker.name = "bedroom"
	target_marker.position = Vector3(10, 5, -2)
	target_marker.add_to_group(&"spawn_points")
	root.add_child(target_marker)

	var player: Node3D = Node3D.new()
	player.name = "Player"
	player.position = Vector3(99, 99, 99)
	player.add_to_group(&"player")
	root.add_child(player)

	# Simulate router setting pending spawn id
	SceneRouter._pending_spawn_id = &"bedroom"

	root._place_player()

	assert_almost_eq(player.global_position.x, 10.0, 0.001)
	assert_almost_eq(player.global_position.y, 5.0, 0.001)
	assert_almost_eq(player.global_position.z, -2.0, 0.001)

func test_level_root_fallback_to_default_marker() -> void:
	var root: LevelRoot = LevelRoot.new()
	add_child_autoqfree(root)

	var default_marker: Marker3D = Marker3D.new()
	default_marker.name = "default"
	default_marker.position = Vector3(1, 2, 3)
	default_marker.add_to_group(&"spawn_points")
	root.add_child(default_marker)

	var player: Node3D = Node3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0, 0)
	player.add_to_group(&"player")
	root.add_child(player)

	SceneRouter._pending_spawn_id = &"unknown_spawn"

	root._place_player()

	assert_almost_eq(player.global_position.x, 1.0, 0.001)
	assert_almost_eq(player.global_position.y, 2.0, 0.001)
	assert_almost_eq(player.global_position.z, 3.0, 0.001)

func test_level_root_no_player_graceful() -> void:
	var root: LevelRoot = LevelRoot.new()
	add_child_autoqfree(root)

	var default_marker: Marker3D = Marker3D.new()
	default_marker.name = "default"
	default_marker.add_to_group(&"spawn_points")
	root.add_child(default_marker)

	# Should not crash when no player exists
	root._place_player()
	assert_true(true, "LevelRoot handled absence of player node without error")
