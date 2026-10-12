extends GutTest

var wardrobe_scene: PackedScene


func before_each() -> void:
	InventoryManager.reset_state()
	wardrobe_scene = load("res://features/wardrobe/wardrobe_ui.tscn") as PackedScene


func after_each() -> void:
	InventoryManager.reset_state()


func test_wardrobe_ui_initial_state() -> void:
	var ui: WardrobeUI = wardrobe_scene.instantiate() as WardrobeUI
	add_child_autoqfree(ui)

	assert_false(ui.is_open, "UI initially closed")
	assert_false(ui.panel_root.visible, "Panel root initially hidden")


func test_wardrobe_ui_open_and_close() -> void:
	var ui: WardrobeUI = wardrobe_scene.instantiate() as WardrobeUI
	add_child_autoqfree(ui)

	watch_signals(ui)
	ui.open()

	assert_true(ui.is_open, "UI open")
	assert_true(ui.panel_root.visible, "Panel root visible when open")
	assert_gt(ui.items_container.get_child_count(), 0, "Items populated for top slot")

	ui.close()
	assert_false(ui.is_open, "UI closed")
	assert_false(ui.panel_root.visible, "Panel root hidden after close")
	assert_signal_emitted(ui, "closed")


func test_wardrobe_ui_tab_switch() -> void:
	var ui: WardrobeUI = wardrobe_scene.instantiate() as WardrobeUI
	add_child_autoqfree(ui)

	ui.open()
	# Switch to Dress tab (index 2)
	ui._on_tab_changed(2)

	assert_eq(ui._current_slot, Enums.Slot.DRESS, "Current slot switched to DRESS")
	assert_gt(ui.items_container.get_child_count(), 0, "Dress items populated")


func test_wardrobe_ui_empty_slot_shows_message() -> void:
	var ui: WardrobeUI = wardrobe_scene.instantiate() as WardrobeUI
	add_child_autoqfree(ui)

	ui.open()
	# Switch to Outerwear tab (index 4) - no outerwear currently owned
	ui._on_tab_changed(4)

	assert_eq(ui._current_slot, Enums.Slot.OUTERWEAR)
	assert_eq(ui.items_container.get_child_count(), 1, "One child (empty panel)")
	var panel: PanelContainer = ui.items_container.get_child(0) as PanelContainer
	assert_not_null(panel)
	var label: Label = panel.get_child(0) as Label
	assert_not_null(label)
	assert_true("No items owned" in label.text)


func test_wardrobe_ui_equip_and_unequip_action() -> void:
	var ui: WardrobeUI = wardrobe_scene.instantiate() as WardrobeUI
	add_child_autoqfree(ui)

	ui.open()
	assert_eq(ui._current_slot, Enums.Slot.TOP)

	var chic_blouse: ClothingItem = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem
	var peasant_tunic: ClothingItem = load("res://data/clothing/top/top_peasant_tunic.tres") as ClothingItem

	# Starting outfit has peasant tunic equipped
	assert_eq(InventoryManager.get_equipped(Enums.Slot.TOP).id, peasant_tunic.id)

	# Find Chic Blouse card and its button
	var blouse_card: Control = ui.items_container.get_node_or_null("ItemCard_top_chic_blouse") as Control
	assert_not_null(blouse_card, "Chic blouse card exists in UI")

	var tag_chips: Node = blouse_card.find_child("TagChips", true, false)
	assert_not_null(tag_chips, "Tag chips row exists")
	assert_gt(tag_chips.get_child_count(), 0, "Tag chips rendered")

	var button: Button = null
	for child: Node in blouse_card.get_child(0).get_children():
		if child is Button:
			button = child as Button
			break

	assert_not_null(button, "Action button found")
	assert_eq(button.text, "Equip", "Button says Equip")

	# Press Equip
	button.pressed.emit()

	# Assert blouse is now equipped
	assert_eq(InventoryManager.get_equipped(Enums.Slot.TOP).id, chic_blouse.id, "Blouse is now equipped")

	# Refresh happens live - check button now says Unequip on blouse card
	blouse_card = ui.items_container.get_node_or_null("ItemCard_top_chic_blouse") as Control
	assert_not_null(blouse_card)
	for child: Node in blouse_card.get_child(0).get_children():
		if child is Button:
			button = child as Button
			break
	assert_eq(button.text, "Unequip", "Button now says Unequip")

	# Press Unequip
	button.pressed.emit()
	assert_null(InventoryManager.get_equipped(Enums.Slot.TOP), "Top slot now unequipped")


func test_wardrobe_ui_ui_cancel_closes() -> void:
	var ui: WardrobeUI = wardrobe_scene.instantiate() as WardrobeUI
	add_child_autoqfree(ui)

	ui.open()
	assert_true(ui.is_open)

	watch_signals(ui)

	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	ui._unhandled_input(ev)

	assert_false(ui.is_open, "ui_cancel closes wardrobe")
	assert_signal_emitted(ui, "closed")
