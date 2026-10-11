extends GutTest

func test_debug_panel_api() -> void:
	var panel: CanvasLayer = load("res://ui/debug/debug_panel.tscn").instantiate()
	add_child_autoqfree(panel)

	var panel_root: Control = panel.get_node("PanelRoot") as Control
	assert_not_null(panel_root)
	assert_false(panel_root.visible)

	panel.toggle_panel()
	assert_true(panel_root.visible)

	var section: Container = panel.add_section("TestSection")
	assert_not_null(section)

	var button_clicked: Array[bool] = [false]
	var btn: Button = panel.add_button(section, "ClickMe", func() -> void: button_clicked[0] = true)
	assert_not_null(btn)
	btn.pressed.emit()
	assert_true(button_clicked[0])

	var watched_val: int = 42
	panel.add_watch(section, "WatchInt", func() -> int: return watched_val)
	panel._refresh_watches()

	var watch_found: bool = false
	for child: Node in section.get_children():
		if child is HBoxContainer:
			for subchild: Node in child.get_children():
				if subchild is Label and (subchild as Label).text == "42":
					watch_found = true
					break
	assert_true(watch_found, "Watch value should be displayed in label")

	panel.toggle_panel()
	assert_false(panel_root.visible)

func test_debug_panel_time_section() -> void:
	GameClock.reset_state()
	var panel: CanvasLayer = load("res://ui/debug/debug_panel.tscn").instantiate()
	add_child_autoqfree(panel)

	panel.toggle_panel()

	var sections_container: Node = panel.get_node("PanelRoot/MarginContainer/VBoxContainer/ScrollContainer/SectionsContainer")
	assert_not_null(sections_container)

	var time_section_node: Node = sections_container.get_node_or_null("Time")
	assert_not_null(time_section_node, "Time section should exist in DebugPanel")

	var items: Container = time_section_node.get_node_or_null("Items") as Container
	assert_not_null(items)

	# Test +1 h button
	var skip_1h_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text.begins_with("+1 h"):
			skip_1h_btn = child as Button
			break
	assert_not_null(skip_1h_btn, "+1 h button should exist")
	skip_1h_btn.pressed.emit()
	assert_eq(GameClock.now_minutes, 480)

	# Test +1 d button
	var skip_1d_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text.begins_with("+1 d"):
			skip_1d_btn = child as Button
			break
	assert_not_null(skip_1d_btn, "+1 d button should exist")
	skip_1d_btn.pressed.emit()
	assert_eq(GameClock.now_minutes, 480 + 1440)

	# Test toggle pause button
	var pause_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text.begins_with("Pause"):
			pause_btn = child as Button
			break
	assert_not_null(pause_btn, "Pause button should exist")
	assert_false(GameClock.is_paused())
	pause_btn.pressed.emit()
	assert_true(GameClock.is_paused())
	pause_btn.pressed.emit()
	assert_false(GameClock.is_paused())

	# Test scale buttons
	var scale_60_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text == "Scale x60":
			scale_60_btn = child as Button
			break
	assert_not_null(scale_60_btn, "Scale x60 button should exist")
	scale_60_btn.pressed.emit()
	assert_eq(GameClock.time_scale, 60.0)

	GameClock.reset_state()

func test_debug_panel_stats_section() -> void:
	StatusManager.reset_state()
	var panel: CanvasLayer = load("res://ui/debug/debug_panel.tscn").instantiate()
	add_child_autoqfree(panel)

	panel.toggle_panel()

	var sections_container: Node = panel.get_node("PanelRoot/MarginContainer/VBoxContainer/ScrollContainer/SectionsContainer")
	assert_not_null(sections_container)

	var stats_section_node: Node = sections_container.get_node_or_null("Stats")
	assert_not_null(stats_section_node, "Stats section should exist in DebugPanel")

	var items: Container = stats_section_node.get_node_or_null("Items") as Container
	assert_not_null(items)

	# Test Sanity = 50 button
	var set_sanity_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text == "Sanity = 50":
			set_sanity_btn = child as Button
			break
	assert_not_null(set_sanity_btn, "Sanity = 50 button should exist")
	set_sanity_btn.pressed.emit()
	assert_eq(StatusManager.get_value(Enums.Stat.SANITY), 50.0)

	# Test Add Test +5/h modifier button
	var initial_rate: float = StatusManager.get_effective_rate(Enums.Stat.SANITY)
	var add_pos_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text.begins_with("Add Test +5/h"):
			add_pos_btn = child as Button
			break
	assert_not_null(add_pos_btn, "Add Test +5/h button should exist")
	add_pos_btn.pressed.emit()
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), initial_rate + 5.0, 1e-4)

	# Test Clear Test Modifiers button
	var clear_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text.begins_with("Clear Test"):
			clear_btn = child as Button
			break
	assert_not_null(clear_btn, "Clear Test Modifiers button should exist")
	clear_btn.pressed.emit()
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), initial_rate, 1e-4)

	StatusManager.reset_state()

func test_debug_panel_cycle_section() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()

	var panel: CanvasLayer = load("res://ui/debug/debug_panel.tscn").instantiate()
	add_child_autoqfree(panel)

	panel.toggle_panel()

	var sections_container: Node = panel.get_node("PanelRoot/MarginContainer/VBoxContainer/ScrollContainer/SectionsContainer")
	assert_not_null(sections_container)

	var cycle_section_node: Node = sections_container.get_node_or_null("Cycle")
	assert_not_null(cycle_section_node, "Cycle section should exist in DebugPanel")

	var items: Container = cycle_section_node.get_node_or_null("Items") as Container
	assert_not_null(items)

	# Test Force Luteal button
	var force_luteal_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text == "Force Luteal":
			force_luteal_btn = child as Button
			break
	assert_not_null(force_luteal_btn, "Force Luteal button should exist")
	force_luteal_btn.pressed.emit()
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.LUTEAL)

	# Test Force Menstrual button
	var force_menstrual_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text == "Force Menstrual":
			force_menstrual_btn = child as Button
			break
	assert_not_null(force_menstrual_btn, "Force Menstrual button should exist")
	force_menstrual_btn.pressed.emit()
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.MENSTRUAL)

	# Test Intensity 0.5 button
	var int_05_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text == "Intensity 0.5":
			int_05_btn = child as Button
			break
	assert_not_null(int_05_btn, "Intensity 0.5 button should exist")
	int_05_btn.pressed.emit()
	assert_almost_eq(GameSettings.current().symptom_intensity, 0.5, 1e-4)

	# Test Cycle Length 12d button
	var cycle_12_btn: Button = null
	for child: Node in items.get_children():
		if child is Button and (child as Button).text == "Cycle Length 12d":
			cycle_12_btn = child as Button
			break
	assert_not_null(cycle_12_btn, "Cycle Length 12d button should exist")
	cycle_12_btn.pressed.emit()
	assert_eq(GameSettings.current().cycle_length_days, 12)

	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()

func test_debug_panel_money_section() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	FinanceManager.reset_state()

	var panel: CanvasLayer = load("res://ui/debug/debug_panel.tscn").instantiate()
	add_child_autoqfree(panel)

	panel.toggle_panel()

	var sections_container: Node = panel.get_node("PanelRoot/MarginContainer/VBoxContainer/ScrollContainer/SectionsContainer")
	assert_not_null(sections_container)

	var money_section_node: Node = sections_container.get_node_or_null("Money")
	assert_not_null(money_section_node, "Money section should exist in DebugPanel")

	var items: Container = money_section_node.get_node_or_null("Items") as Container
	assert_not_null(items)

	# Initial wallet is 25000 (€250.00)
	assert_eq(FinanceManager.wallet_cents, 25000)

	# Find buttons
	var add_100_btn: Button = null
	var sub_100_btn: Button = null
	var charge_rent_btn: Button = null
	for child: Node in items.get_children():
		if child is Button:
			var btn: Button = child as Button
			if btn.text == "+€100":
				add_100_btn = btn
			elif btn.text == "−€100 (Bill)":
				sub_100_btn = btn
			elif btn.text == "Charge Rent Now":
				charge_rent_btn = btn

	assert_not_null(add_100_btn, "+€100 button should exist")
	assert_not_null(sub_100_btn, "−€100 (Bill) button should exist")
	assert_not_null(charge_rent_btn, "Charge Rent Now button should exist")

	# Test +€100 button
	add_100_btn.pressed.emit()
	assert_eq(FinanceManager.wallet_cents, 35000)

	# Test −€100 (Bill) button 4 times: 35000 -> 25000 -> 15000 -> 5000 -> -5000
	sub_100_btn.pressed.emit()
	sub_100_btn.pressed.emit()
	sub_100_btn.pressed.emit()
	sub_100_btn.pressed.emit()
	assert_eq(FinanceManager.wallet_cents, -5000)

	# Verify debt modifier is active in StatusManager
	var debt_mod_found: bool = false
	for m: StatModifier in StatusManager.get_modifiers(int(Enums.Stat.SANITY)):
		if m.source_id == &"finance_debt":
			debt_mod_found = true
			break
	assert_true(debt_mod_found, "Debt modifier should be active when wallet is negative")

	# Test Charge Rent Now button: -5000 - 60000 = -65000
	charge_rent_btn.pressed.emit()
	assert_eq(FinanceManager.wallet_cents, -65000)

	# Earn back to positive
	FinanceManager.earn(70000, &"debug", "Clear debt")
	assert_eq(FinanceManager.wallet_cents, 5000)

	var debt_mod_still_found: bool = false
	for m: StatModifier in StatusManager.get_modifiers(int(Enums.Stat.SANITY)):
		if m.source_id == &"finance_debt":
			debt_mod_still_found = true
			break
	assert_false(debt_mod_still_found, "Debt modifier should be removed once wallet is >= 0")

	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	FinanceManager.reset_state()

