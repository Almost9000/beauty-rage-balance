extends GutTest

var avatar_scene: PackedScene
var avatar: OutfitSlots
var inv: Node


func before_each() -> void:
	inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("reset_state"):
		inv.call("reset_state")
	avatar_scene = load("res://features/avatar/avatar.tscn") as PackedScene
	avatar = avatar_scene.instantiate() as OutfitSlots
	add_child_autofree(avatar)


func test_cosmetic_item_properties() -> void:
	var item: CosmeticItem = CosmeticItem.new()
	assert_false(item.is_valid(), "Empty cosmetic item is invalid")

	item.id = &"test_lipstick"
	item.display_name = "Ruby Kiss"
	item.layer = Enums.MakeupLayer.LIPSTICK
	item.tint = Color.RED
	item.price_cents = 1500
	assert_true(item.is_valid(), "Cosmetic item with id is valid")
	assert_eq(item.layer, Enums.MakeupLayer.LIPSTICK)
	assert_eq(item.price_cents, 1500)


func test_makeup_look_score_empty() -> void:
	var look: MakeupLook = MakeupLook.new()
	assert_eq(look.score(), 0.0, "Empty look has score 0.0")


func test_makeup_look_score_calculation() -> void:
	var look: MakeupLook = MakeupLook.new()
	var c1: CosmeticItem = CosmeticItem.new()
	c1.id = &"c1"
	var c2: CosmeticItem = CosmeticItem.new()
	c2.id = &"c2"

	look.set_layer(Enums.MakeupLayer.BASE, c1, 0.8, Vector2.ZERO, 0.9)
	assert_almost_eq(look.score(), 0.9, 0.001, "Single layer look score matches accuracy")

	look.set_layer(Enums.MakeupLayer.BLUSH, c2, 0.5, Vector2.ZERO, 0.7)
	assert_almost_eq(look.score(), (0.9 + 0.7) / 2.0, 0.001, "Two layer look score is mean accuracy")


func test_makeup_look_layer_accessors() -> void:
	var look: MakeupLook = MakeupLook.new()
	var c: CosmeticItem = CosmeticItem.new()
	c.id = &"blush_test"

	assert_false(look.has_layer(Enums.MakeupLayer.BLUSH), "Does not have layer initially")
	look.set_layer(Enums.MakeupLayer.BLUSH, c, 0.75, Vector2(0.01, -0.02), 0.85)
	assert_true(look.has_layer(Enums.MakeupLayer.BLUSH), "Has layer after set_layer")

	var entry: Dictionary = look.get_layer(Enums.MakeupLayer.BLUSH)
	assert_eq(entry.get("cosmetic"), c, "Cosmetic matches")
	assert_almost_eq(float(entry.get("opacity")), 0.75, 0.001, "Opacity matches")
	assert_eq(entry.get("smudge"), Vector2(0.01, -0.02), "Smudge matches")
	assert_almost_eq(float(entry.get("accuracy")), 0.85, 0.001, "Accuracy matches")

	look.clear_layer(Enums.MakeupLayer.BLUSH)
	assert_false(look.has_layer(Enums.MakeupLayer.BLUSH), "Layer cleared after clear_layer")


func test_inventory_manager_owned_cosmetics_and_signals() -> void:
	assert_not_null(inv, "InventoryManager exists")
	assert_true(inv.owned_cosmetics.size() >= 10, "Starting inventory loaded at least 10 cosmetics")

	watch_signals(inv)

	var natural_look: MakeupLook = load("res://data/looks/natural.tres") as MakeupLook
	assert_not_null(natural_look, "Natural look resource loads")

	inv.set_look(natural_look)
	assert_signal_emitted_with_parameters(inv, "look_changed", [natural_look])
	assert_eq(inv.current_look, natural_look, "Current look set on InventoryManager")

	inv.clear_look()
	assert_signal_emitted_with_parameters(inv, "look_changed", [null])
	assert_null(inv.current_look, "Current look cleared on InventoryManager")


func test_inventory_manager_look_round_trip_serialization() -> void:
	assert_not_null(inv, "InventoryManager exists")

	var lipstick: CosmeticItem = load("res://data/cosmetics/lipstick/lipstick_crimson_velvet.tres") as CosmeticItem
	var blush: CosmeticItem = load("res://data/cosmetics/blush/blush_soft_rose.tres") as CosmeticItem
	assert_not_null(lipstick, "Lipstick cosmetic loads")
	assert_not_null(blush, "Blush cosmetic loads")

	var look: MakeupLook = MakeupLook.new()
	look.id = &"test_custom_look"
	look.display_name = "Custom Evening"
	look.set_layer(Enums.MakeupLayer.LIPSTICK, lipstick, 0.85, Vector2(0.005, -0.002), 0.92)
	look.set_layer(Enums.MakeupLayer.BLUSH, blush, 0.60, Vector2(0.0, 0.01), 0.88)

	inv.set_look(look)

	# Serialize to JSON-safe dictionary
	var data: Dictionary = inv.to_dict()
	assert_true(data.has("current_look"), "to_dict includes current_look")
	assert_not_null(data["current_look"], "current_look is not null in dict")
	assert_true(data["current_look"] is Dictionary, "current_look is a dictionary")

	# Verify JSON serialization does not fail (ADR-11)
	var json_str: String = JSON.stringify(data)
	assert_true(json_str.length() > 0, "JSON stringify succeeds")
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "JSON parsed back to dictionary")

	# Reset state and restore from parsed dict
	inv.reset_state()
	assert_null(inv.current_look, "Reset cleared look")

	inv.from_dict(parsed as Dictionary)
	assert_not_null(inv.current_look, "Look restored from dict")
	var restored: MakeupLook = inv.current_look as MakeupLook
	assert_eq(restored.id, look.id, "Look id matches")
	assert_eq(restored.display_name, look.display_name, "Display name matches")
	assert_almost_eq(restored.score(), look.score(), 0.001, "Score matches")

	# Check layers
	assert_true(restored.has_layer(Enums.MakeupLayer.LIPSTICK), "Has restored lipstick layer")
	var restored_lips: Dictionary = restored.get_layer(Enums.MakeupLayer.LIPSTICK)
	assert_not_null(restored_lips.get("cosmetic"), "Restored lipstick cosmetic is not null")
	assert_eq((restored_lips["cosmetic"] as CosmeticItem).id, lipstick.id, "Lipstick id matches")
	assert_almost_eq(float(restored_lips["opacity"]), 0.85, 0.001, "Lipstick opacity matches")
	assert_almost_eq((restored_lips["smudge"] as Vector2).x, 0.005, 0.001, "Lipstick smudge X matches")
	assert_almost_eq((restored_lips["smudge"] as Vector2).y, -0.002, 0.001, "Lipstick smudge Y matches")
	assert_almost_eq(float(restored_lips["accuracy"]), 0.92, 0.001, "Lipstick accuracy matches")


func test_avatar_face_makeup_component_and_single_material() -> void:
	assert_not_null(avatar.face_makeup, "FaceMakeup component exists on Avatar")
	assert_not_null(avatar.body_mesh.material_override, "Avatar has body material override")
	assert_true(avatar.body_mesh.material_override is ShaderMaterial, "Material is ShaderMaterial")

	var mat: ShaderMaterial = avatar.body_mesh.material_override as ShaderMaterial
	assert_eq(avatar.face_makeup.body_material, mat, "FaceMakeup shares identical ShaderMaterial instance")

	# Apply glam look
	var glam_look: MakeupLook = load("res://data/looks/glam.tres") as MakeupLook
	assert_not_null(glam_look, "Glam look loads")

	avatar.face_makeup.apply_look(glam_look)

	# Verify shader uniforms updated
	var lipstick_opacity: float = float(mat.get_shader_parameter("lipstick_opacity"))
	assert_almost_eq(lipstick_opacity, 0.95, 0.001, "Lipstick opacity uniform set")
	var eyeliner_opacity: float = float(mat.get_shader_parameter("eyeliner_opacity"))
	assert_almost_eq(eyeliner_opacity, 0.95, 0.001, "Eyeliner opacity uniform set")

	# Test individual opacity and smudge adjustments
	avatar.face_makeup.set_layer_opacity(Enums.MakeupLayer.BLUSH, 0.33)
	assert_almost_eq(float(mat.get_shader_parameter("blush_opacity")), 0.33, 0.001, "Blush opacity slider uniform set")

	avatar.face_makeup.set_layer_smudge(Enums.MakeupLayer.EYESHADOW, Vector2(0.04, -0.03))
	assert_eq(mat.get_shader_parameter("eyeshadow_smudge"), Vector2(0.04, -0.03), "Eyeshadow smudge uniform set")

	# Clear look
	avatar.face_makeup.clear()
	assert_almost_eq(float(mat.get_shader_parameter("lipstick_opacity")), 0.0, 0.001, "Lipstick opacity cleared to 0")
	assert_almost_eq(float(mat.get_shader_parameter("blush_opacity")), 0.0, 0.001, "Blush opacity cleared to 0")
	assert_almost_eq(float(mat.get_shader_parameter("eyeliner_opacity")), 0.0, 0.001, "Eyeliner opacity cleared to 0")


func test_preset_looks_differ() -> void:
	var natural: MakeupLook = load("res://data/looks/natural.tres") as MakeupLook
	var glam: MakeupLook = load("res://data/looks/glam.tres") as MakeupLook

	assert_not_null(natural, "Natural look loaded")
	assert_not_null(glam, "Glam look loaded")

	var natural_lips: Dictionary = natural.get_layer(Enums.MakeupLayer.LIPSTICK)
	var glam_lips: Dictionary = glam.get_layer(Enums.MakeupLayer.LIPSTICK)

	var natural_cosmetic: CosmeticItem = natural_lips.get("cosmetic") as CosmeticItem
	var glam_cosmetic: CosmeticItem = glam_lips.get("cosmetic") as CosmeticItem

	assert_not_null(natural_cosmetic, "Natural look has lipstick cosmetic")
	assert_not_null(glam_cosmetic, "Glam look has lipstick cosmetic")
	assert_ne(natural_cosmetic.id, glam_cosmetic.id, "Natural and Glam have different lipstick cosmetics")
	assert_ne(natural_cosmetic.tint, glam_cosmetic.tint, "Natural and Glam have visibly different lip tints")
