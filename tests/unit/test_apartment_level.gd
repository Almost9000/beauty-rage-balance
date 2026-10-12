extends GutTest

const APARTMENT_SCENE_PATH := "res://levels/apartment/apartment.tscn"

func before_each() -> void:
	SceneRouter.reset_state()

func after_each() -> void:
	SceneRouter.reset_state()

func test_graybox_materials_exist() -> void:
	var floor_mat = load("res://assets/materials/floor.tres")
	var wall_mat = load("res://assets/materials/wall.tres")
	var furniture_mat = load("res://assets/materials/furniture.tres")
	var accent_mat = load("res://assets/materials/accent.tres")

	assert_not_null(floor_mat, "floor.tres should exist")
	assert_not_null(wall_mat, "wall.tres should exist")
	assert_not_null(furniture_mat, "furniture.tres should exist")
	assert_not_null(accent_mat, "accent.tres should exist")

	assert_is(floor_mat, StandardMaterial3D)
	assert_is(wall_mat, StandardMaterial3D)
	assert_is(furniture_mat, StandardMaterial3D)
	assert_is(accent_mat, StandardMaterial3D)

func test_apartment_scene_structure() -> void:
	var scene = load(APARTMENT_SCENE_PATH)
	assert_not_null(scene, "apartment.tscn should load")

	var inst = scene.instantiate()
	add_child_autoqfree(inst)

	assert_is(inst, LevelRoot, "Apartment root should be a LevelRoot")

	# WorldEnvironment
	var env_node = inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_not_null(env_node, "WorldEnvironment should exist")
	assert_not_null(env_node.environment, "Environment should be configured")

	# DirectionalLight3D
	var sun = inst.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	assert_not_null(sun, "DirectionalLight3D should exist")
	assert_true(sun.shadow_enabled, "DirectionalLight3D shadow should be enabled")

	# HUD
	var hud = inst.get_node_or_null("HUD")
	assert_not_null(hud, "HUD instance should be present")

	# NavigationRegion3D
	var nav_reg = inst.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	assert_not_null(nav_reg, "NavigationRegion3D should exist")
	assert_not_null(nav_reg.navigation_mesh, "NavigationMesh should be assigned")
	assert_almost_eq(nav_reg.navigation_mesh.agent_radius, 0.3, 0.05, "agent_radius should be ~0.3m")
	assert_gt(nav_reg.navigation_mesh.get_polygon_count(), 0, "NavigationMesh should have baked polygons")
	assert_gt(nav_reg.navigation_mesh.get_vertices().size(), 0, "NavigationMesh should have vertices")

func test_stations_node_markers() -> void:
	var inst = load(APARTMENT_SCENE_PATH).instantiate()
	add_child_autoqfree(inst)

	var stations = inst.get_node_or_null("Stations")
	assert_not_null(stations, "Stations node should exist")

	var required_stations := [
		"closet",
		"vanity",
		"shower",
		"bed",
		"front_door",
		"dog_bowls",
		"dog_bed"
	]

	for st_name in required_stations:
		var marker = stations.get_node_or_null(st_name) as Marker3D
		assert_not_null(marker, "Station marker '%s' should exist" % st_name)

func test_clutter_spawns_node() -> void:
	var inst = load(APARTMENT_SCENE_PATH).instantiate()
	add_child_autoqfree(inst)

	var clutter_spawns = inst.get_node_or_null("ClutterSpawns")
	assert_not_null(clutter_spawns, "ClutterSpawns node should exist")

	var marker_count := 0
	for child in clutter_spawns.get_children():
		if child is Marker3D:
			marker_count += 1

	assert_gt(marker_count, 9, "ClutterSpawns should have at least 10 Marker3D children (found %d)" % marker_count)

func test_spawn_points_convention() -> void:
	var inst = load(APARTMENT_SCENE_PATH).instantiate()
	add_child_autoqfree(inst)

	var spawn_nodes = get_tree().get_nodes_in_group(&"spawn_points")
	var names: Array[String] = []
	for s in spawn_nodes:
		if s is Marker3D and inst.is_ancestor_of(s):
			names.append(s.name)

	assert_true(names.has("default"), "spawn_points must have 'default' marker")
	assert_true(names.has("front_door"), "spawn_points must have 'front_door' marker")

func test_player_spawning_at_bed_and_door() -> void:
	var inst = load(APARTMENT_SCENE_PATH).instantiate()
	add_child_autoqfree(inst)

	var player = inst.get_node_or_null("Player") as Node3D
	if not player:
		player = Node3D.new()
		player.name = "Player"
		player.add_to_group(&"player")
		inst.add_child(player)

	# Test 1: Spawning at default (by bed)
	SceneRouter._pending_spawn_id = &"default"
	(inst as LevelRoot)._place_player()

	var default_marker: Marker3D = null
	var front_door_marker: Marker3D = null
	for s in get_tree().get_nodes_in_group(&"spawn_points"):
		if s is Marker3D and inst.is_ancestor_of(s):
			if s.name == &"default":
				default_marker = s
			elif s.name == &"front_door":
				front_door_marker = s

	assert_not_null(default_marker)
	assert_not_null(front_door_marker)
	assert_almost_eq(player.global_position.x, default_marker.global_position.x, 0.05)
	assert_almost_eq(player.global_position.z, default_marker.global_position.z, 0.05)

	# Test 2: Spawning at front_door
	SceneRouter._pending_spawn_id = &"front_door"
	(inst as LevelRoot)._place_player()

	assert_almost_eq(player.global_position.x, front_door_marker.global_position.x, 0.05)
	assert_almost_eq(player.global_position.z, front_door_marker.global_position.z, 0.05)

func test_navigation_connectivity_across_all_rooms() -> void:
	var inst = load(APARTMENT_SCENE_PATH).instantiate()
	add_child_autoqfree(inst)

	var nav_reg = inst.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	assert_not_null(nav_reg)

	# Wait two physics frames for NavigationServer3D sync
	await get_tree().physics_frame
	await get_tree().physics_frame

	var map = nav_reg.get_navigation_map()
	var stations = inst.get_node("Stations")
	var front_door_pos = (stations.get_node("front_door") as Marker3D).global_position
	var bed_pos = (stations.get_node("bed") as Marker3D).global_position
	var dog_bowls_pos = (stations.get_node("dog_bowls") as Marker3D).global_position
	var dog_bed_pos = (stations.get_node("dog_bed") as Marker3D).global_position
	var shower_pos = (stations.get_node("shower") as Marker3D).global_position
	var closet_pos = (stations.get_node("closet") as Marker3D).global_position
	var vanity_pos = (stations.get_node("vanity") as Marker3D).global_position

	# Front door to Bedroom (bed)
	var path_door_to_bed = NavigationServer3D.map_get_path(map, front_door_pos, bed_pos, true)
	assert_gt(path_door_to_bed.size(), 1, "Navmesh path from front_door to bed should be reachable")

	# Front door to Kitchen (dog bowls)
	var path_door_to_kitchen = NavigationServer3D.map_get_path(map, front_door_pos, dog_bowls_pos, true)
	assert_gt(path_door_to_kitchen.size(), 1, "Navmesh path from front_door to dog_bowls should be reachable")

	# Bedroom to Bathroom (shower)
	var path_bed_to_shower = NavigationServer3D.map_get_path(map, bed_pos, shower_pos, true)
	assert_gt(path_bed_to_shower.size(), 1, "Navmesh path from bed to shower should be reachable")

	# Living room (dog bed) to Kitchen (dog bowls)
	var path_dog_bed_to_bowls = NavigationServer3D.map_get_path(map, dog_bed_pos, dog_bowls_pos, true)
	assert_gt(path_dog_bed_to_bowls.size(), 1, "Navmesh path from dog_bed to dog_bowls should be reachable")

	# Bed to Closet
	var path_bed_to_closet = NavigationServer3D.map_get_path(map, bed_pos, closet_pos, true)
	assert_gt(path_bed_to_closet.size(), 1, "Navmesh path from bed to closet should be reachable")

	# Bed to Vanity
	var path_bed_to_vanity = NavigationServer3D.map_get_path(map, bed_pos, vanity_pos, true)
	assert_gt(path_bed_to_vanity.size(), 1, "Navmesh path from bed to vanity should be reachable")
