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
