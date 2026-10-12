extends GutTest

var countdown_label_scene: PackedScene
var prep_checklist_scene: PackedScene
var girls_day_out: OutingData


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()

	countdown_label_scene = load("res://ui/widgets/countdown_label.tscn") as PackedScene
	prep_checklist_scene = load("res://features/prep/prep_checklist_ui.tscn") as PackedScene
	girls_day_out = load("res://data/outings/girls_day_out.tres") as OutingData


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()


func test_countdown_label_updates_with_clock() -> void:
	var label: CountdownLabel = countdown_label_scene.instantiate() as CountdownLabel
	label.countdown_id = &"test_timer"
	label.prefix = "Remaining: "
	add_child_autoqfree(label)

	GameClock.create_countdown(&"test_timer", GameClock.now_minutes + 75)
	label.update_display()
	assert_eq(label.text, "Remaining: 01:15")

	GameClock.advance_minutes(30)
	assert_eq(label.text, "Remaining: 00:45")


func test_prep_checklist_ui_hidden_initially_and_shows_on_prep_start() -> void:
	var ui: PrepChecklistUI = prep_checklist_scene.instantiate() as PrepChecklistUI
	add_child_autoqfree(ui)

	# Initially not in prep -> hidden
	assert_false(ui.visible)

	# Schedule outing and advance into prep window
	OutingManager.schedule(girls_day_out, 600, "Chloe")
	assert_false(ui.visible)

	GameClock.advance_minutes(90)  # now 510, prep starts
	assert_true(ui.visible)
	assert_true(ui.title_label.text.contains("GIRLS' DAY OUT"))


func test_prep_checklist_ui_live_updates_on_stat_change() -> void:
	var ui: PrepChecklistUI = prep_checklist_scene.instantiate() as PrepChecklistUI
	add_child_autoqfree(ui)

	# Start prep
	StatusManager.set_value(Enums.Stat.HYGIENE, 30.0)
	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(90)  # now 510, prep active

	# Verify hygiene check is currently failing in UI
	var found_hygiene_row: bool = false
	for row_node: Node in ui.checklist_container.get_children():
		var row: HBoxContainer = row_node as HBoxContainer
		if row and row.get_child_count() >= 2:
			var label: Label = row.get_child(1) as Label
			if label.text.contains("Shower"):
				found_hygiene_row = true
				var status_lbl: Label = row.get_child(0) as Label
				assert_eq(status_lbl.text, "[ ]")
	assert_true(found_hygiene_row)

	# Now change hygiene stat via StatusManager
	StatusManager.set_value(Enums.Stat.HYGIENE, 85.0)

	# Verify UI updated live
	for row_node: Node in ui.checklist_container.get_children():
		var row: HBoxContainer = row_node as HBoxContainer
		if row and row.get_child_count() >= 2:
			var label: Label = row.get_child(1) as Label
			if label.text.contains("Shower"):
				var status_lbl: Label = row.get_child(0) as Label
				assert_eq(status_lbl.text, "[✓]")


func test_prep_checklist_ui_live_updates_on_outfit_and_look_change() -> void:
	var ui: PrepChecklistUI = prep_checklist_scene.instantiate() as PrepChecklistUI
	add_child_autoqfree(ui)

	InventoryManager.equipped.clear()
	InventoryManager.clear_look()
	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(90)  # 510 prep active

	# Equip a casual item
	var casual_top: ClothingItem = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem
	InventoryManager.equip(casual_top)

	# Verify outfit check reflects passed
	var outfit_passed: bool = false
	for row_node: Node in ui.checklist_container.get_children():
		var row: HBoxContainer = row_node as HBoxContainer
		if row and row.get_child_count() >= 2:
			var label: Label = row.get_child(1) as Label
			if label.text.contains("Casual"):
				var status_lbl: Label = row.get_child(0) as Label
				if status_lbl.text == "[✓]":
					outfit_passed = true
	assert_true(outfit_passed)
