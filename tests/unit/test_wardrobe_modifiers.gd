extends GutTest

var top_item: ClothingItem
var bot_item: ClothingItem
var dress_item: ClothingItem
var shoes_item: ClothingItem
var chic_top: ClothingItem


func before_each() -> void:
	StatusManager.reset_state()
	InventoryManager.reset_state()
	top_item = load("res://data/clothing/top/top_peasant_tunic.tres") as ClothingItem
	bot_item = load("res://data/clothing/bottom/bottom_peasant_skirt.tres") as ClothingItem
	dress_item = load("res://data/clothing/dress/dress_peasant_ensemble.tres") as ClothingItem
	shoes_item = load("res://data/clothing/shoes/shoes_peasant_boots.tres") as ClothingItem
	chic_top = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem


func after_each() -> void:
	StatusManager.reset_state()
	InventoryManager.reset_state()


func _get_outfit_modifiers(slot_source: StringName) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for mod: StatModifier in StatusManager.get_modifiers():
		if mod and mod.source_id == slot_source:
			result.append(mod)
	return result


func test_starting_inventory_outfit_modifiers_registered() -> void:
	var top_mods: Array[StatModifier] = _get_outfit_modifiers(&"outfit:top")
	assert_gt(top_mods.size(), 0, "Top outfit modifier registered")
	assert_eq(top_mods[0].source_id, &"outfit:top")

	var bot_mods: Array[StatModifier] = _get_outfit_modifiers(&"outfit:bottom")
	assert_gt(bot_mods.size(), 0, "Bottom outfit modifier registered")
	assert_eq(bot_mods[0].source_id, &"outfit:bottom")

	var shoes_mods: Array[StatModifier] = _get_outfit_modifiers(&"outfit:shoes")
	assert_gt(shoes_mods.size(), 0, "Shoes outfit modifier registered")
	assert_eq(shoes_mods[0].source_id, &"outfit:shoes")

	var dress_mods: Array[StatModifier] = _get_outfit_modifiers(&"outfit:dress")
	assert_eq(dress_mods.size(), 0, "Dress outfit modifier not registered initially")


func test_equip_item_replaces_slot_modifier() -> void:
	var top_mods_before: Array[StatModifier] = _get_outfit_modifiers(&"outfit:top")
	assert_gt(top_mods_before.size(), 0)
	var old_val: float = top_mods_before[0].value

	# Equip chic blouse
	InventoryManager.equip(chic_top)

	var top_mods_after: Array[StatModifier] = _get_outfit_modifiers(&"outfit:top")
	assert_eq(top_mods_after.size(), 1, "Exactly one modifier for top slot")
	assert_ne(top_mods_after[0].value, old_val, "Top modifier replaced with new item's value")
	assert_eq(top_mods_after[0].source_id, &"outfit:top")
	assert_eq(top_mods_after[0].value, 0.8, "Chic blouse provides +0.8 Sanity")


func test_unequip_removes_slot_modifier() -> void:
	assert_gt(_get_outfit_modifiers(&"outfit:top").size(), 0, "Top modifier active before unequip")

	InventoryManager.unequip(Enums.Slot.TOP)

	assert_eq(_get_outfit_modifiers(&"outfit:top").size(), 0, "Top modifier removed after unequip")


func test_dress_rule_replaces_top_and_bottom_modifiers() -> void:
	# Initially TOP and BOTTOM modifiers exist
	assert_gt(_get_outfit_modifiers(&"outfit:top").size(), 0, "Top modifier active")
	assert_gt(_get_outfit_modifiers(&"outfit:bottom").size(), 0, "Bottom modifier active")
	assert_eq(_get_outfit_modifiers(&"outfit:dress").size(), 0, "Dress modifier inactive")

	# Equip dress
	InventoryManager.equip(dress_item)

	assert_eq(_get_outfit_modifiers(&"outfit:top").size(), 0, "Top modifier removed by dress rule")
	assert_eq(_get_outfit_modifiers(&"outfit:bottom").size(), 0, "Bottom modifier removed by dress rule")
	assert_gt(_get_outfit_modifiers(&"outfit:dress").size(), 0, "Dress modifier added")
	assert_eq(_get_outfit_modifiers(&"outfit:dress")[0].source_id, &"outfit:dress")


func test_equipping_top_unequips_dress_and_replaces_modifiers() -> void:
	InventoryManager.equip(dress_item)
	assert_gt(_get_outfit_modifiers(&"outfit:dress").size(), 0, "Dress modifier active")

	# Equip top
	InventoryManager.equip(top_item)

	assert_eq(_get_outfit_modifiers(&"outfit:dress").size(), 0, "Dress modifier removed when equipping top")
	assert_gt(_get_outfit_modifiers(&"outfit:top").size(), 0, "Top modifier active again")
