extends GutTest

var avatar_scene: PackedScene
var avatar: OutfitSlots
var top_item: ClothingItem
var bot_item: ClothingItem
var dress_item: ClothingItem
var shoes_item: ClothingItem


func before_each() -> void:
	avatar_scene = load("res://features/avatar/avatar.tscn") as PackedScene
	top_item = load("res://data/clothing/top/top_peasant_tunic.tres") as ClothingItem
	bot_item = load("res://data/clothing/bottom/bottom_peasant_skirt.tres") as ClothingItem
	dress_item = load("res://data/clothing/dress/dress_peasant_ensemble.tres") as ClothingItem
	shoes_item = load("res://data/clothing/shoes/shoes_peasant_boots.tres") as ClothingItem

	avatar = avatar_scene.instantiate() as OutfitSlots
	add_child_autofree(avatar)
	for slot in Enums.Slot.values():
		avatar.unequip(slot)


func test_avatar_scene_structure() -> void:
	assert_not_null(avatar.skeleton, "Skeleton3D found on Avatar")
	assert_not_null(avatar.body_mesh, "Body mesh found on Avatar")
	assert_not_null(avatar.animation_player, "AnimationPlayer found on Avatar")
	assert_not_null(avatar.body_mesh.material_override, "Body mesh material_override is set")
	assert_true(avatar.body_mesh.material_override is ShaderMaterial, "Body material is ShaderMaterial")


func test_equip_garment_attaches_mesh_under_skeleton_with_relative_path() -> void:
	avatar.equip(top_item)

	var meshes: Array[MeshInstance3D] = avatar.get_slot_meshes(Enums.Slot.TOP)
	assert_true(meshes.size() > 0, "At least one mesh attached for TOP slot")

	for mesh: MeshInstance3D in meshes:
		assert_eq(mesh.get_parent(), avatar.skeleton, "Garment mesh is direct child of Skeleton3D")
		assert_eq(mesh.skeleton, NodePath(".."), "Garment mesh skeleton property points to '..'")

	assert_eq(avatar.get_equipped(Enums.Slot.TOP), top_item, "Equipped item in TOP slot matches")


func test_hidden_regions_shader_uniform_updated_on_equip() -> void:
	# Equipping top hides TORSO (bit 2 = 2)
	avatar.equip(top_item)
	assert_eq(avatar.get_hidden_regions() & 2, 2, "TORSO bit set when top equipped")
	var mat: ShaderMaterial = avatar.body_mesh.material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("hidden_regions"), avatar.get_hidden_regions(), "Shader uniform matches get_hidden_regions()")

	# Equipping bottom hides LEGS (bit 16 = 16)
	avatar.equip(bot_item)
	assert_eq(avatar.get_hidden_regions(), 2 | 16, "TORSO and LEGS hidden when top and bottom equipped")

	# Equipping shoes hides FEET (bit 32 = 32)
	avatar.equip(shoes_item)
	assert_eq(avatar.get_hidden_regions(), 2 | 16 | 32, "TORSO, LEGS, FEET hidden")


func test_dress_replaces_top_and_bottom_meshes() -> void:
	avatar.equip(top_item)
	avatar.equip(bot_item)
	assert_true(avatar.get_slot_meshes(Enums.Slot.TOP).size() > 0, "Top meshes present")
	assert_true(avatar.get_slot_meshes(Enums.Slot.BOTTOM).size() > 0, "Bottom meshes present")

	# Equipping dress should clear top and bottom
	avatar.equip(dress_item)
	assert_eq(avatar.get_slot_meshes(Enums.Slot.TOP).size(), 0, "Top meshes cleared")
	assert_eq(avatar.get_slot_meshes(Enums.Slot.BOTTOM).size(), 0, "Bottom meshes cleared")
	assert_true(avatar.get_slot_meshes(Enums.Slot.DRESS).size() > 0, "Dress meshes present")
	assert_null(avatar.get_equipped(Enums.Slot.TOP), "Top slot is null")
	assert_null(avatar.get_equipped(Enums.Slot.BOTTOM), "Bottom slot is null")
	assert_eq(avatar.get_equipped(Enums.Slot.DRESS), dress_item, "Dress slot matches")


func test_unequip_frees_mesh_and_clears_hidden_regions() -> void:
	avatar.equip(shoes_item)
	assert_true(avatar.get_slot_meshes(Enums.Slot.SHOES).size() > 0, "Shoes mesh attached")
	var shoe_mesh: MeshInstance3D = avatar.get_slot_meshes(Enums.Slot.SHOES)[0]

	avatar.unequip(Enums.Slot.SHOES)
	assert_eq(avatar.get_slot_meshes(Enums.Slot.SHOES).size(), 0, "Shoes mesh array cleared")
	assert_null(avatar.get_equipped(Enums.Slot.SHOES), "Shoes slot is null")
	assert_eq(avatar.get_hidden_regions(), 0, "Hidden regions reset to 0")


func test_movement_speed_drives_animation() -> void:
	if avatar.animation_player == null:
		return

	avatar.set_movement_speed(0.0)
	assert_eq(avatar.animation_player.current_animation, "Idle", "Idle animation played when stationary")

	avatar.set_movement_speed(3.5, 4.0)
	assert_eq(avatar.animation_player.current_animation, "Walk", "Walk animation played when moving")

	avatar.set_movement_speed(0.0)
	assert_eq(avatar.animation_player.current_animation, "Idle", "Idle animation resumed when stopped")
