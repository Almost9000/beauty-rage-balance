extends GutTest

var top_item: ClothingItem
var bot_item: ClothingItem
var dress_item: ClothingItem
var shoes_item: ClothingItem


func before_each() -> void:
	top_item = load("res://data/clothing/top/top_peasant_tunic.tres") as ClothingItem
	bot_item = load("res://data/clothing/bottom/bottom_peasant_skirt.tres") as ClothingItem
	dress_item = load("res://data/clothing/dress/dress_peasant_ensemble.tres") as ClothingItem
	shoes_item = load("res://data/clothing/shoes/shoes_peasant_boots.tres") as ClothingItem
	InventoryManager.reset_state()


func after_each() -> void:
	InventoryManager.reset_state()


func test_default_state_loads_starting_inventory() -> void:
	assert_true(InventoryManager.owned_clothing.size() >= 4, "Starting inventory has at least 4 items")
	assert_true(InventoryManager.owns(top_item), "Owns starting top")
	assert_true(InventoryManager.owns(bot_item), "Owns starting bottom")
	assert_true(InventoryManager.owns(shoes_item), "Owns starting shoes")
	assert_true(InventoryManager.owns(dress_item), "Owns starting dress")

	assert_eq(InventoryManager.get_equipped(Enums.Slot.TOP).id, top_item.id, "Equipped top matches starting inventory")
	assert_eq(InventoryManager.get_equipped(Enums.Slot.BOTTOM).id, bot_item.id, "Equipped bottom matches starting inventory")
	assert_eq(InventoryManager.get_equipped(Enums.Slot.SHOES).id, shoes_item.id, "Equipped shoes match starting inventory")
	assert_null(InventoryManager.get_equipped(Enums.Slot.DRESS), "Dress is not equipped initially")


func test_owns_and_add_owned() -> void:
	var custom_item: ClothingItem = ClothingItem.new()
	custom_item.id = &"test_hat"
	custom_item.display_name = "Test Hat"
	custom_item.slot = Enums.Slot.ACCESSORY

	assert_false(InventoryManager.owns(custom_item), "Does not own test hat yet")

	watch_signals(InventoryManager)
	InventoryManager.add_owned(custom_item)
	assert_signal_emitted_with_parameters(InventoryManager, "item_added", [custom_item])
	assert_true(InventoryManager.owns(custom_item), "Owns test hat after add_owned")

	# Duplicate addition should not duplicate
	var count_before: int = InventoryManager.owned_clothing.size()
	InventoryManager.add_owned(custom_item)
	assert_eq(InventoryManager.owned_clothing.size(), count_before, "Duplicate item is not added twice")


func test_slot_rules_equipping_dress_unequips_top_and_bottom() -> void:
	# Initially TOP and BOTTOM are equipped
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Top equipped before dress")
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.BOTTOM), "Bottom equipped before dress")

	watch_signals(InventoryManager)
	InventoryManager.equip(dress_item)

	assert_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Equipping dress unequips top")
	assert_null(InventoryManager.get_equipped(Enums.Slot.BOTTOM), "Equipping dress unequips bottom")
	assert_eq(InventoryManager.get_equipped(Enums.Slot.DRESS).id, dress_item.id, "Dress is now equipped")


func test_slot_rules_equipping_top_or_bottom_unequips_dress() -> void:
	InventoryManager.equip(dress_item)
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.DRESS), "Dress equipped")

	InventoryManager.equip(top_item)
	assert_null(InventoryManager.get_equipped(Enums.Slot.DRESS), "Equipping top unequips dress")
	assert_eq(InventoryManager.get_equipped(Enums.Slot.TOP).id, top_item.id, "Top is now equipped")

	# Re-equip dress, then equip bottom
	InventoryManager.equip(dress_item)
	assert_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Re-equipping dress unequips top")
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.DRESS), "Dress equipped again")

	InventoryManager.equip(bot_item)
	assert_null(InventoryManager.get_equipped(Enums.Slot.DRESS), "Equipping bottom unequips dress")
	assert_eq(InventoryManager.get_equipped(Enums.Slot.BOTTOM).id, bot_item.id, "Bottom is now equipped")


func test_unequip_slot() -> void:
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Top is equipped")

	watch_signals(InventoryManager)
	InventoryManager.unequip(Enums.Slot.TOP)

	assert_signal_emitted_with_parameters(InventoryManager, "outfit_changed", [Enums.Slot.TOP, null])
	assert_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Top is now unequipped")


func test_to_dict_and_from_dict_resref_round_trip() -> void:
	# Equip dress and shoes
	InventoryManager.equip(dress_item)
	InventoryManager.equip(shoes_item)

	var saved_dict: Dictionary = InventoryManager.to_dict()
	assert_true(saved_dict.has("owned_clothing"), "Save has owned_clothing")
	assert_true(saved_dict.has("equipped"), "Save has equipped")

	# Clear inventory
	InventoryManager.unequip(Enums.Slot.DRESS)
	InventoryManager.unequip(Enums.Slot.SHOES)
	InventoryManager.owned_clothing.clear()
	assert_eq(InventoryManager.equipped.size(), 0, "Equipped is cleared")
	assert_eq(InventoryManager.owned_clothing.size(), 0, "Owned is cleared")

	# Restore from dict
	InventoryManager.from_dict(saved_dict)

	assert_true(InventoryManager.owned_clothing.size() >= 4, "Owned clothing restored")
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.DRESS), "Dress restored to equipped")
	assert_eq(InventoryManager.get_equipped(Enums.Slot.DRESS).id, dress_item.id, "Dress id matches")
	assert_not_null(InventoryManager.get_equipped(Enums.Slot.SHOES), "Shoes restored to equipped")
	assert_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Top remains unequipped")
	assert_null(InventoryManager.get_equipped(Enums.Slot.BOTTOM), "Bottom remains unequipped")
