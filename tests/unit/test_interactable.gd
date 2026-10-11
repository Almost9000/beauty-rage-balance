extends GutTest

func test_default_values() -> void:
	var interactable: Interactable = Interactable.new()
	assert_eq(interactable.prompt_text, "")
	assert_true(interactable.enabled)
	assert_eq(interactable.priority, 0)
	assert_eq(interactable.collision_layer, 4, "Collision layer should be 4 (layer 3: interactable)")
	interactable.free()

func test_interact_when_enabled() -> void:
	var interactable: Interactable = Interactable.new()
	watch_signals(interactable)

	var actor: Node = Node.new()
	interactable.interact(actor)

	assert_signal_emitted(interactable, "interacted", "interacted signal should be emitted when enabled")
	assert_signal_emitted_with_parameters(interactable, "interacted", [actor])

	actor.free()
	interactable.free()

func test_interact_when_disabled() -> void:
	var interactable: Interactable = Interactable.new()
	interactable.enabled = false
	watch_signals(interactable)

	var actor: Node = Node.new()
	interactable.interact(actor)

	assert_signal_not_emitted(interactable, "interacted", "interacted signal should not be emitted when disabled")

	actor.free()
	interactable.free()

func test_custom_properties() -> void:
	var interactable: Interactable = Interactable.new()
	interactable.prompt_text = "prompt.open_closet"
	interactable.priority = 10

	assert_eq(interactable.prompt_text, "prompt.open_closet")
	assert_eq(interactable.priority, 10)
	interactable.free()
