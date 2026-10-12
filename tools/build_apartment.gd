extends SceneTree

const APARTMENT_PATH = "res://levels/apartment/apartment.tscn"

func _init() -> void:
	call_deferred("_generate_apartment")

func _set_owners(node: Node, scene_root: Node, instanced_roots: Array) -> void:
	for child in node.get_children():
		if child in instanced_roots:
			child.owner = scene_root
			continue
		child.owner = scene_root
		_set_owners(child, scene_root, instanced_roots)

func _generate_apartment() -> void:
	print(">> Building Apartment graybox level...")

	var root_node = Node3D.new()
	root_node.name = "Apartment"
	root.add_child(root_node)

	# Set script LevelRoot
	var level_root_script = load("res://core/components/level_root.gd")
	root_node.set_script(level_root_script)

	# Load materials
	var mat_floor = load("res://assets/materials/floor.tres")
	var mat_wall = load("res://assets/materials/wall.tres")
	var mat_furniture = load("res://assets/materials/furniture.tres")
	var mat_accent = load("res://assets/materials/accent.tres")

	# 1. WorldEnvironment
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.84)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.25)
	sky_mat.ground_horizon_color = Color(0.72, 0.78, 0.84)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	root_node.add_child(world_env)

	# 2. DirectionalLight3D
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.position = Vector3(-4.0, 6.0, -6.0)
	dir_light.rotation_degrees = Vector3(-38.0, 145.0, 0.0)
	dir_light.light_color = Color(1.0, 0.96, 0.88)
	dir_light.light_energy = 1.1
	dir_light.shadow_enabled = true
	dir_light.shadow_bias = 0.05
	dir_light.directional_shadow_max_distance = 30.0
	root_node.add_child(dir_light)

	# 3. OmniLights (ceiling fill lights)
	var lights_parent = Node3D.new()
	lights_parent.name = "Lights"
	root_node.add_child(lights_parent)

	var add_omni = func(name: String, pos: Vector3, col: Color, energy: float, range: float) -> OmniLight3D:
		var light = OmniLight3D.new()
		light.name = name
		light.position = pos
		light.light_color = col
		light.light_energy = energy
		light.omni_range = range
		light.omni_attenuation = 1.0
		light.shadow_enabled = false
		lights_parent.add_child(light)
		return light

	add_omni.call("Light_Living", Vector3(-3.8, 2.5, 1.5), Color(1.0, 0.93, 0.84), 0.75, 7.5)
	add_omni.call("Light_Kitchen", Vector3(-4.0, 2.5, -3.8), Color(1.0, 0.97, 0.92), 0.8, 6.5)
	add_omni.call("Light_Entry", Vector3(0.0, 2.5, 4.0), Color(1.0, 0.92, 0.82), 0.65, 5.5)
	add_omni.call("Light_Bedroom", Vector3(4.0, 2.5, -2.5), Color(1.0, 0.93, 0.85), 0.7, 6.5)
	add_omni.call("Light_Bathroom", Vector3(4.0, 2.5, 3.8), Color(1.0, 0.98, 0.96), 0.8, 5.5)

	# 4. Camera3D interior eye-level overview
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0.0, 1.8, 5.2)
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	cam.current = true
	root_node.add_child(cam)

	# Helper to create StaticBody3D box
	var add_box = func(parent: Node, name: String, pos: Vector3, sz: Vector3, mat: Material) -> StaticBody3D:
		var sb = StaticBody3D.new()
		sb.name = name
		sb.collision_layer = 1
		sb.collision_mask = 1
		sb.position = pos

		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape = BoxShape3D.new()
		shape.size = sz
		col.shape = shape
		sb.add_child(col)

		var mi = MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		var box_mesh = BoxMesh.new()
		box_mesh.size = sz
		box_mesh.material = mat
		mi.mesh = box_mesh
		sb.add_child(mi)

		parent.add_child(sb)
		return sb

	# Ceilings node (placed outside NavigationRegion3D so top of roof is not baked into navmesh)
	var ceilings_node = Node3D.new()
	ceilings_node.name = "Ceilings"
	root_node.add_child(ceilings_node)
	add_box.call(ceilings_node, "Ceiling_Main", Vector3(0.0, 2.9, 0.0), Vector3(13.0, 0.2, 12.0), mat_wall)

	# 5. NavigationRegion3D
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.3
	nav_mesh.agent_height = 1.5
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1 # layer 1: world
	nav_region.navigation_mesh = nav_mesh
	root_node.add_child(nav_region)

	# Floors node
	var floors_node = Node3D.new()
	floors_node.name = "Floors"
	nav_region.add_child(floors_node)
	add_box.call(floors_node, "Floor_Main", Vector3(0.0, -0.1, 0.0), Vector3(13.0, 0.2, 12.0), mat_floor)

	# Walls node
	var walls_node = Node3D.new()
	walls_node.name = "Walls"
	nav_region.add_child(walls_node)

	# --- EXTERIOR WALLS ---
	# North Wall (Z = -6.0):
	add_box.call(walls_node, "Wall_North_Left", Vector3(-6.0, 1.4, -6.0), Vector3(1.0, 2.8, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_North_KitchenWindowSill", Vector3(-4.5, 0.5, -6.0), Vector3(2.0, 1.0, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_North_KitchenWindowLintel", Vector3(-4.5, 2.6, -6.0), Vector3(2.0, 0.4, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_North_Center", Vector3(0.0, 1.4, -6.0), Vector3(7.0, 2.8, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_North_BedWindowSill", Vector3(4.5, 0.4, -6.0), Vector3(2.0, 0.8, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_North_BedWindowLintel", Vector3(4.5, 2.6, -6.0), Vector3(2.0, 0.4, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_North_Right", Vector3(6.0, 1.4, -6.0), Vector3(1.0, 2.8, 0.3), mat_wall)

	# South Wall (Z = 6.0):
	add_box.call(walls_node, "Wall_South_Left", Vector3(-6.0, 1.4, 6.0), Vector3(1.0, 2.8, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_South_LivingWindowSill", Vector3(-4.25, 0.4, 6.0), Vector3(2.5, 0.8, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_South_LivingWindowLintel", Vector3(-4.25, 2.6, 6.0), Vector3(2.5, 0.4, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_South_Mid", Vector3(-1.85, 1.4, 6.0), Vector3(2.3, 2.8, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_South_DoorLintel", Vector3(0.0, 2.55, 6.0), Vector3(1.4, 0.5, 0.3), mat_wall)
	add_box.call(walls_node, "Wall_South_BathOuter", Vector3(3.6, 1.4, 6.0), Vector3(5.8, 2.8, 0.3), mat_wall)

	# West Wall (X = -6.5):
	add_box.call(walls_node, "Wall_West_North", Vector3(-6.5, 1.4, -2.75), Vector3(0.3, 2.8, 6.5), mat_wall)
	add_box.call(walls_node, "Wall_West_WindowSill", Vector3(-6.5, 0.4, 2.0), Vector3(0.3, 0.8, 3.0), mat_wall)
	add_box.call(walls_node, "Wall_West_WindowLintel", Vector3(-6.5, 2.6, 2.0), Vector3(0.3, 0.4, 3.0), mat_wall)
	add_box.call(walls_node, "Wall_West_South", Vector3(-6.5, 1.4, 4.75), Vector3(0.3, 2.8, 2.5), mat_wall)

	# East Wall (X = 6.5):
	add_box.call(walls_node, "Wall_East_Solid", Vector3(6.5, 1.4, 0.0), Vector3(0.3, 2.8, 12.0), mat_wall)

	# --- INTERIOR PARTITIONS ---
	# 1. Main Spine Partition along X = 1.8:
	add_box.call(walls_node, "Wall_Partition_BedNorth", Vector3(1.8, 1.4, -3.5), Vector3(0.2, 2.8, 5.0), mat_wall)
	# Bedroom Doorway: Z in [-1.0, 0.5] (1.5m wide, height 2.3m) -> lintel
	add_box.call(walls_node, "Wall_Partition_BedLintel", Vector3(1.8, 2.55, -0.25), Vector3(0.2, 0.5, 1.5), mat_wall)
	# Solid section between bedroom and bathroom doors: Z in [0.5, 2.0] (1.5m)
	add_box.call(walls_node, "Wall_Partition_Mid", Vector3(1.8, 1.4, 1.25), Vector3(0.2, 2.8, 1.5), mat_wall)
	# Bathroom Doorway: Z in [2.0, 3.5] (1.5m wide, height 2.3m) -> lintel
	add_box.call(walls_node, "Wall_Partition_BathLintel", Vector3(1.8, 2.55, 2.75), Vector3(0.2, 0.5, 1.5), mat_wall)
	# Bathroom South solid section: Z in [3.5, 6.0] (2.5m)
	add_box.call(walls_node, "Wall_Partition_BathSouth", Vector3(1.8, 1.4, 4.75), Vector3(0.2, 2.8, 2.5), mat_wall)

	# 2. Divider between Bedroom and Bathroom along Z = 1.25:
	add_box.call(walls_node, "Wall_Divider_BedBath", Vector3(4.15, 1.4, 1.25), Vector3(4.7, 2.8, 0.2), mat_wall)

	# 3. Entry West Wall along X = -1.8, Z in [2.5, 6.0] (3.5m)
	add_box.call(walls_node, "Wall_Entry_West", Vector3(-1.8, 1.4, 4.25), Vector3(0.2, 2.8, 3.5), mat_wall)

	# 4. Entry North Archway along Z = 2.5, X in [-1.8, 1.8]:
	add_box.call(walls_node, "Wall_Entry_ArchLeft", Vector3(-1.4, 1.4, 2.5), Vector3(0.8, 2.8, 0.2), mat_wall)
	# Archway Opening: X in [-1.0, 1.0] (2.0m wide, height 2.4m) -> lintel
	add_box.call(walls_node, "Wall_Entry_ArchLintel", Vector3(0.0, 2.6, 2.5), Vector3(2.0, 0.4, 0.2), mat_wall)
	# Right nib: X in [1.0, 1.8]
	add_box.call(walls_node, "Wall_Entry_ArchRight", Vector3(1.4, 1.4, 2.5), Vector3(0.8, 2.8, 0.2), mat_wall)

	# Furniture node
	var furn_node = Node3D.new()
	furn_node.name = "Furniture"
	nav_region.add_child(furn_node)

	# --- LIVING ROOM FURNITURE ---
	add_box.call(furn_node, "Sofa_Seat", Vector3(-4.0, 0.225, 0.9), Vector3(2.4, 0.45, 0.9), mat_furniture)
	add_box.call(furn_node, "Sofa_Back", Vector3(-4.0, 0.65, 0.4), Vector3(2.4, 0.45, 0.2), mat_accent)
	add_box.call(furn_node, "CoffeeTable", Vector3(-4.0, 0.225, 2.0), Vector3(1.4, 0.45, 0.8), mat_furniture)
	add_box.call(furn_node, "TV_Bench", Vector3(-6.1, 0.25, 2.0), Vector3(0.5, 0.5, 1.8), mat_furniture)
	add_box.call(furn_node, "TV_Screen", Vector3(-6.2, 0.85, 2.0), Vector3(0.1, 0.7, 1.4), mat_accent)
	add_box.call(furn_node, "Dog_Bed_Cushion", Vector3(-2.6, 0.125, 4.8), Vector3(1.1, 0.25, 0.9), mat_accent)

	# --- KITCHEN FURNITURE ---
	add_box.call(furn_node, "Kitchen_Counter_North", Vector3(-4.3, 0.45, -5.55), Vector3(3.8, 0.9, 0.7), mat_furniture)
	add_box.call(furn_node, "Kitchen_Counter_West", Vector3(-6.1, 0.45, -4.0), Vector3(0.7, 0.9, 2.4), mat_furniture)
	add_box.call(furn_node, "Kitchen_Fridge", Vector3(-2.1, 0.95, -5.55), Vector3(0.7, 1.9, 0.7), mat_furniture)
	add_box.call(furn_node, "Kitchen_Island", Vector3(-3.8, 0.45, -2.0), Vector3(2.2, 0.9, 0.9), mat_furniture)
	add_box.call(furn_node, "Dog_Bowls_Stand", Vector3(-2.8, 0.08, -3.8), Vector3(0.6, 0.16, 0.35), mat_accent)

	# --- BEDROOM FURNITURE ---
	add_box.call(furn_node, "Bed_Mattress", Vector3(4.8, 0.3, -3.2), Vector3(2.0, 0.5, 2.2), mat_accent)
	add_box.call(furn_node, "Bed_Headboard", Vector3(5.9, 0.55, -3.2), Vector3(0.2, 1.1, 2.3), mat_furniture)
	add_box.call(furn_node, "Bedside_Table_North", Vector3(4.8, 0.25, -4.6), Vector3(0.5, 0.5, 0.5), mat_furniture)
	add_box.call(furn_node, "Bedside_Table_South", Vector3(4.8, 0.25, -1.8), Vector3(0.5, 0.5, 0.5), mat_furniture)
	add_box.call(furn_node, "Wardrobe_Closet", Vector3(4.4, 1.2, 0.75), Vector3(2.6, 2.4, 0.65), mat_furniture)
	add_box.call(furn_node, "Vanity_Desk", Vector3(3.0, 0.4, -5.55), Vector3(1.4, 0.8, 0.6), mat_furniture)
	add_box.call(furn_node, "Vanity_Mirror", Vector3(3.0, 1.4, -5.8), Vector3(1.1, 0.8, 0.05), mat_accent)
	add_box.call(furn_node, "Vanity_Stool", Vector3(3.0, 0.225, -4.7), Vector3(0.45, 0.45, 0.45), mat_furniture)

	# --- BATHROOM FIXTURES ---
	add_box.call(furn_node, "Shower_Tray", Vector3(5.3, 0.05, 2.2), Vector3(1.6, 0.1, 1.5), mat_accent)
	add_box.call(furn_node, "Shower_Glass", Vector3(4.5, 1.1, 2.2), Vector3(0.05, 2.0, 1.5), mat_furniture)
	add_box.call(furn_node, "Bathroom_Vanity", Vector3(3.2, 0.425, 5.55), Vector3(1.6, 0.85, 0.65), mat_furniture)
	add_box.call(furn_node, "Toilet_Fixture", Vector3(5.8, 0.4, 4.6), Vector3(0.45, 0.8, 0.7), mat_furniture)

	# --- ENTRY FURNITURE ---
	add_box.call(furn_node, "Front_Door_Panel", Vector3(0.0, 1.15, 5.95), Vector3(1.3, 2.3, 0.08), mat_furniture)
	add_box.call(furn_node, "Entry_ShoeBench", Vector3(1.45, 0.25, 4.5), Vector3(0.45, 0.5, 1.2), mat_furniture)

	# 6. STATIONS NODE
	var stations_node = Node3D.new()
	stations_node.name = "Stations"
	root_node.add_child(stations_node)

	var add_marker = func(parent: Node, name: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Marker3D:
		var marker = Marker3D.new()
		marker.name = name
		marker.position = pos
		marker.rotation_degrees = rot_deg
		parent.add_child(marker)
		return marker

	add_marker.call(stations_node, "closet", Vector3(4.4, 0.0, -0.2), Vector3(0.0, 180.0, 0.0))
	add_marker.call(stations_node, "vanity", Vector3(3.0, 0.0, -4.5), Vector3(0.0, 0.0, 0.0))
	add_marker.call(stations_node, "shower", Vector3(5.3, 0.0, 2.2), Vector3(0.0, -90.0, 0.0))
	add_marker.call(stations_node, "bed", Vector3(3.3, 0.0, -3.2), Vector3(0.0, 90.0, 0.0))
	add_marker.call(stations_node, "front_door", Vector3(0.0, 0.0, 5.0), Vector3(0.0, 0.0, 0.0))
	add_marker.call(stations_node, "dog_bowls", Vector3(-2.8, 0.0, -3.8), Vector3(0.0, -90.0, 0.0))
	add_marker.call(stations_node, "dog_bed", Vector3(-2.6, 0.0, 4.8), Vector3(0.0, 0.0, 0.0))

	# 7. CLUTTER SPAWNS NODE (~10 markers)
	var clutter_node = Node3D.new()
	clutter_node.name = "ClutterSpawns"
	root_node.add_child(clutter_node)

	add_marker.call(clutter_node, "Clutter_Entry_01", Vector3(0.5, 0.0, 4.0))
	add_marker.call(clutter_node, "Clutter_Hall_01", Vector3(0.0, 0.0, 2.8))
	add_marker.call(clutter_node, "Clutter_Living_01", Vector3(-2.5, 0.0, 0.8))
	add_marker.call(clutter_node, "Clutter_Living_02", Vector3(-4.0, 0.45, 2.0))
	add_marker.call(clutter_node, "Clutter_Living_03", Vector3(-5.5, 0.5, 2.4))
	add_marker.call(clutter_node, "Clutter_Kitchen_01", Vector3(-4.5, 0.9, -5.55))
	add_marker.call(clutter_node, "Clutter_Kitchen_02", Vector3(-3.8, 0.9, -2.0))
	add_marker.call(clutter_node, "Clutter_Bed_01", Vector3(3.2, 0.0, -1.0))
	add_marker.call(clutter_node, "Clutter_Bed_02", Vector3(3.0, 0.8, -5.55))
	add_marker.call(clutter_node, "Clutter_Bath_01", Vector3(3.2, 0.85, 5.55))
	add_marker.call(clutter_node, "Clutter_Bath_02", Vector3(4.2, 0.0, 4.2))

	# 8. SPAWN POINTS (group "spawn_points")
	var spawn_points_node = Node3D.new()
	spawn_points_node.name = "SpawnPoints"
	root_node.add_child(spawn_points_node)

	var spawn_default = add_marker.call(spawn_points_node, "default", Vector3(3.3, 0.0, -2.0), Vector3(0.0, 90.0, 0.0))
	spawn_default.add_to_group(&"spawn_points", true)

	var spawn_front_door = add_marker.call(spawn_points_node, "front_door", Vector3(0.0, 0.0, 4.4), Vector3(0.0, 0.0, 0.0))
	spawn_front_door.add_to_group(&"spawn_points", true)

	# 9. HUD instance
	var hud_scene = load("res://ui/hud/hud.tscn")
	var hud_instance = hud_scene.instantiate()
	root_node.add_child(hud_instance)

	# 10. Temporary bed interactable (debug-only on the bed, kept disabled before PR)
	var bed_interactable = Interactable.new()
	bed_interactable.name = "BedInteractable"
	bed_interactable.prompt_text = "Rest"
	bed_interactable.enabled = false
	bed_interactable.position = Vector3(4.8, 0.5, -3.2)
	var bed_col = CollisionShape3D.new()
	bed_col.name = "CollisionShape3D"
	var bed_box = BoxShape3D.new()
	bed_box.size = Vector3(2.2, 1.2, 2.4)
	bed_col.shape = bed_box
	bed_interactable.add_child(bed_col)
	root_node.add_child(bed_interactable)

	# 11. Player instance
	var player_scene = load("res://features/player/player.tscn")
	var player_instance = player_scene.instantiate()
	player_instance.name = "Player"
	root_node.add_child(player_instance)

	# BAKE NAVIGATION MESH
	print(">> Parsing and baking NavigationMesh...")
	var source_data = NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(nav_mesh, source_data, nav_region)
	if not source_data.has_data():
		push_error("Source geometry data is empty!")
		quit(1)
		return

	NavigationMeshGenerator.bake_from_source_geometry_data(nav_mesh, source_data)
	print(">> NavigationMesh baked: ", nav_mesh.get_polygon_count(), " polygons, ", nav_mesh.get_vertices().size(), " vertices.")

	if nav_mesh.get_polygon_count() == 0:
		push_error("NavigationMesh has 0 polygons!")
		quit(1)
		return

	# Verify vertices are within apartment interior (no roof, Y <= 1.5)
	var max_y: float = -999.0
	for v in nav_mesh.get_vertices():
		if v.y > max_y:
			max_y = v.y
	print(">> NavMesh maximum Y vertex: ", max_y)
	if max_y > 2.0:
		push_error("NavMesh contains vertices on the roof! Max Y: " + str(max_y))
		quit(1)
		return

	# Set owners recursively for scene packing
	_set_owners(root_node, root_node, [hud_instance, player_instance])

	# Pack and save scene
	var packed = PackedScene.new()
	var pack_err = packed.pack(root_node)
	if pack_err != OK:
		push_error("Failed to pack apartment scene: " + str(pack_err))
		quit(1)
		return

	var save_err = ResourceSaver.save(packed, APARTMENT_PATH)
	if save_err != OK:
		push_error("Failed to save apartment scene: " + str(save_err))
		quit(1)
		return

	print(">> Successfully saved apartment scene to: ", APARTMENT_PATH)
	root_node.queue_free()
	quit()
