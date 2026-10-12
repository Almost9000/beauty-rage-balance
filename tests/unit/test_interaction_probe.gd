extends GutTest

func test_pick_best_empty_returns_null() -> void:
	var result = InteractionProbe.pick_best([])
	assert_null(result, "Empty candidate list should return null")

func test_pick_best_all_disabled_returns_null() -> void:
	var c1 := Interactable.new()
	c1.enabled = false
	c1.position = Vector3(0, 0, -1)
	add_child_autoqfree(c1)

	var c2 := Interactable.new()
	c2.enabled = false
	c2.position = Vector3(0, 0, -2)
	add_child_autoqfree(c2)

	var result = InteractionProbe.pick_best([c1, c2])
	assert_null(result, "All disabled candidates should return null")

func test_pick_best_single_enabled_candidate() -> void:
	var c1 := Interactable.new()
	c1.enabled = true
	c1.position = Vector3(0, 0, -1)
	add_child_autoqfree(c1)

	var result = InteractionProbe.pick_best([c1])
	assert_eq(result, c1, "Single enabled candidate should be chosen")

func test_pick_best_ignores_disabled_and_picks_enabled() -> void:
	var c_disabled := Interactable.new()
	c_disabled.enabled = false
	c_disabled.position = Vector3(0, 0, -1)
	c_disabled.priority = 100
	add_child_autoqfree(c_disabled)

	var c_enabled := Interactable.new()
	c_enabled.enabled = true
	c_enabled.position = Vector3(0, 0, -3)
	c_enabled.priority = 1
	add_child_autoqfree(c_enabled)

	var result = InteractionProbe.pick_best([c_disabled, c_enabled])
	assert_eq(result, c_enabled, "Disabled candidates must be ignored regardless of priority")

func test_pick_best_ranks_priority_over_distance() -> void:
	# c_low is closer (1m ahead), but priority 0
	var c_low := Interactable.new()
	c_low.enabled = true
	c_low.priority = 0
	c_low.position = Vector3(0, 0, -1)
	add_child_autoqfree(c_low)

	# c_high is further (3m ahead), but priority 10
	var c_high := Interactable.new()
	c_high.enabled = true
	c_high.priority = 10
	c_high.position = Vector3(0, 0, -3)
	add_child_autoqfree(c_high)

	var result = InteractionProbe.pick_best([c_low, c_high], Vector3.ZERO, Vector3.FORWARD)
	assert_eq(result, c_high, "Higher priority candidate should be picked even if further away")

func test_pick_best_ranks_distance_when_same_priority() -> void:
	# Both priority 0, both directly in front
	var c_far := Interactable.new()
	c_far.enabled = true
	c_far.priority = 0
	c_far.position = Vector3(0, 0, -3)
	add_child_autoqfree(c_far)

	var c_near := Interactable.new()
	c_near.enabled = true
	c_near.priority = 0
	c_near.position = Vector3(0, 0, -1)
	add_child_autoqfree(c_near)

	var result = InteractionProbe.pick_best([c_far, c_near], Vector3.ZERO, Vector3.FORWARD)
	assert_eq(result, c_near, "Closer candidate should be picked when priorities are equal")

func test_pick_best_ranks_facing_when_same_priority_and_distance() -> void:
	# Both at distance 2m
	# c_front is directly in front (0, 0, -2) -> facing dot = 1.0
	var c_front := Interactable.new()
	c_front.enabled = true
	c_front.priority = 0
	c_front.position = Vector3(0, 0, -2)
	add_child_autoqfree(c_front)

	# c_side is 90 degrees to the right (2, 0, 0) -> facing dot = 0.0
	var c_side := Interactable.new()
	c_side.enabled = true
	c_side.priority = 0
	c_side.position = Vector3(2, 0, 0)
	add_child_autoqfree(c_side)

	var result = InteractionProbe.pick_best([c_side, c_front], Vector3.ZERO, Vector3.FORWARD)
	assert_eq(result, c_front, "Candidate directly in front should be preferred over one to the side")

func test_interaction_probe_interact_action_fires_on_best() -> void:
	var probe := InteractionProbe.new()
	add_child_autoqfree(probe)

	var target := Interactable.new()
	target.enabled = true
	target.prompt_text = "prompt.open"
	add_child_autoqfree(target)
	watch_signals(target)

	probe.current_best = target

	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	probe._unhandled_input(event)

	assert_signal_emitted(target, "interacted", "interact action should call interact on current_best")

func test_interaction_probe_locked_input_does_not_interact() -> void:
	var player := PlayerController.new()
	add_child_autoqfree(player)

	var probe := InteractionProbe.new()
	player.add_child(probe)
	probe.player_node = player

	var target := Interactable.new()
	target.enabled = true
	add_child_autoqfree(target)
	watch_signals(target)

	probe.current_best = target

	# Lock player input
	player.lock_input(&"cutscene")

	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	probe._unhandled_input(event)

	assert_signal_not_emitted(target, "interacted", "interact action should not fire when input is locked")
