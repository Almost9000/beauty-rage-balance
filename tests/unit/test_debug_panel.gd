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
