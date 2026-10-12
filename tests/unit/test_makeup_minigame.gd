extends GutTest

var minigame_scene: PackedScene


func before_each() -> void:
	minigame_scene = load("res://features/makeup/makeup_minigame.tscn") as PackedScene
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("reset_state"):
		inv.call("reset_state")
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("reset_state"):
		clock.call("reset_state")


func test_minigame_initial_state_and_layer_sequence() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	assert_false(mg.is_open)

	mg.open()
	assert_true(mg.is_open)
	assert_eq(mg.get_current_layer(), Enums.MakeupLayer.BASE, "First layer is BASE")

	var guide: MakeupGuide = mg.get_current_guide()
	assert_not_null(guide)
	assert_eq(guide.layer, Enums.MakeupLayer.BASE)


func test_minigame_layer_progression_sequential() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	mg.open()
	assert_eq(mg.get_current_layer(), Enums.MakeupLayer.BASE)

	mg.skip_current_layer()
	assert_eq(mg.get_current_layer(), Enums.MakeupLayer.BLUSH)

	mg.skip_current_layer()
	assert_eq(mg.get_current_layer(), Enums.MakeupLayer.EYESHADOW)

	mg.skip_current_layer()
	assert_eq(mg.get_current_layer(), Enums.MakeupLayer.EYELINER)

	mg.skip_current_layer()
	assert_eq(mg.get_current_layer(), Enums.MakeupLayer.LIPSTICK)

	mg.skip_current_layer()
	# All layers finished, finish panel should be visible
	assert_true(mg.finish_panel.visible, "Finish panel visible after all 5 layers")


func test_minigame_skip_layer_leaves_it_empty() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	mg.open()
	mg.skip_current_layer() # Skip BASE

	var look: MakeupLook = mg.get_working_look()
	assert_false(look.has_layer(Enums.MakeupLayer.BASE), "Skipped layer is not present in look")


func test_minigame_apply_layer_advances_clock_and_sets_layer() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	var clock: Node = get_node_or_null("/root/GameClock")
	var initial_minute: int = clock.call("get_minute_of_day") if clock else 0

	mg.open()
	var guide: MakeupGuide = mg.get_current_guide()
	var time_cost: int = guide.time_cost_min

	mg.auto_trace()
	mg.apply_current_layer()

	var after_minute: int = clock.call("get_minute_of_day") if clock else 0
	assert_eq(after_minute, initial_minute + time_cost, "Clock advanced by guide time cost")

	var look: MakeupLook = mg.get_working_look()
	assert_true(look.has_layer(Enums.MakeupLayer.BASE), "Base layer was applied")
	var entry: Dictionary = look.get_layer(Enums.MakeupLayer.BASE)
	assert_almost_eq(float(entry.get("accuracy", 0.0)), 1.0, 0.05, "Auto-trace gives ~1.0 accuracy")


func test_minigame_finish_applies_look_to_inventory_manager() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	mg.open()

	# Apply all 5 layers with auto-trace
	for i: int in range(5):
		mg.auto_trace()
		mg.apply_current_layer()

	mg.finish()

	var inv: Node = get_node_or_null("/root/InventoryManager")
	assert_not_null(inv.current_look, "InventoryManager has active current_look")
	assert_gt(inv.current_look.score(), 0.9, "Overall look score is high from auto-trace")
	assert_false(mg.is_open, "Minigame closed on finish")


func test_minigame_cancel_keeps_previous_look() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	var original_look := MakeupLook.new()
	original_look.id = &"original_preset"
	original_look.display_name = "Original Preset"
	inv.call("set_look", original_look)

	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	mg.open()
	mg.auto_trace()
	mg.apply_current_layer()

	mg.cancel()

	assert_false(mg.is_open, "Minigame closed on cancel")
	assert_eq(inv.current_look, original_look, "Original look kept on cancel")


func test_minigame_only_owned_cosmetics_shown() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	mg.open()

	var inv: Node = get_node_or_null("/root/InventoryManager")
	var owned_base_count: int = 0
	for cos: CosmeticItem in inv.owned_cosmetics:
		if cos and cos.layer == Enums.MakeupLayer.BASE:
			owned_base_count += 1

	var list_children := mg.cosmetics_list.get_children()
	assert_eq(list_children.size(), owned_base_count, "Only owned cosmetics displayed")


func test_minigame_careful_vs_sloppy_trace_differs() -> void:
	var mg: MakeupMinigame = minigame_scene.instantiate() as MakeupMinigame
	add_child_autoqfree(mg)

	mg.open()
	var guide: MakeupGuide = mg.get_current_guide()
	assert_not_null(guide)

	# 1. Careful trace (perfect alignment with guide points)
	mg.auto_trace()
	var careful_score: Dictionary = StrokeScorer.score_stroke(guide, mg._stroke_points)

	# 2. Sloppy trace (disjoint points with large bleed and low coverage)
	var sloppy_stroke := PackedVector2Array([
		Vector2(0.05, 0.05),
		Vector2(0.15, 0.08),
		Vector2(0.25, 0.05)
	])
	var sloppy_score: Dictionary = StrokeScorer.score_stroke(guide, sloppy_stroke)

	# Assert careful trace looks clearly better than sloppy trace
	assert_gt(careful_score["accuracy"], sloppy_score["accuracy"], "Careful trace has higher accuracy")
	assert_gt(careful_score["opacity"], sloppy_score["opacity"], "Careful trace has higher opacity")
	assert_lt((careful_score["smudge"] as Vector2).length(), (sloppy_score["smudge"] as Vector2).length(), "Careful trace has lower smudge")
	assert_almost_eq(careful_score["accuracy"], 1.0, 0.01)
	assert_almost_eq(sloppy_score["accuracy"], 0.0, 0.01)
