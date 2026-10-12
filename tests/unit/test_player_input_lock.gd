extends GutTest

const PLAYER_SCENE_PATH := "res://features/player/player.tscn"

func test_initial_state_not_locked() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	assert_false(player.is_input_locked(), "Player should not be locked initially")
	assert_eq(player.get_lock_reasons().size(), 0, "Initial lock reasons should be empty")

func test_single_lock_and_unlock() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	player.lock_input(&"pause_menu")
	assert_true(player.is_input_locked(), "Player should be locked after lock_input")
	assert_true(player.has_lock_reason(&"pause_menu"))
	assert_eq(player.get_lock_reasons(), [&"pause_menu"])

	player.unlock_input(&"pause_menu")
	assert_false(player.is_input_locked(), "Player should be unlocked after unlock_input")
	assert_false(player.has_lock_reason(&"pause_menu"))
	assert_eq(player.get_lock_reasons().size(), 0)

func test_multiple_distinct_lock_reasons() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	player.lock_input(&"dialog")
	player.lock_input(&"inventory")
	assert_true(player.is_input_locked())
	assert_true(player.has_lock_reason(&"dialog"))
	assert_true(player.has_lock_reason(&"inventory"))

	# Unlock one reason; player should still be locked
	player.unlock_input(&"dialog")
	assert_true(player.is_input_locked(), "Player should remain locked while inventory reason is active")
	assert_false(player.has_lock_reason(&"dialog"))
	assert_true(player.has_lock_reason(&"inventory"))

	# Unlock second reason; player should now be unlocked
	player.unlock_input(&"inventory")
	assert_false(player.is_input_locked(), "Player should be unlocked when all reasons are removed")

func test_reference_counting_same_reason() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	player.lock_input(&"cutscene")
	player.lock_input(&"cutscene")
	assert_true(player.is_input_locked())

	player.unlock_input(&"cutscene")
	assert_true(player.is_input_locked(), "Player should remain locked after single unlock of doubled lock")

	player.unlock_input(&"cutscene")
	assert_false(player.is_input_locked(), "Player should unlock after matching unlock count")

func test_unlock_unlocked_reason_graceful() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	player.unlock_input(&"non_existent")
	assert_false(player.is_input_locked(), "Unlocking unknown reason should not crash or lock")

func test_input_locked_changed_signal() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)
	watch_signals(player)

	# First lock: 0 -> 1 triggers signal with true
	player.lock_input(&"reason_1")
	assert_signal_emitted_with_parameters(player, "input_locked_changed", [true])

	# Second lock: 1 -> 2 should NOT emit again
	player.lock_input(&"reason_2")
	assert_signal_emit_count(player, "input_locked_changed", 1)

	# Partial unlock: 2 -> 1 should NOT emit
	player.unlock_input(&"reason_1")
	assert_signal_emit_count(player, "input_locked_changed", 1)

	# Complete unlock: 1 -> 0 should emit with false
	player.unlock_input(&"reason_2")
	assert_signal_emit_count(player, "input_locked_changed", 2)
	assert_signal_emitted_with_parameters(player, "input_locked_changed", [false])

func test_mouse_mode_toggled_with_lock() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	player.lock_input(&"menu")
	assert_eq(player.target_mouse_mode, Input.MOUSE_MODE_VISIBLE, "Target mouse mode should be visible when input is locked")

	player.unlock_input(&"menu")
	assert_eq(player.target_mouse_mode, Input.MOUSE_MODE_CAPTURED, "Target mouse mode should be captured when unlocked")

	if DisplayServer.get_name() != "headless":
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED)

func test_player_scene_instantiation() -> void:
	var scene: PackedScene = load(PLAYER_SCENE_PATH)
	assert_not_null(scene, "player.tscn should load")

	var player = scene.instantiate()
	add_child_autoqfree(player)

	assert_true(player.is_in_group(&"player"), "Player should be in group 'player'")
	assert_is(player, PlayerController)

	var col = player.get_node_or_null("CollisionShape3D")
	assert_not_null(col, "CollisionShape3D should exist")
	assert_eq(player.collision_layer, 2, "Collision layer should be 2 (player)")

	var mount = player.get_node_or_null("AvatarMount")
	assert_not_null(mount, "AvatarMount node should exist")

	var avatar_node = mount.get_node_or_null("Avatar")
	assert_not_null(avatar_node, "Avatar should exist under AvatarMount")

	var probe = player.get_node_or_null("InteractionProbe")
	assert_not_null(probe, "InteractionProbe should exist")

	var cam = player.get_node_or_null("CameraRig")
	assert_not_null(cam, "CameraRig should exist")
