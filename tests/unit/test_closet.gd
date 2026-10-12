extends GutTest

var closet_scene: PackedScene
var player_scene: PackedScene


func before_each() -> void:
	closet_scene = load("res://features/wardrobe/closet.tscn") as PackedScene
	player_scene = load("res://features/player/player.tscn") as PackedScene


func test_closet_scene_structure() -> void:
	var closet: Closet = closet_scene.instantiate() as Closet
	add_child_autoqfree(closet)

	assert_not_null(closet.interactable, "Interactable exists")
	assert_not_null(closet.camera_marker, "CameraMarker exists")
	assert_not_null(closet.wardrobe_ui, "WardrobeUI exists")
	assert_eq(closet.interactable.collision_layer, 4, "Interactable on layer 3 (mask 4)")


func test_closet_open_and_close_locks_and_unlocks_input() -> void:
	var closet: Closet = closet_scene.instantiate() as Closet
	var player: PlayerController = player_scene.instantiate() as PlayerController
	add_child_autoqfree(closet)
	add_child_autoqfree(player)

	assert_false(player.is_input_locked(), "Player not locked initially")

	closet.open_wardrobe(player)

	assert_true(closet.is_wardrobe_open(), "Wardrobe open")
	assert_true(player.is_input_locked(), "Player input locked while wardrobe open")
	assert_true(player.has_lock_reason(&"wardrobe"), "Lock reason is &\"wardrobe\"")

	var rig: CameraRig = player.camera_rig
	if rig:
		assert_true(rig.is_focused(), "CameraRig is focused on closet marker")

	closet.close_wardrobe()

	assert_false(closet.is_wardrobe_open(), "Wardrobe closed")
	assert_false(player.is_input_locked(), "Player input unlocked after wardrobe closed")
	assert_false(player.has_lock_reason(&"wardrobe"), "Lock reason cleared")
	if rig:
		assert_false(rig.is_focused(), "CameraRig released focus")


func test_closet_close_mid_tween_restores_input_and_camera() -> void:
	var closet: Closet = closet_scene.instantiate() as Closet
	var player: PlayerController = player_scene.instantiate() as PlayerController
	add_child_autoqfree(closet)
	add_child_autoqfree(player)

	closet.camera_blend_time = 1.0  # Slow blend to test mid-tween
	closet.open_wardrobe(player)

	assert_true(player.is_input_locked())

	# Immediately trigger close mid-tween via ui_cancel
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	closet.wardrobe_ui._unhandled_input(ev)

	assert_false(closet.is_wardrobe_open(), "Wardrobe closed via ui_cancel")
	assert_false(player.is_input_locked(), "Player input unlocked mid-tween")
	assert_false(player.has_lock_reason(&"wardrobe"))
	if player.camera_rig:
		assert_false(player.camera_rig.is_focused(), "Camera focus released mid-tween")
